---
name: check-updates
description: "Check whether ai-dev-bootstrap-mac has updates and guide safe application. Use when the user says 'check for updates', 'am I up to date', 'update my tools', 'get latest skills', or asks whether OpenCode/JustVibes/bootstrap assets are current."
---

# Check Updates

Use the bundled update checker to see whether this bootstrap has newer managed assets available.

## Script

Run this script for machine-readable output:

```bash
$AI_BOOTSTRAP_WORKSPACE/scripts/agent/bootstrap-update-check.sh --json
```

## Workflow

1. **Check** — Run `$AI_BOOTSTRAP_WORKSPACE/scripts/agent/bootstrap-update-check.sh --json` and parse the JSON.
   - If it returns `{ "error": "..." }`, explain the error in plain language and stop.
   - Do not reimplement git comparison logic in the prompt.

2. **Report plainly** — Translate category counts into user-facing language:
   - `skills` → AI skills
   - `commands` → slash commands
   - `scripts` → helper scripts
   - `config` → OpenCode/bootstrap configuration
   - `launcher` → JustVibes launcher
   - `other` → project documentation or maintenance files

3. **If current** — If `up_to_date` is `true`, say the tools are up to date. No further action is needed.

4. **If updates exist** — Say how many commits are available and summarize the affected categories. Ask whether the user wants to apply the updates now. Do not apply updates without explicit approval.

5. **Detached HEAD handling** — If `detached_head` is `true`, explain that this install is pinned to a tag or exact version, so a normal `git pull` is not appropriate. Offer the curl fallback instead:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/skwid138/ai-dev-bootstrap-mac/main/install.sh)" -s -- --update
   ```

6. **Apply after approval** — If the user approves and `detached_head` is `false`, run:

   ```bash
   cd "$AI_BOOTSTRAP_DIR" && git pull --ff-only && ./bootstrap.sh --update
   ```

   This command should trigger normal permission approval. Do not bypass it.

7. **After applying** — Tell the user to quit and reopen JustVibes so OpenCode reloads the latest skills, commands, instructions, and permissions.

## Rules

- No proactive or startup polling. Only check when the user asks or when a routing instruction suggests `/check-updates`.
- Never run `git pull` on a detached HEAD; use the curl fallback.
- Never force-pull, reset, clean, or discard local changes.
- Keep the explanation non-technical: what changed and what to do next.
