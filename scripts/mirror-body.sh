#!/usr/bin/env bash
# ============================================
# Generate mirror release body
# Usage: mirror-body.sh <config_json> <tag> <builder_version>
# Output: prints the release body to stdout
# ============================================

set -euo pipefail

CONFIG="${1:-}"
TAG="${2:-}"
BUILDER_VER="${3:-1.1.0}"

if [ -z "$CONFIG" ] || [ -z "$TAG" ]; then
    echo "❌ Usage: mirror-body.sh <config_json> <tag> [builder_version]"
    exit 1
fi

UPSTREAM_REPO=$(echo "$CONFIG" | jq -r '.project.upstream.repo')
PLATFORMS=$(echo "$CONFIG" | jq -r '.build.platforms | join(", ")')
MIRROR_MODE=$(echo "$CONFIG" | jq -r '.mirror.mode')

# Build Docker images section
IMAGES_SECTION=""
if [ "$(echo "$CONFIG" | jq -r '.registry.dockerhub.enabled')" = "true" ]; then
    # Prefer environment variable (set in workflow), fallback to config
    DH_USER="${DOCKERHUB_USERNAME:-$(echo "$CONFIG" | jq -r '.registry.dockerhub.username')}"
    DH_NAME=$(echo "$CONFIG" | jq -r '.registry.dockerhub.image_name')
    IMAGES_SECTION="${IMAGES_SECTION}
📦 Docker Hub: \`docker pull ${DH_USER}/${DH_NAME}:${TAG}\`"
fi
if [ "$(echo "$CONFIG" | jq -r '.registry.ghcr.enabled')" = "true" ]; then
    GH_USER="${GITHUB_REPOSITORY_OWNER:-$(echo "$CONFIG" | jq -r '.registry.ghcr.username')}"
    GH_NAME=$(echo "$CONFIG" | jq -r '.registry.ghcr.image_name')
    IMAGES_SECTION="${IMAGES_SECTION}
📦 GHCR: \`docker pull ghcr.io/${GH_USER}/${GH_NAME}:${TAG}\`"
fi
[ -z "$IMAGES_SECTION" ] && IMAGES_SECTION="None configured"

cat <<BODYEOF
🪞 Auto-mirrored release from upstream [${UPSTREAM_REPO}@${TAG}](https://github.com/${UPSTREAM_REPO}/releases/tag/${TAG})

## Docker Images
${IMAGES_SECTION}
## Platforms
${PLATFORMS}

## Builder Info
- Version: \`${BUILDER_VER}\`
- Mirror mode: \`${MIRROR_MODE}\`
BODYEOF