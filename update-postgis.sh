#!/bin/sh

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

# Extract the base version number without any suffixes
POSTGIS_VERSION="${POSTGIS_VERSION%%+*}"

# Update PostGIS in template_postgis, the main database, and any additional databases passed as arguments
for DB in template_postgis "$POSTGRES_DB" "${@}"; do
    echo "Updating PostGIS core extensions in '$DB' to $POSTGIS_VERSION"
    psql --dbname="$DB" -c "
        -- First ensure the extension exists, then update it to the current version
        -- This handles both new installations and updates in one command
        CREATE EXTENSION IF NOT EXISTS postgis VERSION '$POSTGIS_VERSION';
        ALTER EXTENSION postgis UPDATE TO '$POSTGIS_VERSION';

        -- Note: We only update the core PostGIS extension
        -- The lean image doesn't include raster, topology, or tiger geocoder
    "
done
