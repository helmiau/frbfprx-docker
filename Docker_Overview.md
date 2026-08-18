# freebuff-proxy-docker

[![Docker Release Builder](https://github.com/trefeon/freebuff-proxy-docker/actions/workflows/docker-release.yml/badge.svg)](https://github.com/trefeon/freebuff-proxy-docker/actions/workflows/docker-release.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/YOUR_USERNAME/freebuff-proxy-docker)](https://hub.docker.com/r/YOUR_USERNAME/freebuff-proxy-docker)
[![Docker Image Size](https://img.shields.io/docker/image-size/YOUR_USERNAME/freebuff-proxy-docker/latest)](https://hub.docker.com/r/YOUR_USERNAME/freebuff-proxy-docker)

Auto-built Docker images for [freebuff-proxy](https://github.com/trefeon/freebuff-proxy) — a lightweight Go-based proxy server. Images are automatically built and pushed on every new upstream release.

## Supported Platforms

- `linux/amd64`
- `linux/arm64`

## Tags

| Tag Pattern | Example | Description |
|-------------|---------|-------------|
| `latest` | `latest` | Always points to the newest upstream release |
| `v<semver>` | `v0.9.7` | Pinned to a specific upstream version |

## Quick Start

```bash
docker run -d \
  --name freebuff-proxy \
  -p 3457:3457 \
  YOUR_USERNAME/freebuff-proxy-docker:latest
```

The proxy will be available on port **3457**.

## Configuration

All configuration is handled via environment variables. Refer to the [upstream documentation](https://github.com/trefeon/freebuff-proxy) for available options.

### Example with custom config

```bash
docker run -d \
  --name freebuff-proxy \
  -p 3457:3457 \
  -e "PROXY_CONFIG=your-config-value" \
  YOUR_USERNAME/freebuff-proxy-docker:latest
```

## How It Works

This repository automatically:

1. **Checks** for new upstream releases every 6 hours
2. **Builds** multi-architecture Docker images (amd64 + arm64)
3. **Pushes** to Docker Hub (and optionally GitHub Container Registry)
4. **Notifies** via Telegram/Discord/Slack on build results

No upstream fork is required — everything is driven by a configurable CI/CD pipeline.

## Source

The Dockerfile and build automation are available on GitHub:

[https://github.com/trefeon/freebuff-proxy-docker](https://github.com/trefeon/freebuff-proxy-docker)

## License

MIT — same as upstream.