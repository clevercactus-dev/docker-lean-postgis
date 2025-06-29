
# === VARIABLES (defined once) ===
# Using the latest PostgreSQL 17 Alpine image for minimal size
ARG BASE_IMAGE=postgres:17-alpine3.22
# PostGIS 3.5.3 provides the spatial features we need while maintaining compatibility
ARG POSTGIS_VERSION=3.5.3
# SHA256 checksum ensures we're getting the exact source code we expect
ARG POSTGIS_SHA256=44222ed2b8f742ffc1ceb429b09ebb484c7880f9ba27bf7b6b197346cdd25437

# === BUILD STAGE ===
# Multi-stage build keeps the final image lean by excluding build tools
FROM ${BASE_IMAGE} AS builder

# Re-import build args into this stage
ARG POSTGIS_VERSION
ARG POSTGIS_SHA256

ENV POSTGIS_VERSION=${POSTGIS_VERSION}
ENV POSTGIS_SHA256=${POSTGIS_SHA256}

RUN set -eux \
    # Install minimal dependencies needed to fetch and extract source
    && apk add --no-cache --virtual .fetch-deps \
        ca-certificates \
        openssl \
        tar \
    \
    # Download PostGIS source and verify integrity
    && wget -O postgis.tar.gz "https://github.com/postgis/postgis/archive/${POSTGIS_VERSION}.tar.gz" \
    && echo "${POSTGIS_SHA256} *postgis.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/postgis \
    && tar \
        --extract \
        --file postgis.tar.gz \
        --directory /usr/src/postgis \
        --strip-components 1 \
    && rm postgis.tar.gz \
    \
    # Install build dependencies
    # These are only needed during compilation and won't be in the final image
    && apk add --no-cache --virtual .build-deps \
        geos-dev \
        proj-dev \
        proj-util \
        $DOCKER_PG_LLVM_DEPS \
        autoconf \
        automake \
        file \
        g++ \
        gcc \
        gettext-dev \
        json-c-dev \
        libtool \
        libxml2-dev \
        make \
        pcre2-dev \
        perl \
        protobuf-c-dev \
    \
    # Build PostGIS with minimal features for a lean image
    # We exclude raster, topology, and GUI to reduce size and dependencies
    # Link-time optimization (LTO) improves performance and reduces size
    && cd /usr/src/postgis \
    && gettextize \
    && ./autogen.sh \
    && ./configure \
        --enable-lto \
        --without-gui \
        --without-raster \
        --without-topology \
    && make -j$(nproc) \
    && make install \
    \
    # Quick sanity test to ensure core PostGIS functionality works
    # This catches any build issues before we create the final image
    && mkdir /tempdb \
    && chown -R postgres:postgres /tempdb \
    && su postgres -c 'pg_ctl -D /tempdb init' \
    && su postgres -c 'pg_ctl -D /tempdb -c -l /tmp/logfile -o "-F" start' \
    && su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS postgis;"' \
    && su postgres -c 'psql -c "SELECT PostGIS_version();"' \
    && su postgres -c 'pg_ctl -D /tempdb --mode=immediate stop' \
    && rm -rf /tempdb /tmp/logfile

# === FINAL STAGE ===
# Start fresh with the base image for the smallest possible final size
FROM ${BASE_IMAGE}

# Re-import build args into final stage
ARG POSTGIS_VERSION
ARG BASE_IMAGE

LABEL maintainer="Clever Cactus" \
      org.opencontainers.image.description="Lean PostGIS ${POSTGIS_VERSION} spatial database extension (optimized for ARM64)" \
      org.opencontainers.image.source="https://github.com/clevercactus-dev/coolify-postgresql" \
      org.opencontainers.image.version="${POSTGIS_VERSION}"

ENV POSTGIS_VERSION=${POSTGIS_VERSION}

# Install only the minimal runtime dependencies needed for core spatial functions
# This keeps the image small while maintaining full geometry functionality
RUN apk add --no-cache \
        geos \
        proj \
        json-c \
        libstdc++ \
        protobuf-c \
        ca-certificates

# Copy only the essential PostGIS files from the builder stage
# We deliberately exclude raster, topology, and tiger geocoder components
# to minimize image size while keeping core spatial capabilities
COPY --from=builder /usr/local/lib/postgresql/postgis-3.so /usr/local/lib/postgresql/
COPY --from=builder /usr/local/share/postgresql/extension/postgis* /usr/local/share/postgresql/extension/

# Include only the most useful utilities for working with spatial data
# These tools allow importing/exporting between PostGIS and Shapefile format
COPY --from=builder /usr/local/bin/pgsql2shp /usr/local/bin/
COPY --from=builder /usr/local/bin/shp2pgsql /usr/local/bin/

# Add initialization and update scripts
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh
COPY ./update-postgis.sh /usr/local/bin/

# Create version file for easy identification
RUN echo "Lean PostGIS ${POSTGIS_VERSION}" > /_pgis_version.txt
