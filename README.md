# 🌍 Lean PostGIS Docker Image 🐘

[![Build Status](https://github.com/clevercactus-dev/docker-lean-postgis/actions/workflows/build.yml/badge.svg)](https://github.com/clevercactus-dev/docker-lean-postgis/actions/workflows/build.yml)
[![GitHub Container Registry](https://img.shields.io/badge/ghcr.io-docker--lean--postgis-blue?logo=docker)](https://github.com/clevercactus-dev/docker-lean-postgis/pkgs/container/docker-lean-postgis)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight, performance-optimized PostgreSQL image with PostGIS spatial extensions. Built on
Alpine Linux for minimal size while maintaining full spatial database functionality.

## ✨ Features

- 🗜️ **Lean Build**: ~329MB image size (vs 600MB+ for standard PostGIS)
- 🚀 **Performance Focused**: Optimized for speed and resource efficiency
- 🧩 **Core PostGIS**: Full support for geometry types and spatial functions
- 🔄 **Multi-Architecture**: Native support for both ARM64 and AMD64 platforms
- 🧪 **Thoroughly Tested**: Comprehensive test suite ensures reliability
- 🔒 **Secure Base**: Built on official PostgreSQL Alpine images
- 📦 **Latest Versions**: PostgreSQL 18 + PostGIS 3.6.2

### What's Included

- ✅ Core PostGIS spatial types and functions
- ✅ GEOS geometry engine
- ✅ PROJ coordinate transformation library
- ✅ Spatial indexing (GIST)
- ✅ Spatial relationships (contains, within, etc.)
- ✅ Distance calculations
- ✅ Coordinate transformations

### What's Excluded (for size optimization)

- ❌ Raster support
- ❌ Topology extension
- ❌ Tiger geocoder
- ❌ GUI tools

## 🚀 Quick Start

```bash
# Pull the image
docker pull ghcr.io/clevercactus-dev/docker-lean-postgis:latest

# Run a container
docker run -d \
  --name postgis \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  ghcr.io/clevercactus-dev/docker-lean-postgis:latest
```

### Available Tags

The following tagging scheme is used for this image:

| Tag                            | Description                                 |
|--------------------------------|---------------------------------------------|
| `latest`                       | Latest stable build from the main branch    |
| `RELEASE.YYYY-MM-DDTHH-mm-ssZ` | Timestamped release builds from main branch |
| `main-sha`                     | Specific commit from main branch            |
| `branch-YYYY-MM-DDTHH-mm-ssZ`  | Timestamped builds from other branches      |
| `branch-sha`                   | Specific commit from other branches         |

All images are multi-architecture and will automatically use the appropriate version for your
platform (AMD64 or ARM64).

### Environment Variables

| Variable            | Description                    | Default                         |
|---------------------|--------------------------------|---------------------------------|
| `POSTGRES_PASSWORD` | PostgreSQL password (required) | -                               |
| `POSTGRES_USER`     | PostgreSQL username            | `postgres`                      |
| `POSTGRES_DB`       | Database name                  | `postgres`                      |
| `PGDATA`            | Data directory                 | `/var/lib/postgresql/18/docker` |

All standard PostgreSQL environment variables are supported. See
the [official PostgreSQL Docker documentation](https://hub.docker.com/_/postgres) for more details.

> **Note:** Starting with PostgreSQL 18, the PGDATA path is now version-specific to enable easier
> major version upgrades using `pg_upgrade --link`.

### Using with Docker Compose

```yaml
services:
   postgis:
      image: ghcr.io/clevercactus-dev/docker-lean-postgis:latest
      environment:
         POSTGRES_PASSWORD: mysecretpassword
         POSTGRES_DB: mydb
      ports:
         - "5432:5432"
      volumes:
         - postgis-data:/var/lib/postgresql

volumes:
   postgis-data:
```

## 🔄 Migrating from PostgreSQL 17 to 18

PostgreSQL 18 introduces a breaking change in the data directory structure. If you're upgrading from
a previous version of this image (PostgreSQL 17), you have two options:

### Option 1: Use the Old PGDATA Path (Backwards Compatible)

Keep using your existing volumes by explicitly setting the PGDATA environment variable:

```yaml
services:
  postgis:
    image: ghcr.io/clevercactus-dev/docker-lean-postgis:latest
    environment:
      POSTGRES_PASSWORD: mysecretpassword
      POSTGRES_DB: mydb
      PGDATA: /var/lib/postgresql/data  # Use old location
    ports:
      - "5432:5432"
    volumes:
      - postgis-data:/var/lib/postgresql/data  # Old mount point

volumes:
  postgis-data:
```

### Option 2: Migrate to the New Structure (Recommended)

For new deployments or when you want to benefit from easier future upgrades:

1. **Backup your existing data:**
   ```bash
   docker exec your-container pg_dumpall -U postgres > backup.sql
   ```

2. **Update your docker-compose.yml to use the new volume mount:**
   ```yaml
   volumes:
     - postgis-data:/var/lib/postgresql  # New mount point
   ```

3. **Start the new container and restore:**
   ```bash
   docker-compose up -d
   docker exec -i your-container psql -U postgres < backup.sql
   ```

> **Why this change?** The new versioned PGDATA path (`/var/lib/postgresql/18/docker`) enables
> faster major version upgrades using `pg_upgrade --link` by keeping data directories separate per
> version.

## 🔨 Building

To build the image locally:

```bash
# Clone the repository
git clone https://github.com/clevercactus-dev/docker-lean-postgis.git
cd docker-lean-postgis

# Build the image
docker build -t docker-lean-postgis:latest .
```

### Building for Multiple Architectures

```bash
docker buildx create --name mybuilder --use
docker buildx build --platform linux/amd64,linux/arm64 -t docker-lean-postgis:latest .
```

## 🧪 Testing

The repository includes a comprehensive test script that verifies:

- Core PostGIS functionality
- Spatial operations
- Excluded features are properly removed
- Image size

Run the tests with:

```bash
./test-image.sh
```

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create a feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request

### Development Guidelines

- Keep the image size as small as possible
- Maintain compatibility with the official PostgreSQL image
- Add comprehensive tests for new features
- Document any new features or changes

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgements

- [PostgreSQL](https://www.postgresql.org/)
- [PostGIS](https://postgis.net/)
- [Docker](https://www.docker.com/)
