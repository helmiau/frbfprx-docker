#!/usr/bin/env bash
# ============================================
# Quick release checker v1.1.0
# ============================================

CONFIG_FILE="$(dirname "$0")/../config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ config.json not found"
    exit 1
fi

UPSTREAM=$(jq -r '.project.upstream.repo' "$CONFIG_FILE")
USE_SEMVER=$(jq -r '.build.use_exact_semver' "$CONFIG_FILE")
PROJECT=$(jq -r '.project.name' "$CONFIG_FILE")

if [ -z "$UPSTREAM" ] || [ "$UPSTREAM" = "null" ]; then
    echo "❌ Upstream repo not configured"
    exit 1
fi

echo "🔍 Checking $UPSTREAM..."
LATEST=$(curl -sL "https://api.github.com/repos/$UPSTREAM/releases/latest")

if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
    echo "❌ Failed to fetch release"
    exit 1
fi

TAG=$(echo "$LATEST" | jq -r '.tag_name')
PUBLISHED=$(echo "$LATEST" | jq -r '.published_at')
ASSETS=$(echo "$LATEST" | jq -r '.assets | length')
URL=$(echo "$LATEST" | jq -r '.html_url')

[ "$USE_SEMVER" = "true" ] && DOCKER_TAG="$TAG" || DOCKER_TAG="${TAG#v}"

echo ""
echo "┌────────────────────────────────────────┐"
echo "│  📦 Upstream Release Info              │"
echo "├────────────────────────────────────────┤"
printf "│  %-36s │\n" "Project: $PROJECT"
printf "│  %-36s │\n" "Tag:        $TAG"
printf "│  %-36s │\n" "Docker Tag: $DOCKER_TAG"
printf "│  %-36s │\n" "Published:  $PUBLISHED"
printf "│  %-36s │\n" "Assets:     $ASSETS files"
printf "│  %-36s │\n" "URL:        $URL"
echo "└────────────────────────────────────────┘"

# Check registries
DOCKERHUB=$(jq -r '.registry.dockerhub.enabled' "$CONFIG_FILE")
GHCR=$(jq -r '.registry.ghcr.enabled' "$CONFIG_FILE")

echo ""
echo "🔎 Registry checks:"

if [ "$DOCKERHUB" = "true" ]; then
    DH_USER=$(jq -r '.registry.dockerhub.username' "$CONFIG_FILE")
    DH_NAME=$(jq -r '.registry.dockerhub.image_name' "$CONFIG_FILE")
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        "https://hub.docker.com/v2/repositories/$DH_USER/$DH_NAME/tags/$DOCKER_TAG" 2>/dev/null)
    if [ "$HTTP_STATUS" = "200" ]; then
        echo "  ✅ Docker Hub: $DH_USER/$DH_NAME:$DOCKER_TAG exists"
    else
        echo "  ❌ Docker Hub: $DH_USER/$DH_NAME:$DOCKER_TAG not found"
    fi
fi

if [ "$GHCR" = "true" ]; then
    GH_USER=$(jq -r '.registry.ghcr.username' "$CONFIG_FILE")
    GH_NAME=$(jq -r '.registry.ghcr.image_name' "$CONFIG_FILE")
    echo "  ℹ️  GHCR: ghcr.io/$GH_USER/$GH_NAME:$DOCKER_TAG (check via GitHub UI)"
fi

# Check local
echo ""
if docker images "$PROJECT" --format "{{.Tag}}" 2>/dev/null | grep -q "^$DOCKER_TAG$"; then
    echo "✅ Local image: $PROJECT:$DOCKER_TAG exists"
else
    echo "❌ Local image: $PROJECT:$DOCKER_TAG not found"
fi
