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

| Secret | Required For | How to Get |
|--------|-------------|------------|
| `DOCKERHUB_USERNAME` | Docker Hub | Your Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub | [Create access token](https://hub.docker.com/settings/security) |
| `TELEGRAM_BOT_TOKEN` | Telegram | See [Telegram Setup Guide](#-telegram-setup-guide) below |
| `TELEGRAM_CHAT_ID` | Telegram | See [Telegram Setup Guide](#-telegram-setup-guide) below |
| `DISCORD_WEBHOOK_URL` | Discord | Server Settings → Integrations → Webhooks |
| `SLACK_WEBHOOK_URL` | Slack | [Incoming Webhooks](https://api.slack.com/messaging/webhooks) |

### 4. Enable GitHub Actions

Workflows run automatically every 6 hours. To trigger manually:

**Actions → Docker Release Builder → Run workflow**

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

### Notification Modes

| Mode | When Notified | Use Case |
|------|---------------|----------|
| `success` | Only when build succeeds | Track successful releases |
| `failure` | Only when build fails | Alert on errors (quiet) |
| `both` | Always | Full visibility (default) |
| `quiet` | Never | Silent operation |

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
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Configure  │ → │    Build    │ → │   Mirror    │ → │   Notify    │
│  (read cfg) │    │(multi-arch) │    │(GH Release) │    │(Discord/    │
│  (check ver)│    │             │    │             │    │ Slack/TG)   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
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
