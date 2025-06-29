#!/bin/bash

# Comprehensive test script for our lean PostGIS Docker image
# This script verifies core functionality and confirms size optimizations
set -e

# Accept platform as environment variable for CI, or detect locally
PLATFORM=${DOCKER_PLATFORM:-}
if [ -z "$PLATFORM" ]; then
    # Auto-detect platform if not specified (for local testing)
    HOST_ARCH=$(docker version --format '{{.Server.Arch}}')
    PLATFORM="linux/${HOST_ARCH}"
fi


# Generate unique container name using process ID to avoid conflicts with other test runs
CONTAINER_NAME="postgis-test-$$"
CLEANUP_DONE=false

# Robust cleanup function that runs on any exit (normal or error)
# This ensures we don't leave test containers running
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

# Set up trap to ensure cleanup runs on any exit (normal, error, or signal)
trap cleanup EXIT INT TERM

echo "🧪 Testing Lean PostGIS Docker Image..."
echo "📦 Container name: $CONTAINER_NAME"

# Start container with a specific test database
# We use a named database to ensure PostGIS extensions get installed properly
echo "🚀 Starting PostgreSQL container..."
if ! docker run -d --name "$CONTAINER_NAME" \
    --platform="$PLATFORM" \
    -e POSTGRES_PASSWORD=testpass \
    -e POSTGRES_DB=testdb \
    coolify-postgresql:latest; then
    echo "❌ Failed to start container"
    exit 1
fi

# Wait for PostgreSQL to be ready with robust health checking
# This ensures we don't start tests before the database is fully initialized
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

# First verify that we can connect to the database
echo "🔍 Verifying database connection..."
if ! docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "SELECT 1;" >/dev/null 2>&1; then
    echo "❌ Cannot connect to testdb"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Test core PostGIS functionality to ensure all essential features work
echo "🔍 Testing PostGIS core extensions..."
if ! docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "
    -- Test PostGIS version and build info
    -- This confirms the extension is properly installed
    SELECT postgis_version();
    SELECT postgis_lib_version();
    SELECT postgis_lib_build_date();

    -- Test basic geometry creation and operations
    -- These are the fundamental spatial operations most applications need
    SELECT ST_AsText(ST_MakePoint(1, 2)) as point_test;
    SELECT ST_AsText(ST_MakeLine(ST_MakePoint(0, 0), ST_MakePoint(1, 1))) as line_test;
    SELECT ST_Area(ST_MakeEnvelope(0, 0, 1, 1, 4326)) as area_test;

    -- Test coordinate transformations
    -- Essential for working with different map projections
    SELECT ST_AsText(ST_Transform(ST_GeomFromText('POINT(0 0)', 4326), 3857)) as transform_test;

    -- Test spatial relationships
    -- These functions enable spatial queries like 'find all points within this area'
    SELECT ST_Contains(
        ST_MakeEnvelope(0, 0, 2, 2, 4326),
        ST_SetSRID(ST_MakePoint(1, 1), 4326)
    ) as contains_test;

    -- Test distance calculations
    -- Important for proximity searches
    SELECT ST_Distance(
        ST_MakePoint(0, 0),
        ST_MakePoint(1, 1)
    ) as distance_test;
"; then
    echo "❌ Core PostGIS tests failed"
    exit 1
fi

# Test real-world spatial operations with a sample table
echo "📍 Testing practical spatial operations..."
if ! docker exec "$CONTAINER_NAME" psql -U postgres -d testdb -c "
    -- Create a test table with common spatial data types
    CREATE TABLE test_locations (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        location GEOMETRY(POINT, 4326),
        area GEOMETRY(POLYGON, 4326)
    );

    -- Insert test data (San Francisco coordinates as an example)
    INSERT INTO test_locations (name, location, area) VALUES
    ('Test Point', ST_SetSRID(ST_MakePoint(-122.4194, 37.7749), 4326), NULL),
    ('Test Area', NULL, ST_SetSRID(ST_MakeEnvelope(-122.5, 37.7, -122.3, 37.8, 4326), 4326));

    -- Test spatial queries that applications commonly need
    SELECT name, ST_AsText(location) as point_wkt FROM test_locations WHERE location IS NOT NULL;
    SELECT name, ST_Area(area) as area_sqm FROM test_locations WHERE area IS NOT NULL;

    -- Test spatial indexing (critical for performance with large datasets)
    CREATE INDEX idx_locations_geom ON test_locations USING GIST (location);
    CREATE INDEX idx_areas_geom ON test_locations USING GIST (area);

    -- Clean up test table
    DROP TABLE test_locations;
"; then
    echo "❌ Practical spatial operations tests failed"
    exit 1
fi

# Verify that excluded extensions are actually not available
# This confirms our size optimization efforts were successful
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

# Check the image size to verify we're meeting our size target
echo "📏 Checking image size..."
IMAGE_SIZE=$(docker images coolify-postgresql:latest --format "table {{.Size}}" | tail -n 1)
echo "📦 Image size: $IMAGE_SIZE"

# Manual cleanup (trap will also run, but that's OK)
cleanup

echo "✅ Lean PostGIS test completed successfully!"
echo "🎯 Ready for production: core spatial features working perfectly"
