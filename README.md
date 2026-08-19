# 🐳 frbfprx-docker

Auto-build Docker images for [trefeon/freebuff-proxy](https://github.com/trefeon/freebuff-proxy) on every new upstream release **without forking upstream**.

## ✨ Features

| Feature | Config Key | Default | Options |
|---------|-----------|---------|---------|
| Exact SemVer Tag | `build.use_exact_semver` | `true` | `true` / `false` |
| Build Cache | `build.cache_enabled` | `true` | `true` / `false` |
| Docker Hub | `registry.dockerhub.enabled` | `true` | `true` / `false` |
| GHCR | `registry.ghcr.enabled` | `false` | `true` / `false` |
| Notifications | `notifications.enabled` | `true` | `true` / `false` |
| Notify Mode | `notifications.mode` | `"both"` | `"success"` / `"failure"` / `"both"` / `"quiet"` |
| Mirror Release | `mirror.enabled` | `true` | `true` / `false` |
| Mirror Mode | `mirror.mode` | `"all"` | `"all"` / `"source-only"` / `"checksums-only"` |

## 🚀 Quick Start

### 1. Create Repository

Create a new repository on GitHub (e.g., `yourusername/frbfprx-docker`) and copy these files into it:

```
.github/workflows/docker-release.yml
scripts/build.sh
scripts/check-release.sh
config.json
PRD.md
AGENTS.md
README.md
```

### 2. Edit `config.json`

At minimum, update these fields:

```json
{
  "registry": {
    "dockerhub": {
      "enabled": true,
      "username": "${DOCKERHUB_USERNAME}",
      "image_name": "frbfprx-docker"
    }
  }
}
```

> **Note:** `${DOCKERHUB_USERNAME}` will be replaced by the GitHub Secret value. Do NOT put your actual username here.

### 3. Add GitHub Secrets

Go to **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Required For | How to Get | Status |
|--------|-------------|------------|--------|
| `DOCKERHUB_USERNAME` | Docker Hub | Your Docker Hub username | **Required** |
| `DOCKERHUB_TOKEN` | Docker Hub | [Create access token](https://hub.docker.com/settings/security) | **Required** |
| `TELEGRAM_BOT_TOKEN` | Telegram | See [Telegram Setup Guide](#-telegram-setup-guide) below | Optional |
| `TELEGRAM_CHAT_ID` | Telegram (private/group) | See [Telegram Setup Guide](#-telegram-setup-guide) below | Optional |
| `TELEGRAM_CHANNEL_CHAT_ID` | Telegram (public channel) | See [Telegram Channel Setup](#-telegram-channel-setup-public-channel) below | Optional |
| `DISCORD_WEBHOOK_URL` | Discord | Server Settings → Integrations → Webhooks | Optional |
| `SLACK_WEBHOOK_URL` | Slack | [Incoming Webhooks](https://api.slack.com/messaging/webhooks) | Optional |

### 4. Enable GitHub Actions

This project uses multiple triggers to stay up-to-date with upstream:

| Trigger | Workflow | Interval | Description |
|---------|----------|----------|-------------|
| **Upstream Watcher** | `upstream-watcher.yml` | Every 10 minutes | Polls `trefeon/freebuff-proxy` releases; dispatches `upstream-release` event if a new tag is missing in registries |
| **Scheduled Build** | `docker-release.yml` | Every 3 hours | Fallback polling — builds if image is missing |
| **Repository Dispatch** | `docker-release.yml` | On-demand | Triggered automatically by the watcher via `upstream-release` event |
| **Manual Dispatch** | `docker-release.yml` | On-demand | **Actions → Docker Release Builder → Run workflow** (use `force_build: true` to rebuild) |
| **Config Push** | `docker-release.yml` | On push to `main` | Rebuilds when `config.json` or workflow file changes |

No additional setup is required — the watcher runs automatically once the workflows are enabled. Just push the files and enable Actions.

---

## 📱 Telegram Setup Guide

### Step 1: Create a Bot with @BotFather

1. Open Telegram and search for **[@BotFather](https://t.me/BotFather)**
2. Send `/start` then `/newbot`
3. Follow the prompts:
   - **Name:** `freebuff-proxy-builder` (display name)
   - **Username:** `yourname_freebuff_bot` (must end with `_bot`, unique globally)
4. BotFather will reply with your **HTTP API token**:
   ```
   Use this token to access the HTTP API:
   123456789:ABCdefGHIjklMNOpqrSTUvwxyz123456789
   ```
5. **Copy this token** → save as GitHub Secret `TELEGRAM_BOT_TOKEN`

### Step 2: Get Your Chat ID

**Option A: Via getUpdates API (Recommended)**

1. Send `/start` to your newly created bot
2. Open this URL in browser (replace `<TOKEN>` with your actual token):
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
3. Look for the `chat` object in the JSON response:
   ```json
   {
     "ok": true,
     "result": [{
       "message": {
         "chat": {
           "id": 123456789,
           "first_name": "YourName",
           "type": "private"
         }
       }
     }]
   }
   ```
4. **Copy the `id` value** (e.g., `123456789`) → save as GitHub Secret `TELEGRAM_CHAT_ID`

**Option B: Via @userinfobot**

1. Search for **[@userinfobot](https://t.me/userinfobot)** on Telegram
2. Send `/start`
3. The bot will reply with your info, including:
   ```
   Id: 123456789
   First: YourName
   ```
4. **Copy the `Id` value** → save as GitHub Secret `TELEGRAM_CHAT_ID`

### Step 3: Test Your Bot

Send a test message via browser:
```
https://api.telegram.org/bot<TOKEN>/sendMessage?chat_id=<CHAT_ID>&text=Hello+from+freebuff-proxy-builder
```

You should receive the message in Telegram.

### Step 4: Enable in config.json

```json
{
  "notifications": {
    "enabled": true,
    "mode": "both",
    "telegram": {
      "enabled": true,
      "bot_token": "${TELEGRAM_BOT_TOKEN}",
      "chat_id": "${TELEGRAM_CHAT_ID}"
    }
  }
}
```

### 📢 Telegram Channel Setup (Public Channel)

To also send notifications to a **public Telegram channel** (in addition to your private chat):

#### Step 1: Create a Channel

1. In Telegram, tap **New Channel** → set name (e.g., `freebuff-proxy releases`) → choose **Public channel**
2. Set a username, e.g., `@my_freebuff_channel` — this is your channel's public link: `t.me/my_freebuff_channel`

#### Step 2: Add Your Bot as Admin

1. Open the channel → **Channel Info → Administrators → Add Administrator**
2. Search for your bot username (e.g., `@yourname_freebuff_bot`) and add it
3. Grant at least **Post messages** permission (no other permissions needed)

> ⚠️ **Required:** The bot must be an admin in the channel, otherwise Telegram returns `403 Forbidden` / `400 Bad Request: chat not found`.

#### Step 3: Get the Channel Chat ID

**Option A — Use @username (simplest):**

Use the channel username directly as the chat ID: `@my_freebuff_channel`

**Option B — Use numeric ID:**

1. Post any message in the channel
2. Forward that message to **[@userinfobot](https://t.me/userinfobot)** or **[@getidsbot](https://t.me/getidsbot)**
3. The bot will reply with the channel ID, e.g., `-1001234567890` (channels always start with `-100`)

#### Step 4: Add the Secret

Go to **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value | Example |
|--------|-------|---------|
| `TELEGRAM_CHANNEL_CHAT_ID` | Channel username or numeric ID | `@my_freebuff_channel` or `-1001234567890` |

#### Step 5: Enable in config.json

```json
{
  "notifications": {
    "telegram": {
      "enabled": true,
      "bot_token": "${TELEGRAM_BOT_TOKEN}",
      "chat_id": "${TELEGRAM_CHAT_ID}",
      "channel_chat_id": "${TELEGRAM_CHANNEL_CHAT_ID}"
    }
  }
}
```

> **Notes:**
> - You can use **both** `TELEGRAM_CHAT_ID` (private/group) and `TELEGRAM_CHANNEL_CHAT_ID` (public channel) at the same time — the bot will send to all configured destinations.
> - Both fields support **comma-separated** lists, e.g., `TELEGRAM_CHAT_ID: "123456789,987654321"` or `TELEGRAM_CHANNEL_CHAT_ID: "@chan1,@chan2"`.
> - If `TELEGRAM_CHANNEL_CHAT_ID` is empty/not set, it is silently skipped (non-blocking).
> - Test manually: `https://api.telegram.org/bot<TOKEN>/sendMessage?chat_id=@my_freebuff_channel&text=Hello+channel`

### Notification Modes

| Mode | When Notified | Use Case |
|------|---------------|----------|
| `success` | Only when build succeeds | Track successful releases |
| `failure` | Only when build fails | Alert on errors (quiet) |
| `both` | Always | Full visibility (default) |
| `quiet` | Never | Silent operation |

### Missing/Invalid Secrets Handling

Notifications are **non-blocking and auto-skip**. If any of `DISCORD_WEBHOOK_URL`, `SLACK_WEBHOOK_URL`, `TELEGRAM_BOT_TOKEN`, or `TELEGRAM_CHAT_ID` is empty, not set, or returns an invalid API response (non-2xx), then:

1. That provider is **automatically skipped** without failing the workflow
2. Full details are **logged in GitHub Actions** (e.g., `⚠️ TELEGRAM_BOT_TOKEN is empty or not set, skipping`)
3. Other valid providers continue to work
4. Build, push, and mirror stages **still run to completion**

Example log output when secrets are incomplete:

```
📤 Sending discord notification...
  ⚠️ DISCORD_WEBHOOK_URL is empty or not set, skipping Discord notification
📤 Sending telegram notification...
  ℹ️  Bot token and chat ID configured, sending...
  ℹ️  Telegram responded with HTTP 200
```

---

## 🖥️ CLI Usage

```bash
# Make scripts executable
chmod +x scripts/build.sh scripts/check-release.sh

# Interactive menu
./scripts/build.sh

# Quick commands
./scripts/build.sh check      # Check upstream release
./scripts/build.sh build      # Build locally
./scripts/build.sh push       # Build & push
./scripts/build.sh validate   # Validate config
./scripts/build.sh config     # Show config
./scripts/build.sh toggle     # Toggle features

# Quick release check
./scripts/check-release.sh
```

---

## 📋 Config Reference

```json
{
  "_schema": "freebuff-proxy-builder-config-v1",
  "version": "1.1.0",
  "project": {
    "name": "frbfprx-docker",
    "description": "Auto-build Docker images for trefeon/freebuff-proxy",
    "upstream": {
      "repo": "trefeon/freebuff-proxy",
      "branch": "main"
    }
  },
  "build": {
    "use_upstream_dockerfile": true,
    "platforms": ["linux/amd64", "linux/arm64"],
    "tag_prefix": "v",
    "use_exact_semver": true,
    "cache_enabled": true,
    "latest_always_newest": true
  },
  "registry": {
    "dockerhub": {
      "enabled": true,
      "username": "${DOCKERHUB_USERNAME}",
      "image_name": "frbfprx-docker"
    },
    "ghcr": {
      "enabled": false,
      "username": "${GITHUB_REPOSITORY_OWNER}",
      "image_name": "frbfprx-docker"
    }
  },
  "notifications": {
    "enabled": true,
    "mode": "both",
    "discord": { "enabled": false, "webhook_url": "${DISCORD_WEBHOOK_URL}" },
    "slack": { "enabled": false, "webhook_url": "${SLACK_WEBHOOK_URL}" },
    "telegram": { "enabled": true, "bot_token": "${TELEGRAM_BOT_TOKEN}", "chat_id": "${TELEGRAM_CHAT_ID}" }
  },
  "mirror": {
    "enabled": true,
    "mode": "all",
    "create_github_release": true,
    "release_prefix": "mirror-"
  },
  "schedule": {
    "check_interval": "0 */6 * * *",
    "timezone": "UTC"
  }
}
```

---

## 🔄 Workflow Stages

```
┌──────────────────┐
│ Upstream Watcher │  every 10 min — polls trefeon/freebuff-proxy
│  (watcher.yml)   │  dispatches `upstream-release` if new tag found
└────────┬─────────┘
         │ repository_dispatch
         ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Configure  │ → │    Build    │ → │   Mirror    │ → │   Notify    │
│  (read cfg) │    │(multi-arch) │    │(GH Release) │    │(Discord/    │
│  (check ver)│    │             │    │             │    │ Slack/TG)   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
         ▲
         │ also triggered by: schedule (3h) / push / manual dispatch
```

---

## 🧪 First-Time Testing (Recommended)

Before relying on the scheduled runs, test manually:

1. **Push all files** to your GitHub repo
2. **Add all secrets** in GitHub Settings
3. **Go to Actions tab** → "Docker Release Builder" → "Run workflow"
4. **Select `force_build: true`** for the first run
5. **Monitor the logs** in real-time
6. **Verify:**
   - Image appears on Docker Hub
   - Telegram notification received (if enabled)
   - Mirror release created (if enabled)

### Expected First Run Output

```
📋 Builder version: 1.1.0
🔧 Upstream: trefeon/freebuff-proxy
🏷️  Exact semver: true
📦 DockerHub: true
📦 GHCR: false
🔔 Notifications: true (mode: both)
📂 Mirror: true (mode: all)
💾 Cache: true

🔍 Fetching latest release from trefeon/freebuff-proxy...
🆕 New release detected: v0.9.7 (tag: v0.9.7)

📥 Downloading v0.9.7 from upstream...
🔧 Using upstream Dockerfile
🐳 Build and push
✅ Build completed successfully

🏷️ Create mirror release
📥 Downloading release assets... (mode: all)
  ↳ freebuff-proxy-linux-amd64
  ↳ freebuff-proxy-linux-arm64
  ↳ checksums.txt

✈️ Telegram Notification
✅ freebuff-proxy Build SUCCESS
```

---

## 📝 License

MIT — same as upstream.
