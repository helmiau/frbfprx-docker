#!/usr/bin/env bash
# ============================================
# freebuff-proxy Docker Builder CLI v1.1.0
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.json"
VERSION="1.1.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# Helpers
# ============================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }
log_cyan() { echo -e "${CYAN}$1${NC}"; }

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_err "config.json not found at $CONFIG_FILE"
        exit 1
    fi
    cat "$CONFIG_FILE"
}

# ============================================
# Banner
# ============================================
show_banner() {
    CONFIG=$(load_config)
    PROJECT=$(echo "$CONFIG" | jq -r '.project.name')
    UPSTREAM=$(echo "$CONFIG" | jq -r '.project.upstream.repo')
    SEMVER=$(echo "$CONFIG" | jq -r '.build.use_exact_semver')
    CACHE=$(echo "$CONFIG" | jq -r '.build.cache_enabled')
    DOCKERHUB=$(echo "$CONFIG" | jq -r '.registry.dockerhub.enabled')
    GHCR=$(echo "$CONFIG" | jq -r '.registry.ghcr.enabled')
    NOTIFY=$(echo "$CONFIG" | jq -r '.notifications.enabled')
    NOTIFY_MODE=$(echo "$CONFIG" | jq -r '.notifications.mode')
    MIRROR=$(echo "$CONFIG" | jq -r '.mirror.enabled')
    MIRROR_MODE=$(echo "$CONFIG" | jq -r '.mirror.mode')

    echo ""
    log_cyan "╔══════════════════════════════════════════════════════════════╗"
    log_cyan "║     🐳 $PROJECT Builder CLI v${VERSION}              ║"
    log_cyan "╠══════════════════════════════════════════════════════════════╣"
    printf "║  %-58s ║\n" "Upstream: ${UPSTREAM}"
    printf "║  %-58s ║\n" "Semver: ${SEMVER} | Cache: ${CACHE}"
    printf "║  %-58s ║\n" "DockerHub: ${DOCKERHUB} | GHCR: ${GHCR}"
    printf "║  %-58s ║\n" "Notify: ${NOTIFY} (${NOTIFY_MODE}) | Mirror: ${MIRROR} (${MIRROR_MODE})"
    log_cyan "╠══════════════════════════════════════════════════════════════╣"
    log_cyan "║  [1] Check latest upstream release                           ║"
    log_cyan "║  [2] Build Docker image locally                              ║"
    log_cyan "║  [3] Build & push to configured registries                   ║"
    log_cyan "║  [4] Toggle config features                                  ║"
    log_cyan "║  [5] Show current config                                     ║"
    log_cyan "║  [6] Validate config                                         ║"
    log_cyan "║  [0] Exit                                                    ║"
    log_cyan "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================
# Feature 1: Check Release
# ============================================
check_release() {
    CONFIG=$(load_config)
    UPSTREAM=$(echo "$CONFIG" | jq -r '.project.upstream.repo')
    USE_SEMVER=$(echo "$CONFIG" | jq -r '.build.use_exact_semver')

    log_info "Checking latest release from $UPSTREAM..."

    LATEST=$(curl -sL "https://api.github.com/repos/$UPSTREAM/releases/latest")
    TAG=$(echo "$LATEST" | jq -r '.tag_name')
    PUBLISHED=$(echo "$LATEST" | jq -r '.published_at')
    BODY=$(echo "$LATEST" | jq -r '.body' | head -6)
    ASSETS=$(echo "$LATEST" | jq -r '.assets | length')

    [ "$USE_SEMVER" = "true" ] && DOCKER_TAG="$TAG" || DOCKER_TAG="${TAG#v}"

    echo ""
    echo "┌─────────────────────────────────────────┐"
    echo "│  🏷️  Latest Upstream Release            │"
    echo "├─────────────────────────────────────────┤"
    echo "│  Tag:        $TAG"
    echo "│  Docker Tag: $DOCKER_TAG"
    echo "│  Published:  $PUBLISHED"
    echo "│  Assets:     $ASSETS files"
    echo "├─────────────────────────────────────────┤"
    echo "│  Changelog (first 5 lines):"
    echo "$BODY" | sed 's/^/│  /'
    echo "└─────────────────────────────────────────┘"

    # Check local image
    if docker images "freebuff-proxy" --format "{{.Tag}}" 2>/dev/null | grep -q "^$DOCKER_TAG$"; then
        log_ok "Image freebuff-proxy:$DOCKER_TAG exists locally"
    else
        log_warn "Image freebuff-proxy:$DOCKER_TAG not found locally"
    fi
}

# ============================================
# Feature 2: Local Build
# ============================================
build_local() {
    CONFIG=$(load_config)
    UPSTREAM=$(echo "$CONFIG" | jq -r '.project.upstream.repo')
    USE_SEMVER=$(echo "$CONFIG" | jq -r '.build.use_exact_semver')
    PLATFORMS=$(echo "$CONFIG" | jq -r '.build.platforms | join(",")')
    CACHE=$(echo "$CONFIG" | jq -r '.build.cache_enabled')

    log_info "Fetching latest release..."
    LATEST=$(curl -sL "https://api.github.com/repos/$UPSTREAM/releases/latest")
    TAG=$(echo "$LATEST" | jq -r '.tag_name')
    TARBALL=$(echo "$LATEST" | jq -r '.tarball_url')

    [ "$USE_SEMVER" = "true" ] && DOCKER_TAG="$TAG" || DOCKER_TAG="${TAG#v}"

    log_info "Downloading $TAG..."
    TMPDIR=$(mktemp -d)
    curl -sL "$TARBALL" -o "$TMPDIR/upstream.tar.gz"
    tar -xzf "$TMPDIR/upstream.tar.gz" --strip-components=1 -C "$TMPDIR"
    rm "$TMPDIR/upstream.tar.gz"

    log_info "Building image (tag: freebuff-proxy:$DOCKER_TAG)"
    log_info "Platforms: $PLATFORMS"
    log_info "Cache: $CACHE"

    cd "$TMPDIR"

    # For local build, only build current platform
    docker build -t "freebuff-proxy:$DOCKER_TAG" -t "freebuff-proxy:latest" .

    log_ok "Build complete!"
    echo ""
    docker images "freebuff-proxy" --format "  • {{.Repository}}:{{.Tag}} ({{.Size}})"

    rm -rf "$TMPDIR"
}

# ============================================
# Feature 3: Build & Push
# ============================================
build_and_push() {
    log_warn "This requires Docker Hub / GHCR login."
    log_info "Ensure you have run: docker login"
    read -p "Continue? (y/N): " confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || return

    build_local

    CONFIG=$(load_config)
    USE_SEMVER=$(echo "$CONFIG" | jq -r '.build.use_exact_semver')
    TAG=$(curl -sL "https://api.github.com/repos/$(echo "$CONFIG" | jq -r '.project.upstream.repo')/releases/latest" | jq -r '.tag_name')
    [ "$USE_SEMVER" = "true" ] && DOCKER_TAG="$TAG" || DOCKER_TAG="${TAG#v}"

    # Docker Hub
    if [ "$(echo "$CONFIG" | jq -r '.registry.dockerhub.enabled')" = "true" ]; then
        USER=$(echo "$CONFIG" | jq -r '.registry.dockerhub.username')
        NAME=$(echo "$CONFIG" | jq -r '.registry.dockerhub.image_name')
        log_info "Pushing to Docker Hub ($USER/$NAME)..."
        docker tag "freebuff-proxy:$DOCKER_TAG" "$USER/$NAME:$DOCKER_TAG"
        docker tag "freebuff-proxy:$DOCKER_TAG" "$USER/$NAME:latest"
        docker push "$USER/$NAME:$DOCKER_TAG"
        docker push "$USER/$NAME:latest"
        log_ok "Docker Hub push complete!"
    fi

    # GHCR
    if [ "$(echo "$CONFIG" | jq -r '.registry.ghcr.enabled')" = "true" ]; then
        USER=$(echo "$CONFIG" | jq -r '.registry.ghcr.username')
        NAME=$(echo "$CONFIG" | jq -r '.registry.ghcr.image_name')
        log_info "Pushing to GHCR (ghcr.io/$USER/$NAME)..."
        docker tag "freebuff-proxy:$DOCKER_TAG" "ghcr.io/$USER/$NAME:$DOCKER_TAG"
        docker tag "freebuff-proxy:$DOCKER_TAG" "ghcr.io/$USER/$NAME:latest"
        docker push "ghcr.io/$USER/$NAME:$DOCKER_TAG"
        docker push "ghcr.io/$USER/$NAME:latest"
        log_ok "GHCR push complete!"
    fi
}

# ============================================
# Feature 4: Toggle Config
# ============================================
toggle_config() {
    CONFIG=$(load_config)

    echo ""
    echo "Toggle features (current values):"
    echo "  1. use_exact_semver:  $(echo "$CONFIG" | jq -r '.build.use_exact_semver')"
    echo "  2. cache_enabled:     $(echo "$CONFIG" | jq -r '.build.cache_enabled')"
    echo "  3. dockerhub:         $(echo "$CONFIG" | jq -r '.registry.dockerhub.enabled')"
    echo "  4. ghcr:              $(echo "$CONFIG" | jq -r '.registry.ghcr.enabled')"
    echo "  5. notifications:     $(echo "$CONFIG" | jq -r '.notifications.enabled')"
    echo "  6. notify_mode:       $(echo "$CONFIG" | jq -r '.notifications.mode')"
    echo "  7. mirror:            $(echo "$CONFIG" | jq -r '.mirror.enabled')"
    echo "  8. mirror_mode:       $(echo "$CONFIG" | jq -r '.mirror.mode')"
    echo ""
    read -p "Enter number to toggle (or 0 to cancel): " choice

    case $choice in
        1) KEY=".build.use_exact_semver" ;; 
        2) KEY=".build.cache_enabled" ;;
        3) KEY=".registry.dockerhub.enabled" ;;
        4) KEY=".registry.ghcr.enabled" ;;
        5) KEY=".notifications.enabled" ;;
        6) 
            echo "Notify modes: success | failure | both | quiet"
            read -p "Enter new mode: " new_mode
            jq ".notifications.mode = \"$new_mode\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            log_ok "Notify mode changed to: $new_mode"
            return
            ;;
        7) KEY=".mirror.enabled" ;;
        8) 
            echo "Mirror modes: all | source-only | checksums-only"
            read -p "Enter new mode: " new_mode
            jq ".mirror.mode = \"$new_mode\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            log_ok "Mirror mode changed to: $new_mode"
            return
            ;;
        0) return ;;
        *) log_err "Invalid choice"; return ;;
    esac

    CURRENT=$(echo "$CONFIG" | jq -r "$KEY")
    NEW=$( [ "$CURRENT" = "true" ] && echo "false" || echo "true" )

    jq "$KEY = $NEW" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    log_ok "Toggled $KEY: $CURRENT → $NEW"
}

# ============================================
# Feature 5: Show Config
# ============================================
show_config() {
    echo ""
    echo "📋 Current Configuration:"
    load_config | jq .
}

# ============================================
# Feature 6: Validate Config
# ============================================
validate_config() {
    CONFIG=$(load_config)
    ERRORS=0

    echo ""
    echo "🔍 Validating config.json..."

    # Check required fields
    [ -z "$(echo "$CONFIG" | jq -r '.project.upstream.repo')" ] && { log_err "project.upstream.repo is required"; ERRORS=$((ERRORS+1)); }
    [ -z "$(echo "$CONFIG" | jq -r '.version')" ] && { log_err "version is required"; ERRORS=$((ERRORS+1)); }
    [ -z "$(echo "$CONFIG" | jq -r '.project.name')" ] && { log_err "project.name is required"; ERRORS=$((ERRORS+1)); }

    # Check semver consistency
    SEMVER=$(echo "$CONFIG" | jq -r '.build.use_exact_semver')
    [ "$SEMVER" != "true" ] && [ "$SEMVER" != "false" ] && { log_err "build.use_exact_semver must be true or false"; ERRORS=$((ERRORS+1)); }

    # Check at least one registry enabled
    DH=$(echo "$CONFIG" | jq -r '.registry.dockerhub.enabled')
    GH=$(echo "$CONFIG" | jq -r '.registry.ghcr.enabled')
    [ "$DH" != "true" ] && [ "$GH" != "true" ] && { log_warn "No registry enabled — images won't be pushed"; }

    # Check notification mode
    NOTIFY=$(echo "$CONFIG" | jq -r '.notifications.enabled')
    if [ "$NOTIFY" = "true" ]; then
        MODE=$(echo "$CONFIG" | jq -r '.notifications.mode')
        [ "$MODE" != "success" ] && [ "$MODE" != "failure" ] && [ "$MODE" != "both" ] && [ "$MODE" != "quiet" ] && {
            log_err "notifications.mode must be: success | failure | both | quiet"; ERRORS=$((ERRORS+1))
        }

        DISCORD=$(echo "$CONFIG" | jq -r '.notifications.discord.enabled')
        SLACK=$(echo "$CONFIG" | jq -r '.notifications.slack.enabled')
        TG=$(echo "$CONFIG" | jq -r '.notifications.telegram.enabled')
        [ "$DISCORD" != "true" ] && [ "$SLACK" != "true" ] && [ "$TG" != "true" ] && {
            log_warn "Notifications enabled but no provider enabled"
        }
    fi

    # Check mirror mode
    MIRROR=$(echo "$CONFIG" | jq -r '.mirror.enabled')
    if [ "$MIRROR" = "true" ]; then
        MODE=$(echo "$CONFIG" | jq -r '.mirror.mode')
        [ "$MODE" != "all" ] && [ "$MODE" != "source-only" ] && [ "$MODE" != "checksums-only" ] && {
            log_err "mirror.mode must be: all | source-only | checksums-only"; ERRORS=$((ERRORS+1))
        }
    fi

    # Check cache
    CACHE=$(echo "$CONFIG" | jq -r '.build.cache_enabled')
    [ "$CACHE" != "true" ] && [ "$CACHE" != "false" ] && { log_err "build.cache_enabled must be true or false"; ERRORS=$((ERRORS+1)); }

    if [ $ERRORS -eq 0 ]; then
        log_ok "Config is valid! ✨"
    else
        log_err "Found $ERRORS error(s)"
        exit 1
    fi
}

# ============================================
# Main
# ============================================
main() {
    case "${1:-}" in
        check|chk) check_release ;;
        build|b) build_local ;;
        push|p) build_and_push ;;
        validate|v) validate_config ;;
        config|c) show_config ;;
        toggle|t) toggle_config ;;
        menu|m|""|help)
            while true; do
                show_banner
                read -p "Select option: " opt
                case $opt in
                    1) check_release ;;
                    2) build_local ;;
                    3) build_and_push ;;
                    4) toggle_config ;;
                    5) show_config ;;
                    6) validate_config ;;
                    0) exit 0 ;;
                    *) log_err "Invalid option: $opt" ;;
                esac
                echo ""
                read -p "Press Enter to continue..."
            done
            ;;
        --version|-v) echo "freebuff-proxy-builder v$VERSION" ;;
        --help|-h)
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  check, chk     Check latest upstream release"
            echo "  build, b       Build Docker image locally"
            echo "  push, p        Build and push to registries"
            echo "  validate, v    Validate config.json"
            echo "  config, c      Show current config"
            echo "  toggle, t      Toggle config features"
            echo "  menu, m        Interactive menu (default)"
            echo ""
            echo "Options:"
            echo "  --version, -v  Show version"
            echo "  --help, -h     Show this help"
            ;;
        *) log_err "Unknown command: $1"; exit 1 ;;
    esac
}

main "$@"
