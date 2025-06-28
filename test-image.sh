#!/bin/bash

# Test script for PostGIS Docker Image (Directus-optimized)
set -e

CONTAINER_NAME="postgis-test-$$"  # Use process ID to avoid conflicts
CLEANUP_DONE=false

# Cleanup function that runs no matter what
cleanup() {
    if [ "$CLEANUP_DONE" = false ]; then
        echo "🧹 Cleaning up container '$CONTAINER_NAME'..."
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
            docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
            echo "✅ Container cleaned up"
        fi
        CLEANUP_DONE=true
    fi
}

# Set up trap to ensure cleanup runs on any exit
trap cleanup EXIT INT TERM

echo "🧪 Testing PostGIS Docker Image (Directus-optimized)..."
echo "📦 Container name: $CONTAINER_NAME"

# Start container - FIX: Use POSTGRES_DB=testdb so PostGIS gets installed there
echo "🚀 Starting PostgreSQL container..."
if ! docker run -d --name "$CONTAINER_NAME" \
    -e POSTGRES_PASSWORD=testpass \
    -e POSTGRES_DB=testdb \
    coolify-postgresql:latest; then
    echo "❌ Failed to start container"
    exit 1
fi

# Wait for PostgreSQL to be ready with better health checking
echo "⏳ Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
        echo "✅ PostgreSQL is ready (attempt $i)"
        # Give it an extra moment for the init scripts to complete
        sleep 2
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL failed to start within 30 seconds"
        echo "📝 Container logs:"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
    sleep 1
done

# Verify PostGIS extension is available
echo "🔍 Verifying PostGIS extension..."
if ! docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "SELECT 1;" >/dev/null 2>&1; then
    echo "❌ Cannot connect to testdb"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Test core PostGIS functionality for Directus
echo "🔍 Testing PostGIS core extensions..."
if ! docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "
    -- Test PostGIS version and build info
    SELECT postgis_version();
    SELECT postgis_lib_version();
    SELECT postgis_lib_build_date();

    -- Test basic geometry creation and operations (core Directus needs)
    SELECT ST_AsText(ST_MakePoint(1, 2)) as point_test;
    SELECT ST_AsText(ST_MakeLine(ST_MakePoint(0, 0), ST_MakePoint(1, 1))) as line_test;
    SELECT ST_Area(ST_MakeEnvelope(0, 0, 1, 1, 4326)) as area_test;

    -- Test coordinate transformations (important for Directus maps)
    SELECT ST_AsText(ST_Transform(ST_GeomFromText('POINT(0 0)', 4326), 3857)) as transform_test;

    -- Test spatial relationships (Directus filtering)
    SELECT ST_Contains(
        ST_MakeEnvelope(0, 0, 2, 2, 4326),
        ST_SetSRID(ST_MakePoint(1, 1), 4326)
    ) as contains_test;

    -- Test distance calculations
    SELECT ST_Distance(
        ST_MakePoint(0, 0),
        ST_MakePoint(1, 1)
    ) as distance_test;
"; then
    echo "❌ Core PostGIS tests failed"
    exit 1
fi

# Test typical Directus spatial data types
echo "📍 Testing Directus-style spatial operations..."
if ! docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "
    -- Create a test table similar to what Directus would use
    CREATE TABLE directus_locations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        location GEOMETRY(POINT, 4326),
        area GEOMETRY(POLYGON, 4326)
    );

    -- Insert test data
    INSERT INTO directus_locations (name, location, area) VALUES
    ('Test Point', ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326), NULL),
    ('Test Area', NULL, ST_SetSRID(ST_MakeEnvelope(-122.5, 37.7, -122.3, 37.8, 4326), 4326));

    -- Test spatial queries (typical Directus operations)
    SELECT name, ST_AsText(location) as point_wkt FROM directus_locations WHERE location IS NOT NULL;
    SELECT name, ST_Area(area) as area_sqm FROM directus_locations WHERE area IS NOT NULL;

    -- Test spatial indexing
    CREATE INDEX idx_locations_geom ON directus_locations USING GIST (location);
    CREATE INDEX idx_areas_geom ON directus_locations USING GIST (area);

    -- Clean up test table
    DROP TABLE directus_locations;
"; then
    echo "❌ Directus spatial operations tests failed"
    exit 1
fi

# Test what should NOT be available (confirming optimization)
echo "❌ Testing removed extensions (should fail)..."

echo "  📦 Testing raster extension (should fail)..."
if docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "CREATE EXTENSION IF NOT EXISTS postgis_raster;" 2>/dev/null; then
    echo "⚠️  Raster available (unexpected)"
else
    echo "✅ Raster correctly removed"
fi

echo "  🕸️ Testing topology extension (should fail)..."
if docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;" 2>/dev/null; then
    echo "⚠️  Topology available (unexpected)"
else
    echo "✅ Topology correctly removed"
fi

echo "  🌍 Testing tiger geocoder (should fail)..."
if docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;" 2>/dev/null; then
    echo "⚠️  Tiger geocoder available (unexpected)"
else
    echo "✅ Tiger geocoder correctly removed"
fi

# Test image size
echo "📏 Checking image size..."
IMAGE_SIZE=$(docker images coolify-postgresql:latest --format "table {{.Size}}" | tail -n 1)
echo "📦 Image size: $IMAGE_SIZE"

# Manual cleanup (trap will also run, but that's OK)
cleanup

echo "✅ PostGIS Directus-optimized test completed!"
echo "🎯 Perfect for Directus spatial features: points, polygons, coordinate transforms, spatial queries"
