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

# Helper: expand ${VAR} templates using env vars (envsubst if available)
expand_vars() {
    local raw="$1"
    if command -v envsubst >/dev/null 2>&1; then
        printf '%s' "$raw" | envsubst
    else
        # fallback: eval with env vars (safe for simple ${VAR} patterns)
        eval "printf '%s' \"$raw\""
    fi
}

# Resolve Docker Hub image + URL
DH_IMAGE=""
DH_URL=""
DH_ENABLED=$(echo "$CONFIG" | jq -r '.registry.dockerhub.enabled')
if [ "$DH_ENABLED" = "true" ]; then
    DH_USER_RAW=$(echo "$CONFIG" | jq -r '.registry.dockerhub.username // ""')
    DH_USER_EXPANDED=$(expand_vars "$DH_USER_RAW")
    DH_USER="${DOCKERHUB_USERNAME:-$DH_USER_EXPANDED}"
    # fallback if still contains ${...} or empty
    if [ -z "$DH_USER" ] || [[ "$DH_USER" == *"\${"* ]]; then
        DH_USER="${DOCKERHUB_USERNAME:-}"
    fi
    DH_NAME=$(echo "$CONFIG" | jq -r '.registry.dockerhub.image_name // "freebuff-proxy-docker"')
    DH_IMAGE="$DH_USER/$DH_NAME"
    DH_URL_RAW=$(echo "$CONFIG" | jq -r '.registry.dockerhub.repo_url // ""')
    if [ -n "$DH_URL_RAW" ] && [ "$DH_URL_RAW" != "null" ] && [ "$DH_URL_RAW" != "" ]; then
        DH_URL=$(expand_vars "$DH_URL_RAW")
    else
        DH_URL="https://hub.docker.com/r/$DH_IMAGE"
    fi
    # ensure DH_URL still has no unexpanded vars
    DH_URL=$(expand_vars "$DH_URL")
fi

# Resolve GHCR image + URL
GH_IMAGE=""
GH_URL=""
GH_ENABLED=$(echo "$CONFIG" | jq -r '.registry.ghcr.enabled')
if [ "$GH_ENABLED" = "true" ]; then
    GH_USER_RAW=$(echo "$CONFIG" | jq -r '.registry.ghcr.username // ""')
    GH_USER_EXPANDED=$(expand_vars "$GH_USER_RAW")
    GH_USER="${GITHUB_REPOSITORY_OWNER:-$GH_USER_EXPANDED}"
    if [ -z "$GH_USER" ] || [[ "$GH_USER" == *"\${"* ]]; then
        GH_USER="${GITHUB_REPOSITORY_OWNER:-}"
    fi
    GH_NAME=$(echo "$CONFIG" | jq -r '.registry.ghcr.image_name // "freebuff-proxy-docker"')
    GH_IMAGE="ghcr.io/$GH_USER/$GH_NAME"
    GH_URL_RAW=$(echo "$CONFIG" | jq -r '.registry.ghcr.repo_url // ""')
    if [ -n "$GH_URL_RAW" ] && [ "$GH_URL_RAW" != "null" ] && [ "$GH_URL_RAW" != "" ]; then
        GH_URL=$(expand_vars "$GH_URL_RAW")
    else
        # fallback: use REPO if available, else GH_USER/GH_NAME
        if [ -n "$REPO" ] && [ "$REPO" != "" ]; then
            GH_URL="https://github.com/$REPO/pkgs/container/$GH_NAME"
        else
            GH_URL="https://github.com/$GH_USER/pkgs/container/$GH_NAME"
        fi
    fi
    GH_URL=$(expand_vars "$GH_URL")
fi

# Build legacy image list (for Discord/Slack backward compat)
IMAGES=""
IMAGES_VERSION_JSON="[]"
IMAGES_LATEST_JSON="[]"
if [ "$DH_ENABLED" = "true" ] && [ -n "$DH_IMAGE" ]; then
    IMAGES="$IMAGES
📦 Docker Hub: \`$DH_IMAGE:$TAG\`"
    IMAGES_VERSION_JSON=$(echo "$IMAGES_VERSION_JSON" | jq --arg v "$DH_IMAGE:$TAG" '. + [$v]')
    IMAGES_LATEST_JSON=$(echo "$IMAGES_LATEST_JSON" | jq --arg v "$DH_IMAGE:latest" '. + [$v]')
fi
if [ "$GH_ENABLED" = "true" ] && [ -n "$GH_IMAGE" ]; then
    IMAGES="$IMAGES
📦 GHCR: \`$GH_IMAGE:$TAG\`"
    IMAGES_VERSION_JSON=$(echo "$IMAGES_VERSION_JSON" | jq --arg v "$GH_IMAGE:$TAG" '. + [$v]')
    IMAGES_LATEST_JSON=$(echo "$IMAGES_LATEST_JSON" | jq --arg v "$GH_IMAGE:latest" '. + [$v]')
fi

# Build images string for JSON (handles multi-line safely)
IMAGES_JSON=$(printf '%s' "$IMAGES" | jq -Rs '.')

# Builder version + platforms from config
BUILDER_VER=$(echo "$CONFIG" | jq -r '.version // "1.1.0"')
UPSTREAM_REPO=$(echo "$CONFIG" | jq -r '.project.upstream.repo // "trefeon/freebuff-proxy"')
PLATFORMS_STR=$(echo "$CONFIG" | jq -r '.build.platforms // ["linux/amd64","linux/arm64"] | join(", ")')
TG_CHANNEL_SILENT=$(echo "$CONFIG" | jq -r '.notifications.telegram.channel_silent // true')
TG_INLINE_KB=$(echo "$CONFIG" | jq -r '.notifications.telegram.inline_keyboard // true')

# Build duration: prefer BUILD_STARTED_AT env (set in workflow), fallback to empty
BUILD_DURATION=""
if [ -n "${BUILD_STARTED_AT:-}" ] && [ "$BUILD_STARTED_AT" != "" ]; then
    # BUILD_STARTED_AT is epoch seconds
    NOW_EPOCH=$(date +%s)
    ELAPSED=$((NOW_EPOCH - BUILD_STARTED_AT))
    if [ "$ELAPSED" -lt 0 ]; then ELAPSED=0; fi
    if [ "$ELAPSED" -ge 3600 ]; then
        H=$((ELAPSED / 3600)); M=$(((ELAPSED % 3600) / 60)); S=$((ELAPSED % 60))
        BUILD_DURATION=$(printf "%dh %dm %ds" "$H" "$M" "$S")
    elif [ "$ELAPSED" -ge 60 ]; then
        M=$((ELAPSED / 60)); S=$((ELAPSED % 60))
        BUILD_DURATION=$(printf "%dm %ds" "$M" "$S")
    else
        BUILD_DURATION=$(printf "%ds" "$ELAPSED")
    fi
fi

jq -n \
    --arg status "$STATUS" \
    --arg tag "$TAG" \
    --argjson images "$IMAGES_JSON" \
    --arg build_status "$BUILD_STATUS" \
    --arg mirror_status "$MIRROR_STATUS" \
    --arg notify_mode "$NOTIFY_MODE" \
    --arg repo "$REPO" \
    --arg run_url "$RUN_URL" \
    --arg builder_version "$BUILDER_VER" \
    --arg upstream_repo "$UPSTREAM_REPO" \
    --arg dockerhub_image "$DH_IMAGE" \
    --arg ghcr_image "$GH_IMAGE" \
    --arg dockerhub_url "$DH_URL" \
    --arg ghcr_url "$GH_URL" \
    --arg platforms "$PLATFORMS_STR" \
    --arg build_duration "$BUILD_DURATION" \
    --argjson channel_silent "$TG_CHANNEL_SILENT" \
    --argjson inline_keyboard "$TG_INLINE_KB" \
    --argjson images_version "$IMAGES_VERSION_JSON" \
    --argjson images_latest "$IMAGES_LATEST_JSON" \
    '{
      status: $status,
      tag: $tag,
      images: $images,
      images_version: $images_version,
      images_latest: $images_latest,
      dockerhub_image: $dockerhub_image,
      ghcr_image: $ghcr_image,
      dockerhub_url: $dockerhub_url,
      ghcr_url: $ghcr_url,
      platforms: $platforms,
      build_duration: $build_duration,
      channel_silent: $channel_silent,
      inline_keyboard: $inline_keyboard,
      build_status: $build_status,
      mirror_status: $mirror_status,
      notify_mode: $notify_mode,
      repo: $repo,
      run_url: $run_url,
      builder_version: $builder_version,
      upstream_repo: $upstream_repo
    }' | jq -c .