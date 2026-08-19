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

# Helper: expand ${VAR} templates
expand_vars() {
    local raw="$1"
    if command -v envsubst >/dev/null 2>&1; then
        printf '%s' "$raw" | envsubst
    else
        eval "printf '%s' \"$raw\""
    fi
}

# Build Docker images section — config-driven, no hardcoded URLs
IMAGES_SECTION=""
if [ "$(echo "$CONFIG" | jq -r '.registry.dockerhub.enabled')" = "true" ]; then
    DH_USER_RAW=$(echo "$CONFIG" | jq -r '.registry.dockerhub.username // ""')
    DH_USER_EXPANDED=$(expand_vars "$DH_USER_RAW")
    DH_USER="${DOCKERHUB_USERNAME:-$DH_USER_EXPANDED}"
    [ -z "$DH_USER" ] || [[ "$DH_USER" == *"\${"* ]] && DH_USER="${DOCKERHUB_USERNAME:-}"
    DH_NAME=$(echo "$CONFIG" | jq -r '.registry.dockerhub.image_name // "freebuff-proxy-docker"')
    DH_URL_RAW=$(echo "$CONFIG" | jq -r '.registry.dockerhub.repo_url // ""')
    if [ -n "$DH_URL_RAW" ] && [ "$DH_URL_RAW" != "null" ] && [ "$DH_URL_RAW" != "" ]; then
        DH_URL=$(expand_vars "$DH_URL_RAW")
    else
        DH_URL="https://hub.docker.com/r/$DH_USER/$DH_NAME"
    fi
    IMAGES_SECTION="${IMAGES_SECTION}
📦 Docker Hub: \`docker pull ${DH_USER}/${DH_NAME}:${TAG}\` — [View on Docker Hub](${DH_URL})"
fi
if [ "$(echo "$CONFIG" | jq -r '.registry.ghcr.enabled')" = "true" ]; then
    GH_USER_RAW=$(echo "$CONFIG" | jq -r '.registry.ghcr.username // ""')
    GH_USER_EXPANDED=$(expand_vars "$GH_USER_RAW")
    GH_USER="${GITHUB_REPOSITORY_OWNER:-$GH_USER_EXPANDED}"
    [ -z "$GH_USER" ] || [[ "$GH_USER" == *"\${"* ]] && GH_USER="${GITHUB_REPOSITORY_OWNER:-}"
    GH_NAME=$(echo "$CONFIG" | jq -r '.registry.ghcr.image_name // "freebuff-proxy-docker"')
    GH_URL_RAW=$(echo "$CONFIG" | jq -r '.registry.ghcr.repo_url // ""')
    if [ -n "$GH_URL_RAW" ] && [ "$GH_URL_RAW" != "null" ] && [ "$GH_URL_RAW" != "" ]; then
        GH_URL=$(expand_vars "$GH_URL_RAW")
    else
        GH_URL="https://github.com/${GITHUB_REPOSITORY:-$GH_USER/$GH_NAME}/pkgs/container/$GH_NAME"
    fi
    GH_URL=$(expand_vars "$GH_URL")
    IMAGES_SECTION="${IMAGES_SECTION}
📦 GHCR: \`docker pull ghcr.io/${GH_USER}/${GH_NAME}:${TAG}\` — [View on GHCR](${GH_URL})"
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