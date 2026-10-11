---
name: deploy-config
description: Pull the latest pushed commits into the running Home Assistant pod, validate the config, and reload. Use after changes are pushed to GitHub, or when the user asks to deploy, sync, apply, or reload config.
---

# Deploy config to Home Assistant

Deploys commits already pushed to GitHub into the running pod, then validates and reloads. Stop and report at any failure. Never reset, discard, stash or force anything unless the user confirms (step 4 rollback only).

Pod target: namespace `default`, deployment `home-assistant`, container `code-server`. Git and the deploy key live in that container; `/config` is shared with the `app` container. The deploy key is read-only: the pod can fetch and pull, not push.

Define for all pod commands:

    kubectl -n default exec deploy/home-assistant -c code-server -- git -C /config <args>

Keep output at each step to a line or two.

## 1. Preconditions (local)
- Run `git status -sb` and `git fetch`.
- Stop if there are uncommitted changes or the branch is ahead of `origin/master`. Say which. Offer to commit/push but do not push to master without asking.

## 2. Show what will change
- Pod: `git -C /config fetch origin`
- Pod: `git -C /config rev-parse HEAD` (record as PREVIOUS_SHA)
- Pod: `git -C /config diff --stat HEAD origin/master`
- Summarize changed files. If there are none, say the pod is already current and stop.

## 3. Pull
- Pod: `git -C /config status --short`
- For each dirty file under `.storage/lovelace*` (HA rewrites these on dashboard saves): if `git -C /config diff --quiet origin/master -- <file>` exits 0, the pod copy already equals the incoming version. Ask the user to confirm, then run `git -C /config checkout -- <file>`.
- Any other dirty file, or a `.storage/lovelace*` file that differs from `origin/master`: print the files and stop. Ask the user how to proceed. Do not reset or discard. A differing dashboard file means the live dashboard has changes not in git; run `tools/sync-dashboards.sh`, commit, and push first.
- Pod: `git -C /config pull --ff-only`

To capture dashboard edits made through the MCP into the repo, run `tools/sync-dashboards.sh` locally, then commit and push before deploying.

## 4. Validate
- `ha_get_system_health(include="config_check")`.
- If invalid: stop, print the errors, do not reload. State that the pod is now on the new commit. Offer rollback with `git -C /config reset --hard <PREVIOUS_SHA>` and run it only after the user confirms.

## 5. Reload
Choose by changed paths:
- `automation/`, `automations.yaml`, `blueprints/`: `ha_reload_core(target="automations")`
- `scripts/`: `ha_reload_core(target="scripts")`
- `config/template.yaml`: `ha_reload_core(target="templates")`
- `config/input_*.yaml`, `config/timer.yaml`: matching target (`input_booleans`, `input_datetimes`, `input_numbers`, `timers`, ...)
- `config/groups.yaml`, `config/zones.yaml`: `groups`, `zones`
- `themes/`: `themes`
- anything else reloadable or mixed: `ha_reload_core` with `target="all"`

If `configuration.yaml`, packages, or a key with no reload service changed (for example a new helper domain key), say a restart is required and ask before calling `ha_restart(confirm=True)`.
Docs-only changes (`docs/`, `tools/`, `*.md`, `.claude/`) need no reload.

## 6. Verify
- `ha_get_logs(source="system")` and check for new errors since the reload.
- Report: previous sha, new sha, what was reloaded, errors found (or none). Include automation or entity counts only if useful.
