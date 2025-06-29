#!/bin/bash

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

# Create the 'template_postgis' template db
# This allows new databases to be created with PostGIS already installed
"${psql[@]}" <<- 'EOSQL'
CREATE DATABASE template_postgis IS_TEMPLATE true;
EOSQL

# Load core PostGIS extension into both the template and the main database
for DB in template_postgis "$POSTGRES_DB"; do
	echo "Loading PostGIS core extensions into $DB"
	"${psql[@]}" --dbname="$DB" <<-'EOSQL'
		-- Install core PostGIS for geometry types and spatial functions
		-- This provides all the essential spatial capabilities
		CREATE EXTENSION IF NOT EXISTS postgis;

		-- Reconnect to update pg_setting.resetval
		-- This addresses a known issue: https://github.com/postgis/docker-postgis/issues/288
		\c

		-- Note: We've excluded topology, raster, and tiger geocoder extensions
		-- to minimize image size while maintaining core spatial functionality
EOSQL
done
