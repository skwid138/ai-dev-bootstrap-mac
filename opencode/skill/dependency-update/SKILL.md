---
name: dependency-update
description: "Check OpenCode config dependencies for outdated or unpinned packages and apply updates. Use when the user says 'check for outdated packages', 'update dependencies', 'are my packages up to date', 'check opencode deps', or any request to audit or update npm package versions in the OpenCode configuration."
---

# Dependency Update

Use the bundled dependency checker to audit OpenCode configuration dependencies and guide safe updates.

## Script

Run this script; do not reimplement its dependency parsing or registry lookup logic in the prompt:

```bash
$AI_BOOTSTRAP_WORKSPACE/scripts/agent/opencode-deps-check.sh
```

Use `--json` when you need machine-readable output:

```bash
$AI_BOOTSTRAP_WORKSPACE/scripts/agent/opencode-deps-check.sh --json
```

## Workflow

1. **Check** — Run `$AI_BOOTSTRAP_WORKSPACE/scripts/agent/opencode-deps-check.sh --json` and parse the JSON output. It reports on:
   - `~/.config/opencode/package.json` dependencies
   - `~/.config/opencode/opencode.jsonc` (preferred) or `opencode.json` `plugin` array entries
   - `~/.config/opencode/opencode.jsonc` (preferred) or `opencode.json` MCP `command` arrays that reference npm packages

2. **Report** — Present a concise table. For each entry show package name, current version or `unpinned`, latest version or `unknown`, status, and location.

3. **Recommend** — For each `outdated` or `unpinned` entry, recommend one action:
   - `outdated` → bump to the latest resolved version
   - `unpinned` → pin to the latest resolved version
   - `unknown` → warn and continue; do not recommend a blind version change

4. **Confirm** — Ask the user which updates to apply. Accept `all`, a comma-separated list of package names, or `none`. Default to no edits unless the user explicitly approves specific changes.

5. **Apply** — Only after approval:
   - For `package.json` dependencies, edit the version string and run `npm install` from `~/.config/opencode/` to refresh `package-lock.json`.
   - For `opencode.jsonc`/`opencode.json` `plugin` entries, edit only the matching package version suffix in whichever file the script selected (use the reported `location`; `.jsonc` is preferred when both exist).
   - For `opencode.jsonc`/`opencode.json` MCP `command` arrays, edit only the matching command token in whichever file the script selected.

6. **Verify** — Re-run `$AI_BOOTSTRAP_WORKSPACE/scripts/agent/opencode-deps-check.sh` in human-output mode and show the updated state.

7. **Hand off** — Summarize what changed, list modified files, and remind the user to commit if they want a checkpoint. Do not commit unless explicitly asked.

## Rules

- Run the script; do not reimplement its logic in agent instructions.
- Never edit `opencode.jsonc` or `opencode.json` without explicit user approval of the specific changes.
- Preserve JSONC formatting and comments in the selected `opencode.jsonc`/`opencode.json`; use targeted string replacements instead of full-file rewrites.
- Registry lookup failures are warn and continue: keep unresolved packages as `unknown`, report the warning, and do not stop solely because the registry was unavailable.
- Never replace `@latest` or an unpinned reference with a guessed version. Only pin to a version reported by the script or explicitly provided by the user.
