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
BUILDER_VER="${BUILDER_VERSION:-1.1.0}"

case "$PROVIDER" in
    discord)
        if [ "$STATUS" = "SUCCESS" ]; then
            COLOR=3066993
        else
            COLOR=15158332
        fi

        PAYLOAD_JSON=$(jq -n \
            --arg status "$STATUS" \
            --arg tag "$TAG" \
            --arg images "$IMAGES" \
            --arg run_url "$RUN_URL" \
            --arg notify_mode "$NOTIFY_MODE" \
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
                  {name: "Run", value: "[View Logs](\($run_url))", inline: true}
                ],
                timestamp: $timestamp
              }]
            }')

        curl -sL -X POST "$DISCORD_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD_JSON"
        ;;

    slack)
        if [ "$STATUS" = "SUCCESS" ]; then
            EMOJI="✅"
            COLOR="#36a64f"
        else
            EMOJI="❌"
            COLOR="#ff0000"
        fi

        PAYLOAD_JSON=$(jq -n \
            --arg color "$COLOR" \
            --arg emoji "$EMOJI" \
            --arg status "$STATUS" \
            --arg tag "$TAG" \
            --arg notify_mode "$NOTIFY_MODE" \
            --arg images "$IMAGES" \
            --arg run_url "$RUN_URL" \
            --arg footer "Docker Builder v${BUILDER_VER}" \
            --argjson ts "$(date +%s)" \
            '{
              attachments: [{
                color: $color,
                title: "\($emoji) freebuff-proxy Build \($status)",
                fields: [
                  {title: "Version", value: $tag, short: true},
                  {title: "Notify Mode", value: $notify_mode, short: true},
                  {title: "Images", value: $images, short: false},
                  {title: "Run URL", value: $run_url, short: false}
                ],
                footer: $footer,
                ts: $ts
              }]
            }')

        curl -sL -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD_JSON"
        ;;

    telegram)
        if [ "$STATUS" = "SUCCESS" ]; then
            EMOJI="✅"
        else
            EMOJI="❌"
        fi

        # Build image list with bullet points
        IMAGES_BULLETS=$(echo "$IMAGES" | sed 's/^/• /')

        MESSAGE="${EMOJI} <b>freebuff-proxy Build ${STATUS}</b>

<b>Version:</b> <code>${TAG}</code>
<b>Notify Mode:</b> <code>${NOTIFY_MODE}</code>
<b>Images:</b>
${IMAGES_BULLETS}

<b>Run:</b> <a href=\"${RUN_URL}\">View Logs</a>

<i>Builder v${BUILDER_VER}</i>"

        curl -sL -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "parse_mode=HTML" \
            --data-urlencode "text=${MESSAGE}" \
            -d "disable_web_page_preview=true"
        ;;

    *)
        echo "❌ Unknown provider: $PROVIDER"
        exit 1
        ;;
esac

echo "✅ $PROVIDER notification sent"