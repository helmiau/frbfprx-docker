#!/usr/bin/env bash
# ============================================
# Generate notification payload JSON
# Usage: notify-payload.sh <config_json> <tag> <build_status> <mirror_status> <notify_mode> <repo> <run_url>
# Output: prints compact JSON payload to stdout
# ============================================

set -euo pipefail

CONFIG="${1:-}"
TAG="${2:-}"
BUILD_STATUS="${3:-}"
MIRROR_STATUS="${4:-}"
NOTIFY_MODE="${5:-}"
REPO="${6:-}"
RUN_URL="${7:-}"

if [ -z "$CONFIG" ] || [ -z "$TAG" ]; then
    echo '{"error":"Usage: notify-payload.sh <config_json> <tag> <build_status> <mirror_status> <notify_mode> <repo> <run_url>"}'
    exit 1
fi

# Determine overall status
if [ "$BUILD_STATUS" = "success" ]; then
    STATUS="SUCCESS"
else
    STATUS="FAILED"
fi

# Build image list
IMAGES=""
if [ "$(echo "$CONFIG" | jq -r '.registry.dockerhub.enabled')" = "true" ]; then
    DH_USER=$(echo "$CONFIG" | jq -r '.registry.dockerhub.username' | envsubst)
    DH_NAME=$(echo "$CONFIG" | jq -r '.registry.dockerhub.image_name')
    IMAGES="$IMAGES
📦 Docker Hub: \`$DH_USER/$DH_NAME:$TAG\`"
fi
if [ "$(echo "$CONFIG" | jq -r '.registry.ghcr.enabled')" = "true" ]; then
    GH_USER=$(echo "$CONFIG" | jq -r '.registry.ghcr.username' | envsubst)
    GH_NAME=$(echo "$CONFIG" | jq -r '.registry.ghcr.image_name')
    IMAGES="$IMAGES
📦 GHCR: \`ghcr.io/$GH_USER/$GH_NAME:$TAG\`"
fi

# Build images array for JSON (handles multi-line safely)
IMAGES_JSON=$(printf '%s' "$IMAGES" | jq -Rs '.')

jq -n \
    --arg status "$STATUS" \
    --arg tag "$TAG" \
    --argjson images "$IMAGES_JSON" \
    --arg build_status "$BUILD_STATUS" \
    --arg mirror_status "$MIRROR_STATUS" \
    --arg notify_mode "$NOTIFY_MODE" \
    --arg repo "$REPO" \
    --arg run_url "$RUN_URL" \
    '{
      status: $status,
      tag: $tag,
      images: $images,
      build_status: $build_status,
      mirror_status: $mirror_status,
      notify_mode: $notify_mode,
      repo: $repo,
      run_url: $run_url
    }' | jq -c .