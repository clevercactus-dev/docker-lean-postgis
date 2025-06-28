
# === VARIABLES (defined once) ===
ARG BASE_IMAGE=postgres:17-alpine3.22
ARG POSTGIS_VERSION=3.5.3
ARG POSTGIS_SHA256=44222ed2b8f742ffc1ceb429b09ebb484c7880f9ba27bf7b6b197346cdd25437

# === BUILD STAGE ===
FROM ${BASE_IMAGE} AS builder

# Re-import build args into this stage
ARG POSTGIS_VERSION
ARG POSTGIS_SHA256

ENV POSTGIS_VERSION=${POSTGIS_VERSION}
ENV POSTGIS_SHA256=${POSTGIS_SHA256}

RUN set -eux \
    && apk add --no-cache --virtual .fetch-deps \
        ca-certificates \
        openssl \
        tar \
    \
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
# Build PostGIS with minimal features for Directus
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
# Basic test to ensure PostGIS core works
    && mkdir /tempdb \
    && chown -R postgres:postgres /tempdb \
    && su postgres -c 'pg_ctl -D /tempdb init' \
    && su postgres -c 'pg_ctl -D /tempdb -c -l /tmp/logfile -o "-F" start' \
    && su postgres -c 'psql -c "CREATE EXTENSION IF NOT EXISTS postgis;"' \
    && su postgres -c 'psql -c "SELECT PostGIS_version();"' \
    && su postgres -c 'pg_ctl -D /tempdb --mode=immediate stop' \
    && rm -rf /tempdb /tmp/logfile

# === FINAL STAGE ===
FROM ${BASE_IMAGE}

# Re-import build args into final stage
ARG POSTGIS_VERSION
ARG BASE_IMAGE

LABEL maintainer="Clever Cactus" \
      org.opencontainers.image.description="PostGIS ${POSTGIS_VERSION} spatial database extension optimized for Directus (ARM64)" \
      org.opencontainers.image.source="https://github.com/clevercactus-dev/coolify-postgresql" \
      org.opencontainers.image.version="${POSTGIS_VERSION}"

ENV POSTGIS_VERSION=${POSTGIS_VERSION}

# Install minimal runtime dependencies for Directus spatial
RUN apk add --no-cache \
        geos \
        proj \
        json-c \
        libstdc++ \
        protobuf-c \
        ca-certificates

# Copy only core PostGIS files (no raster, no topology, no tiger)
COPY --from=builder /usr/local/lib/postgresql/postgis-3.so /usr/local/lib/postgresql/
COPY --from=builder /usr/local/share/postgresql/extension/postgis* /usr/local/share/postgresql/extension/

# Copy basic utilities (skip raster tools)
COPY --from=builder /usr/local/bin/pgsql2shp /usr/local/bin/
COPY --from=builder /usr/local/bin/shp2pgsql /usr/local/bin/

# Copy initialization script (Directus-optimized)
COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh
COPY ./update-postgis.sh /usr/local/bin/

RUN echo "PostGIS ${POSTGIS_VERSION} optimized for Directus" > /_pgis_version.txt
