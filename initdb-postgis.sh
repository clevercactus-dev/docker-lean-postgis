#!/bin/bash

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

# Create the 'template_postgis' template db
"${psql[@]}" <<- 'EOSQL'
CREATE DATABASE template_postgis IS_TEMPLATE true;
EOSQL

# Load minimal PostGIS for Directus spatial features
for DB in template_postgis "$POSTGRES_DB"; do
	echo "Loading PostGIS core extensions into $DB (Directus-optimized)"
	"${psql[@]}" --dbname="$DB" <<-'EOSQL'
		-- Core PostGIS for geometry types and spatial functions
		CREATE EXTENSION IF NOT EXISTS postgis;
		-- Reconnect to update pg_setting.resetval
		-- See https://github.com/postgis/docker-postgis/issues/288
		\c
		-- Note: Removed topology, raster, tiger geocoder for Directus optimization
EOSQL
done
