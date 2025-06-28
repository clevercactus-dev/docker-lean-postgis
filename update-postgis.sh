#!/bin/sh

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

POSTGIS_VERSION="${POSTGIS_VERSION%%+*}"

# Update PostGIS in both template_database and $POSTGRES_DB
for DB in template_postgis "$POSTGRES_DB" "${@}"; do
    echo "Updating PostGIS core extensions in '$DB' to $POSTGIS_VERSION (Directus-optimized)"
    psql --dbname="$DB" -c "
        -- Upgrade core PostGIS only (no raster, topology, or tiger)
        CREATE EXTENSION IF NOT EXISTS postgis VERSION '$POSTGIS_VERSION';
        ALTER EXTENSION postgis UPDATE TO '$POSTGIS_VERSION';

        -- Note: Removed topology and tiger geocoder updates for Directus optimization
    "
done
