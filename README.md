# 🌍 Lean PostGIS Docker Image 🐘

[![Build Status](https://github.com/clevercactus-dev/coolify-postgresql/actions/workflows/build.yml/badge.svg)](https://github.com/clevercactus-dev/coolify-postgresql/actions/workflows/build.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/ghcr.io/clevercactus-dev/coolify-postgresql)](https://github.com/clevercactus-dev/coolify-postgresql/pkgs/container/coolify-postgresql)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A lightweight, performance-optimized PostgreSQL image with PostGIS spatial extensions. Built on
Alpine Linux for minimal size while maintaining full spatial database functionality.

## ✨ Features

- 🗜️ **Lean Build**: ~329MB image size (vs 600MB+ for standard PostGIS)
- 🚀 **Performance Focused**: Optimized for speed and resource efficiency
- 🧩 **Core PostGIS**: Full support for geometry types and spatial functions
- 🔄 **Multi-Architecture**: Optimized for ARM64, works great on AMD64 too
- 🧪 **Thoroughly Tested**: Comprehensive test suite ensures reliability
- 🔒 **Secure Base**: Built on official PostgreSQL Alpine images
- 📦 **Latest Versions**: PostgreSQL 17 + PostGIS 3.5.3

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
docker pull ghcr.io/clevercactus-dev/coolify-postgresql:latest

# Run a container
docker run -d \
  --name postgis \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  ghcr.io/clevercactus-dev/coolify-postgresql:latest
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

| Variable            | Description                    | Default                    |
|---------------------|--------------------------------|----------------------------|
| `POSTGRES_PASSWORD` | PostgreSQL password (required) | -                          |
| `POSTGRES_USER`     | PostgreSQL username            | `postgres`                 |
| `POSTGRES_DB`       | Database name                  | `postgres`                 |
| `PGDATA`            | Data directory                 | `/var/lib/postgresql/data` |

All standard PostgreSQL environment variables are supported. See
the [official PostgreSQL Docker documentation](https://hub.docker.com/_/postgres) for more details.

### Using with Docker Compose

```yaml
version: '3'
services:
  postgis:
    image: ghcr.io/clevercactus-dev/coolify-postgresql:latest
    environment:
      POSTGRES_PASSWORD: mysecretpassword
      POSTGRES_DB: mydb
    ports:
      - "5432:5432"
    volumes:
      - postgis-data:/var/lib/postgresql/data

volumes:
  postgis-data:
```

## 🔨 Building

To build the image locally:

```bash
# Clone the repository
git clone https://github.com/clevercactus-dev/coolify-postgresql.git
cd coolify-postgresql

# Build the image
docker build -t coolify-postgresql:latest .
```

### Building for Multiple Architectures

```bash
docker buildx create --name mybuilder --use
docker buildx build --platform linux/amd64,linux/arm64 -t coolify-postgresql:latest .
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
