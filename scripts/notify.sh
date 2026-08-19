#!/usr/bin/env bash
# ============================================
# Notification dispatcher for freebuff-proxy builder
# Usage: notify.sh <provider> <payload_json>
# Providers: discord | slack | telegram
# ============================================

set -euo pipefail

PROVIDER="${1:-}"
PAYLOAD="${2:-}"

if [ -z "$PROVIDER" ] || [ -z "$PAYLOAD" ]; then
    echo "❌ Usage: notify.sh <provider> <payload_json>"
    exit 1
fi

# Extract common fields
STATUS=$(echo "$PAYLOAD" | jq -r '.status')
TAG=$(echo "$PAYLOAD" | jq -r '.tag')
IMAGES=$(echo "$PAYLOAD" | jq -r '.images')
RUN_URL=$(echo "$PAYLOAD" | jq -r '.run_url')
NOTIFY_MODE=$(echo "$PAYLOAD" | jq -r '.notify_mode')
REPO=$(echo "$PAYLOAD" | jq -r '.repo // ""')
BUILDER_VER=$(echo "$PAYLOAD" | jq -r '.builder_version // ""')
if [ -z "$BUILDER_VER" ] || [ "$BUILDER_VER" = "null" ]; then BUILDER_VER="${BUILDER_VERSION:-1.1.0}"; fi
UPSTREAM_REPO=$(echo "$PAYLOAD" | jq -r '.upstream_repo // "trefeon/freebuff-proxy"')
DOCKERHUB_IMAGE=$(echo "$PAYLOAD" | jq -r '.dockerhub_image // ""')
GHCR_IMAGE=$(echo "$PAYLOAD" | jq -r '.ghcr_image // ""')
DOCKERHUB_URL=$(echo "$PAYLOAD" | jq -r '.dockerhub_url // ""')
GHCR_URL=$(echo "$PAYLOAD" | jq -r '.ghcr_url // ""')
PLATFORMS=$(echo "$PAYLOAD" | jq -r '.platforms // ""')
BUILD_DURATION=$(echo "$PAYLOAD" | jq -r '.build_duration // ""')
CHANNEL_SILENT=$(echo "$PAYLOAD" | jq -r '.channel_silent // true')
INLINE_KB=$(echo "$PAYLOAD" | jq -r '.inline_keyboard // true')
# Arrays for structured rendering
IMAGES_VERSION_JSON=$(echo "$PAYLOAD" | jq -c '.images_version // []')
IMAGES_LATEST_JSON=$(echo "$PAYLOAD" | jq -c '.images_latest // []')

case "$PROVIDER" in
    discord)
        if [ -z "${DISCORD_WEBHOOK_URL:-}" ] || [ "$DISCORD_WEBHOOK_URL" = "" ]; then
            echo "⚠️ DISCORD_WEBHOOK_URL is empty or not set, skipping Discord notification"
            exit 0
        fi
        echo "  ℹ️  Webhook URL configured, sending..."

        if [ "$STATUS" = "SUCCESS" ]; then
            COLOR=3066993
        else
            COLOR=15158332
        fi

        # Build repo links line from config-driven URLs
        REPO_LINKS=""
        if [ -n "$DOCKERHUB_URL" ] && [ "$DOCKERHUB_URL" != "null" ] && [ "$DOCKERHUB_URL" != "" ]; then
            REPO_LINKS="[Docker Hub]($DOCKERHUB_URL)"
        fi
        if [ -n "$GHCR_URL" ] && [ "$GHCR_URL" != "null" ] && [ "$GHCR_URL" != "" ]; then
            if [ -n "$REPO_LINKS" ]; then REPO_LINKS="$REPO_LINKS | "; fi
            REPO_LINKS="${REPO_LINKS}[GHCR]($GHCR_URL)"
        fi
        [ -z "$REPO_LINKS" ] && REPO_LINKS="—"

        # Build images field: versioned + latest
        IMAGES_FIELD="$IMAGES"
        if [ "$(echo "$IMAGES_LATEST_JSON" | jq 'length')" -gt 0 ]; then
            LATEST_LINES=$(echo "$IMAGES_LATEST_JSON" | jq -r '.[] | "• `\(.)`"')
            IMAGES_FIELD="$IMAGES

Or use \`latest\`:
$LATEST_LINES"
        fi
        # Append platforms + duration if available
        EXTRA_FIELD=""
        if [ -n "$PLATFORMS" ] && [ "$PLATFORMS" != "null" ] && [ "$PLATFORMS" != "" ]; then
            EXTRA_FIELD="Platforms: \`$PLATFORMS\`"
        fi
        if [ -n "$BUILD_DURATION" ] && [ "$BUILD_DURATION" != "null" ] && [ "$BUILD_DURATION" != "" ]; then
            if [ -n "$EXTRA_FIELD" ]; then EXTRA_FIELD="$EXTRA_FIELD | "; fi
            EXTRA_FIELD="${EXTRA_FIELD}Build took \`$BUILD_DURATION\`"
        fi

        PAYLOAD_JSON=$(jq -n \
            --arg status "$STATUS" \
            --arg tag "$TAG" \
            --arg images "$IMAGES_FIELD" \
            --arg run_url "$RUN_URL" \
            --arg notify_mode "$NOTIFY_MODE" \
            --arg repo_links "$REPO_LINKS" \
            --arg repo "$REPO" \
            --arg builder_version "$BUILDER_VER" \
            --arg platforms "$PLATFORMS" \
            --arg build_duration "$BUILD_DURATION" \
            --arg extra "$EXTRA_FIELD" \
            --argjson color "$COLOR" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{
              embeds: [{
                title: "🐳 freebuff-proxy Build \($status)",
                color: $color,
                fields: [
                  {name: "Version", value: $tag, inline: true},
                  {name: "Notify Mode", value: $notify_mode, inline: true},
                  {name: "Images", value: $images, inline: false},
                  {name: "Repos", value: $repo_links, inline: false},
                  {name: "Run", value: "[View Logs](\($run_url))", inline: true},
                  {name: "Builder", value: $builder_version, inline: true}
                ] + (if $extra != "" then [{name: "Details", value: $extra, inline: false}] else [] end),
                footer: {text: $repo},
                timestamp: $timestamp
              }]
            }')

        HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" -X POST "$DISCORD_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD_JSON")
        echo "  ℹ️  Discord responded with HTTP $HTTP_CODE"
        ;;

    slack)
        if [ -z "${SLACK_WEBHOOK_URL:-}" ] || [ "$SLACK_WEBHOOK_URL" = "" ]; then
            echo "⚠️ SLACK_WEBHOOK_URL is empty or not set, skipping Slack notification"
            exit 0
        fi
        echo "  ℹ️  Webhook URL configured, sending..."

        if [ "$STATUS" = "SUCCESS" ]; then
            EMOJI="✅"
            COLOR="#36a64f"
        else
            EMOJI="❌"
            COLOR="#ff0000"
        fi

        # Build repo links for Slack
        REPO_LINKS_SLACK=""
        if [ -n "$DOCKERHUB_URL" ] && [ "$DOCKERHUB_URL" != "null" ] && [ "$DOCKERHUB_URL" != "" ]; then
            REPO_LINKS_SLACK="<$DOCKERHUB_URL|Docker Hub>"
        fi
        if [ -n "$GHCR_URL" ] && [ "$GHCR_URL" != "null" ] && [ "$GHCR_URL" != "" ]; then
            if [ -n "$REPO_LINKS_SLACK" ]; then REPO_LINKS_SLACK="$REPO_LINKS_SLACK | "; fi
            REPO_LINKS_SLACK="${REPO_LINKS_SLACK}<$GHCR_URL|GHCR>"
        fi
        [ -z "$REPO_LINKS_SLACK" ] && REPO_LINKS_SLACK="—"

        IMAGES_FIELD_SLACK="$IMAGES"
        if [ "$(echo "$IMAGES_LATEST_JSON" | jq 'length')" -gt 0 ]; then
            LATEST_LINES_SLACK=$(echo "$IMAGES_LATEST_JSON" | jq -r '.[] | "• `\(.)`"')
            IMAGES_FIELD_SLACK="$IMAGES

Or use \`latest\`:
$LATEST_LINES_SLACK"
        fi
        EXTRA_SLACK=""
        if [ -n "$PLATFORMS" ] && [ "$PLATFORMS" != "null" ] && [ "$PLATFORMS" != "" ]; then
            EXTRA_SLACK="Platforms: \`$PLATFORMS\`"
        fi
        if [ -n "$BUILD_DURATION" ] && [ "$BUILD_DURATION" != "null" ] && [ "$BUILD_DURATION" != "" ]; then
            if [ -n "$EXTRA_SLACK" ]; then EXTRA_SLACK="$EXTRA_SLACK | "; fi
            EXTRA_SLACK="${EXTRA_SLACK}Build took \`$BUILD_DURATION\`"
        fi
        if [ -n "$EXTRA_SLACK" ]; then
            IMAGES_FIELD_SLACK="$IMAGES_FIELD_SLACK

$EXTRA_SLACK"
        fi

        PAYLOAD_JSON=$(jq -n \
            --arg color "$COLOR" \
            --arg emoji "$EMOJI" \
            --arg status "$STATUS" \
            --arg tag "$TAG" \
            --arg notify_mode "$NOTIFY_MODE" \
            --arg images "$IMAGES_FIELD_SLACK" \
            --arg run_url "$RUN_URL" \
            --arg repo_links "$REPO_LINKS_SLACK" \
            --arg repo "$REPO" \
            --arg footer "Docker Builder v${BUILDER_VER} • $REPO" \
            --argjson ts "$(date +%s)" \
            '{
              attachments: [{
                color: $color,
                title: "\($emoji) freebuff-proxy Build \($status)",
                fields: [
                  {title: "Version", value: $tag, short: true},
                  {title: "Notify Mode", value: $notify_mode, short: true},
                  {title: "Images", value: $images, short: false},
                  {title: "Repos", value: $repo_links, short: false},
                  {title: "Run URL", value: $run_url, short: false}
                ],
                footer: $footer,
                ts: $ts
              }]
            }')

        HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD_JSON")
        echo "  ℹ️  Slack responded with HTTP $HTTP_CODE"
        ;;

    telegram)
        if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ "$TELEGRAM_BOT_TOKEN" = "" ]; then
            echo "⚠️ TELEGRAM_BOT_TOKEN is empty or not set, skipping Telegram notification"
            exit 0
        fi
        # Collect all Telegram destinations: TELEGRAM_CHAT_ID + TELEGRAM_CHANNEL_CHAT_ID
        # Supports comma-separated lists and @channelusername format
        TELEGRAM_TARGETS=""
        if [ -n "${TELEGRAM_CHAT_ID:-}" ] && [ "$TELEGRAM_CHAT_ID" != "" ]; then
            TELEGRAM_TARGETS="$TELEGRAM_CHAT_ID"
        fi
        if [ -n "${TELEGRAM_CHANNEL_CHAT_ID:-}" ] && [ "$TELEGRAM_CHANNEL_CHAT_ID" != "" ]; then
            if [ -n "$TELEGRAM_TARGETS" ]; then
                TELEGRAM_TARGETS="$TELEGRAM_TARGETS,$TELEGRAM_CHANNEL_CHAT_ID"
            else
                TELEGRAM_TARGETS="$TELEGRAM_CHANNEL_CHAT_ID"
            fi
        fi
        if [ -z "$TELEGRAM_TARGETS" ]; then
            echo "⚠️ TELEGRAM_CHAT_ID and TELEGRAM_CHANNEL_CHAT_ID are both empty, skipping Telegram notification"
            exit 0
        fi
        echo "  ℹ️  Bot token configured, targets: $TELEGRAM_TARGETS"

        if [ "$STATUS" = "SUCCESS" ]; then
            EMOJI="✅"
        else
            EMOJI="❌"
        fi

        # Build Telegram message — structured, config-driven, no hardcoded URLs
        # Versioned images
        TG_IMAGES_VERSION=""
        if [ "$(echo "$IMAGES_VERSION_JSON" | jq 'length')" -gt 0 ]; then
            while IFS= read -r img; do
                TG_IMAGES_VERSION="${TG_IMAGES_VERSION}• 📦 <code>${img}</code>
"
            done < <(echo "$IMAGES_VERSION_JSON" | jq -r '.[]')
        else
            TG_IMAGES_VERSION="• <i>No images configured</i>
"
        fi

        # Latest images
        TG_IMAGES_LATEST=""
        if [ "$(echo "$IMAGES_LATEST_JSON" | jq 'length')" -gt 0 ]; then
            while IFS= read -r img; do
                TG_IMAGES_LATEST="${TG_IMAGES_LATEST}• 📦 <code>${img}</code>
"
            done < <(echo "$IMAGES_LATEST_JSON" | jq -r '.[]')
        fi

        # Repo links line — fully config-driven
        TG_REPOS_LINE=""
        if [ -n "$DOCKERHUB_URL" ] && [ "$DOCKERHUB_URL" != "null" ] && [ "$DOCKERHUB_URL" != "" ]; then
            TG_REPOS_LINE="<a href=\"${DOCKERHUB_URL}\">Docker Hub</a>"
        fi
        if [ -n "$GHCR_URL" ] && [ "$GHCR_URL" != "null" ] && [ "$GHCR_URL" != "" ]; then
            if [ -n "$TG_REPOS_LINE" ]; then TG_REPOS_LINE="$TG_REPOS_LINE | "; fi
            TG_REPOS_LINE="${TG_REPOS_LINE}<a href=\"${GHCR_URL}\">GHCR</a>"
        fi
        if [ -n "$REPO" ] && [ "$REPO" != "null" ] && [ "$REPO" != "" ]; then
            if [ -n "$TG_REPOS_LINE" ]; then TG_REPOS_LINE="$TG_REPOS_LINE | "; fi
            TG_REPOS_LINE="${TG_REPOS_LINE}<a href=\"https://github.com/${REPO}\">GitHub</a>"
        fi

        # Upstream link
        TG_UPSTREAM_LINE="<a href=\"https://github.com/${UPSTREAM_REPO}/releases/tag/${TAG}\">${UPSTREAM_REPO}@${TAG}</a>"

        # Platforms + duration line
        TG_DETAILS_LINE=""
        if [ -n "$PLATFORMS" ] && [ "$PLATFORMS" != "null" ] && [ "$PLATFORMS" != "" ]; then
            TG_DETAILS_LINE="<b>Platforms:</b> <code>${PLATFORMS}</code>"
        fi
        if [ -n "$BUILD_DURATION" ] && [ "$BUILD_DURATION" != "null" ] && [ "$BUILD_DURATION" != "" ]; then
            if [ -n "$TG_DETAILS_LINE" ]; then TG_DETAILS_LINE="$TG_DETAILS_LINE | "; fi
            TG_DETAILS_LINE="${TG_DETAILS_LINE}<b>Build took:</b> <code>${BUILD_DURATION}</code>"
        fi

        if [ "$STATUS" = "SUCCESS" ]; then
            TG_TITLE="${EMOJI} <b>freebuff-proxy Build SUCCESS</b>"
            TG_LATEST_SECTION=""
            if [ -n "$TG_IMAGES_LATEST" ]; then
                TG_LATEST_SECTION="
Or use <code>latest</code> build:
${TG_IMAGES_LATEST}"
            fi
            MESSAGE="${TG_TITLE}

<b>Version:</b> <code>${TAG}</code>
<b>Upstream:</b> ${TG_UPSTREAM_LINE}
<b>Images:</b>
${TG_IMAGES_VERSION}${TG_LATEST_SECTION}"
            if [ -n "$TG_DETAILS_LINE" ]; then
                MESSAGE="${MESSAGE}
${TG_DETAILS_LINE}"
            fi
            MESSAGE="${MESSAGE}
<b>Repos:</b> ${TG_REPOS_LINE}
-------
<i>Builder v${BUILDER_VER}</i>"
        else
            MESSAGE="${EMOJI} <b>freebuff-proxy Build FAILED</b>

<b>Version:</b> <code>${TAG}</code>
<b>Upstream:</b> ${TG_UPSTREAM_LINE}
<b>Notify Mode:</b> <code>${NOTIFY_MODE}</code>
<b>Attempted Images:</b>
${TG_IMAGES_VERSION}"
            if [ -n "$TG_DETAILS_LINE" ]; then
                MESSAGE="${MESSAGE}
${TG_DETAILS_LINE}"
            fi
            MESSAGE="${MESSAGE}
<b>Repos:</b> ${TG_REPOS_LINE}
-------
<i>Builder v${BUILDER_VER}</i>"
        fi

        # Build inline keyboard JSON (config-driven URLs, no hardcoded values)
        TG_REPLY_MARKUP=""
        if [ "$INLINE_KB" = "true" ]; then
            KB_BUTTONS=()
            if [ -n "$RUN_URL" ] && [ "$RUN_URL" != "null" ] && [ "$RUN_URL" != "" ]; then
                KB_BUTTONS+=("{\"text\":\"📋 View Logs\",\"url\":\"$RUN_URL\"}")
            fi
            if [ -n "$DOCKERHUB_URL" ] && [ "$DOCKERHUB_URL" != "null" ] && [ "$DOCKERHUB_URL" != "" ]; then
                KB_BUTTONS+=("{\"text\":\"🐳 Docker Hub\",\"url\":\"$DOCKERHUB_URL\"}")
            fi
            if [ -n "$GHCR_URL" ] && [ "$GHCR_URL" != "null" ] && [ "$GHCR_URL" != "" ]; then
                KB_BUTTONS+=("{\"text\":\"📦 GHCR\",\"url\":\"$GHCR_URL\"}")
            fi
            if [ "${#KB_BUTTONS[@]}" -gt 0 ]; then
                # Join buttons into rows: first row = View Logs, second row = Docker Hub + GHCR
                if [ "${#KB_BUTTONS[@]}" -eq 3 ]; then
                    TG_REPLY_MARKUP="{\"inline_keyboard\":[[${KB_BUTTONS[0]}],[${KB_BUTTONS[1]},${KB_BUTTONS[2]}]]}"
                elif [ "${#KB_BUTTONS[@]}" -eq 2 ]; then
                    TG_REPLY_MARKUP="{\"inline_keyboard\":[[${KB_BUTTONS[0]},${KB_BUTTONS[1]}]]}"
                else
                    TG_REPLY_MARKUP="{\"inline_keyboard\":[[${KB_BUTTONS[0]}]]}"
                fi
            fi
        fi

        # Determine which targets are channels (for silent mode)
        # Channel targets are those in TELEGRAM_CHANNEL_CHAT_ID (comma-separated)
        CHANNEL_LIST="${TELEGRAM_CHANNEL_CHAT_ID:-}"

        # Send to each target (comma-separated), non-blocking per target
        IFS=',' read -ra TG_TARGETS <<< "$TELEGRAM_TARGETS"
        TG_FAILED=0
        for TG_CHAT in "${TG_TARGETS[@]}"; do
            TG_CHAT=$(echo "$TG_CHAT" | xargs)  # trim whitespace
            [ -z "$TG_CHAT" ] && continue

            # Silent only for channel targets when channel_silent=true
            TG_SILENT="false"
            if [ "$CHANNEL_SILENT" = "true" ] && [ -n "$CHANNEL_LIST" ]; then
                IFS=',' read -ra CH_LIST <<< "$CHANNEL_LIST"
                for CH in "${CH_LIST[@]}"; do
                    CH=$(echo "$CH" | xargs)
                    if [ "$TG_CHAT" = "$CH" ]; then
                        TG_SILENT="true"
                        break
                    fi
                done
            fi

            if [ "$TG_SILENT" = "true" ]; then
                echo "  📤 Sending to $TG_CHAT (silent/channel) ..."
            else
                echo "  📤 Sending to $TG_CHAT ..."
            fi

            # Build curl args
            CURL_ARGS=(
                -sL -o /dev/null -w "%{http_code}"
                -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
                -d "chat_id=${TG_CHAT}"
                -d "parse_mode=HTML"
                --data-urlencode "text=${MESSAGE}"
                -d "disable_web_page_preview=true"
            )
            if [ "$TG_SILENT" = "true" ]; then
                CURL_ARGS+=(-d "disable_notification=true")
            fi
            if [ -n "$TG_REPLY_MARKUP" ]; then
                CURL_ARGS+=(-d "reply_markup=${TG_REPLY_MARKUP}")
            fi

            HTTP_CODE=$(curl "${CURL_ARGS[@]}" || echo "000")
            echo "  ℹ️  Telegram ($TG_CHAT) responded with HTTP $HTTP_CODE"
            if [ "$HTTP_CODE" != "200" ]; then
                echo "  ⚠️ Failed to send to $TG_CHAT (HTTP $HTTP_CODE) — check bot is admin in channel / chat_id is correct"
                TG_FAILED=$((TG_FAILED + 1))
            fi
        done
        if [ "$TG_FAILED" -gt 0 ] && [ "$TG_FAILED" -eq "${#TG_TARGETS[@]}" ]; then
            echo "  ⚠️ All Telegram targets failed"
        fi
        ;;

    *)
        echo "❌ Unknown provider: $PROVIDER"
        exit 1
        ;;
esac

echo "✅ $PROVIDER notification sent"