---
description: Check OpenCode config dependencies for outdated/unpinned packages and apply updates
---

Use the `$AI_BOOTSTRAP_WORKSPACE/scripts/agent/opencode-deps-check.sh` script to check the user's OpenCode configuration for outdated or unpinned dependencies.

## Workflow

1. **Check**: Run `$AI_BOOTSTRAP_WORKSPACE/scripts/agent/opencode-deps-check.sh --json` and parse the JSON output. The script reports on:
   - `~/.config/opencode/package.json` dependencies
   - `~/.config/opencode/opencode.json` `plugin` array entries
   - `~/.config/opencode/opencode.json` MCP `command` arrays referencing npm packages

2. **Report**: Present the results as a clear table. For each entry show: package name, current version (or "unpinned"), latest version (or "unknown"), status (ok/outdated/unpinned/unknown), and where it lives.

3. **Recommend**: For each entry that is `outdated` or `unpinned`, recommend an action:
   - `outdated` → bump to `latest`
   - `unpinned` (i.e. uses `@latest` or has no version) → pin to `latest`
   - `unknown` → warn and continue; do not suggest a blind update
   Skip entries already at status `ok`.

4. **Confirm**: Ask the user which to update — accept "all", a comma-separated list of package names, or "none". Default to nothing without explicit confirmation.

5. **Apply** (only after explicit user confirmation):
   - For `package.json` deps: edit the version string in `~/.config/opencode/package.json`, then run `npm install` from `~/.config/opencode/` to refresh `node_modules` and `package-lock.json`.
   - For `opencode.json` `plugin` entries: edit the version suffix in the matching `"<pkg>@<version>"` string. Preserve the rest of the file (it's JSONC — keep any comments untouched).
   - For `opencode.json` MCP `command` arrays: edit the version suffix in the matching token. Same JSONC-preservation rule.

6. **Verify**: After edits, re-run `$AI_BOOTSTRAP_WORKSPACE/scripts/agent/opencode-deps-check.sh` (no flag — human table) and show the new state. Confirm everything resolvable is `ok`.

7. **Hand off**: Summarize what changed, list the modified files, and remind the user to commit. Do NOT commit on the user's behalf.

## Rules

- Run the script, do not reimplement its logic in the prompt.
- Never edit files without explicit user approval of the specific changes.
- Never edit `opencode.json` without explicit user approval of the specific changes.
- Preserve formatting and comments in `opencode.json` — use targeted string replacements rather than full-file rewrites.
- If registry lookups fail, warn and continue with `unknown` entries. Do not stop solely because the registry was unavailable.

{{$arguments}}
