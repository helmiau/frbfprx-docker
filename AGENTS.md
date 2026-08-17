# AGENTS.md
# frbfprx-docker Builder

**Version:** 1.1.0  
**Purpose:** Agent instruction and context for AI assistants working on this project  
**Last Updated:** 2026-08-17

---

## 1. Project Overview

This is an **auto-builder** project that builds Docker images for the upstream `trefeon/freebuff-proxy` repository **without forking it**.

### Key Principles
- **Zero Fork:** Never fork or modify upstream code
- **Config-Driven:** All behavior controlled via `config.json`
- **Multi-Registry:** Support Docker Hub and GHCR simultaneously
- **Multi-Notify:** Support Discord, Slack, Telegram
- **Multi-Arch:** Build for linux/amd64 and linux/arm64

---

## 2. Architecture for Agents

### 2.1 File Structure

```
.
├── .github/
│   └── workflows/
│       └── docker-release.yml    # Main CI/CD workflow
├── scripts/
│   ├── build.sh                  # CLI tool (v1.1.0)
│   └── check-release.sh          # Quick release checker
├── config.json                   # ⭐ SINGLE SOURCE OF TRUTH
├── PRD.md                        # Product Requirements Document
├── AGENTS.md                     # This file
└── README.md                     # User documentation
```

### 2.2 Workflow Stages

```
Configure → Build → Mirror → Notify
   ↑           ↓       ↓        ↓
config.json  Docker   GH      Discord/Slack/TG
```

**Configure Stage:**
- Reads `config.json`
- Fetches upstream release via GitHub API
- Checks if image already exists in registry
- Decides: build or skip

**Build Stage (conditional):**
- Downloads upstream source tarball
- Builds multi-arch image with Docker Buildx
- Pushes to enabled registries
- Uses cache if `build.cache_enabled = true`

**Mirror Stage (conditional):**
- Downloads upstream assets based on `mirror.mode`
- Creates GitHub Release in builder repo

**Notify Stage (conditional):**
- Sends notifications based on `notifications.mode`
- Only sends to enabled providers

---

## 3. Configuration Reference for Agents

### 3.1 Critical Config Keys

When modifying workflow or scripts, always respect these config keys:

| Config Path | Type | Impact |
|-------------|------|--------|
| `project.upstream.repo` | string | Which repo to watch |
| `build.use_exact_semver` | boolean | Tag format: `v0.9.7` vs `0.9.7` |
| `build.cache_enabled` | boolean | Enable/disable GHA cache |
| `registry.dockerhub.enabled` | boolean | Push to Docker Hub |
| `registry.ghcr.enabled` | boolean | Push to GHCR |
| `notifications.enabled` | boolean | Master switch for notifications |
| `notifications.mode` | enum | `success`/`failure`/`both`/`quiet` |
| `mirror.enabled` | boolean | Master switch for mirroring |
| `mirror.mode` | enum | `all`/`source-only`/`checksums-only` |

### 3.2 Notification Mode Logic

```
if notifications.enabled == false:
    skip notify stage

if notifications.mode == "quiet":
    skip notify stage

if notifications.mode == "success" and build.result != "success":
    skip notify stage

if notifications.mode == "failure" and build.result == "success":
    skip notify stage

# Otherwise, send notification
```

### 3.3 Mirror Mode Logic

```
if mirror.mode == "all":
    download all upstream assets + source tarball

if mirror.mode == "source-only":
    download only source tarball + zipball

if mirror.mode == "checksums-only":
    download only checksums.txt
```

---

## 4. Coding Guidelines for Agents

### 4.1 Workflow YAML Rules
- Always use `fromJson(needs.configure.outputs.config)` to access config values
- Use conditional `if:` for stage gating, not shell conditionals
- Cache must be conditional: `${{ fromJson(...).build.cache_enabled == true && 'type=gha' || '' }}`
- Never hardcode upstream repo; always read from config

### 4.2 Shell Script Rules
- Use `jq` for JSON parsing
- Use `envsubst` for variable substitution in config values
- Validate config before operations
- Use `set -euo pipefail` for strict mode
- Use color-coded logging functions

### 4.3 Config Modification Rules
- Preserve `_schema` and `_help` fields
- Maintain backward compatibility when adding keys
- Use semantic versioning for `config.version`
- Add `_help` text for new enum fields

---

## 5. Common Tasks for Agents

### 5.1 Add New Notification Provider

1. Add provider block to `config.json`:
```json
"webhook": {
  "enabled": false,
  "url": "${WEBHOOK_URL}"
}
```

2. Add secret to workflow inputs

3. Add notify step in workflow:
```yaml
- name: 🔔 Webhook Notification
  if: fromJson(needs.configure.outputs.config).notifications.webhook.enabled == true
  run: |
    # Implementation
```

4. Update `scripts/build.sh` toggle menu

5. Update `PRD.md` feature matrix

### 5.2 Add New Registry

1. Add registry block to `config.json`
2. Add login step in workflow (conditional)
3. Add tag generation in Configure stage
4. Update `scripts/build.sh` push logic

### 5.3 Modify Build Behavior

1. Update `config.json` schema
2. Update Configure stage to read new key
3. Update Build stage to use new key
4. Update `scripts/build.sh` for CLI parity
5. Update validation logic

---

## 6. Testing Checklist for Agents

Before submitting changes:

- [ ] `config.json` validates with `jq . config.json`
- [ ] `./scripts/build.sh validate` passes
- [ ] Workflow YAML syntax valid (use `actionlint` if available)
- [ ] All config paths referenced in workflow exist in schema
- [ ] No hardcoded values that should be in config
- [ ] Secrets referenced match GitHub Actions naming convention
- [ ] Conditional logic handles all enum values

---

## 7. Troubleshooting Guide for Agents

### Issue: Image not pushed
- Check `registry.*.enabled` in config
- Check secrets are set in GitHub Settings
- Check registry login step ran (look for conditional)

### Issue: Notification not sent
- Check `notifications.enabled` and `notifications.mode`
- Check provider-specific `enabled` flag
- Check if build stage actually ran (not skipped)
- Check secret values for provider

### Issue: Mirror release empty
- Check `mirror.enabled` and `mirror.mode`
- Check upstream release has assets
- Check `create_github_release` is true

### Issue: Build uses wrong tag
- Check `build.use_exact_semver` value
- Check upstream tag format

### Issue: Cache not working
- Check `build.cache_enabled` is true
- Check `docker/build-push-action` cache inputs

---

## 8. Context for Future Agents

### Upstream Details
- **Repo:** `trefeon/freebuff-proxy`
- **Language:** Go 1.26
- **Base Image:** Alpine 3.20
- **Port:** 3457
- **Dockerfile:** Valid, multi-stage build

### Builder Details
- **Image Name:** `frbfprx-docker`
- **Platforms:** linux/amd64, linux/arm64
- **Schedule:** Every 6 hours (configurable)
- **Builder Version:** 1.1.0

### When to Ask User
- Changing upstream repository
- Adding new build platforms
- Modifying security boundaries
- Breaking config schema changes
