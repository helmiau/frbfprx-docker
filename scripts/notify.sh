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

        # Build image list with bullet points
        IMAGES_BULLETS=$(echo "$IMAGES" | sed 's/^/• /')

        MESSAGE="${EMOJI} <b>freebuff-proxy Build ${STATUS}</b>

<b>Version:</b> <code>${TAG}</code>
<b>Notify Mode:</b> <code>${NOTIFY_MODE}</code>
<b>Images:</b>
${IMAGES_BULLETS}

<b>Run:</b> <a href=\"${RUN_URL}\">View Logs</a>

<i>Builder v${BUILDER_VER}</i>"

        # Send to each target (comma-separated), non-blocking per target
        IFS=',' read -ra TG_TARGETS <<< "$TELEGRAM_TARGETS"
        TG_FAILED=0
        for TG_CHAT in "${TG_TARGETS[@]}"; do
            TG_CHAT=$(echo "$TG_CHAT" | xargs)  # trim whitespace
            [ -z "$TG_CHAT" ] && continue
            echo "  📤 Sending to $TG_CHAT ..."
            HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
                -d "chat_id=${TG_CHAT}" \
                -d "parse_mode=HTML" \
                --data-urlencode "text=${MESSAGE}" \
                -d "disable_web_page_preview=true" || echo "000")
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