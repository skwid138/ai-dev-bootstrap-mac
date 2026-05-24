## Plan: Migrate Local TUI Plugins to @skwid138/opencode-tui@1.0.0

> **Status:** Implemented
> **Created:** 2026-05-24
> **Completed:** 2026-05-24
> **Source:** User request — migrate from local .tsx TUI plugins to published npm package

### 1. Goal

Replace the two local TUI plugin files (`home-prompt.tsx`, `justvibes-logo.tsx`) with the published `@skwid138/opencode-tui@1.0.0` npm package. OpenCode resolves npm TUI plugins at runtime via its own cache — no `npm install` or lock file is needed in this repo.

### 2. Scope and non-goals

**In scope:**
- Switch `tui.json.template` and `tui.json` to reference the npm package
- Add old local plugin paths to `historical_managed_plugins` for automatic cleanup on existing installs
- Delete local plugin source files and `plugins-dev/` test infrastructure
- Delete unused `opencode/package.json` and `opencode/package-lock.json` (local-only, gitignored)
- Remove `package.json`/`package-lock.json` entries from `opencode/.gitignore`
- Repurpose `scripts/tui-preview.sh` for npm plugin workflow
- Remove CI `plugin-tests` job
- Update all affected tests and documentation

**Non-goals:**
- Changing the `opencode_deploy_assets()` subdir loop (keep `plugins` with `.gitkeep`)
- Modifying the npm package itself
- Any changes to `opencode.json.template` (non-TUI plugins are unrelated)

### 3. Context

- OpenCode resolves npm TUI plugins via `Npm.add(...)` at runtime into its own cache. No `npm install` needed.
- Must use version-pinned specifier (`@skwid138/opencode-tui@1.0.0`) due to a bun/opencode bug with `latest` keyword.
- Package has single `./tui` export registering both `home_prompt` and `home_logo` slots.
- `opencode_deploy_tui_config()` in `lib/opencode.sh` has a smart merge system: extracts managed plugin IDs from template, strips historical + current managed from existing user config, prepends template plugins, appends remaining user plugins.
- `historical_managed_plugins` array (currently empty in production, test-injectable via env var) enables automatic removal of old managed plugin references from user configs on upgrade.
- `opencode/tui.json` is gitignored (local dev use); `tui.json.template` is the deployment source of truth.

### 4. Approach

1. Update config templates to reference npm package instead of local paths
2. Register old local paths as historical managed plugins so existing installs auto-clean
3. Remove all local plugin infrastructure (source, dev tooling, CI job)
4. Repurpose preview script for npm-based workflow
5. Update tests to reflect new plugin reference format and removed files
6. Update documentation

### 5. Implementation steps

1. **`opencode/tui.json.template`** — Replace `["./plugins/home-prompt.tsx", {}]` and `["./plugins/justvibes-logo.tsx", {}]` with single entry `["@skwid138/opencode-tui@1.0.0", {}]`

2. **`opencode/tui.json`** — Same change as template (local dev consistency)

3. **`lib/opencode.sh` `opencode_deploy_tui_config()`** — Add to production `historical_managed_plugins` array:
   - `"./plugins/home-prompt.tsx"`
   - `"./plugins/justvibes-logo.tsx"`

4. **Delete `opencode/plugins/home-prompt.tsx`**

5. **Delete `opencode/plugins/justvibes-logo.tsx`**

6. **Delete `opencode/plugins/README.md`**

7. **Add `opencode/plugins/.gitkeep`**

8. **Delete `opencode/plugins-dev/` entirely** (includes `__tests__/`, `package.json`, `tsconfig.json`, etc.)

9. **Delete local `opencode/package.json`** (gitignored, not tracked — `rm` only)

10. **Delete local `opencode/package-lock.json`** (gitignored, not tracked — `rm` only)

11. **Update `opencode/.gitignore`** — Remove lines for `/package.json` and `/package-lock.json`

12. **Repurpose `scripts/tui-preview.sh`** — Generate a temp `tui.json` with `["@skwid138/opencode-tui@1.0.0", {}]` and launch opencode pointing at it. No local .tsx dependency.

13. **Update `tests/test_tui_preview.bats`** — Assert generated tui.json content contains npm plugin reference. Do not test npm resolution.

14. **Remove CI `plugin-tests` job from `.github/workflows/ci.yml`**

15. **Update `tests/test_opencode_lib.bats`** — Update assertions for new plugin reference in tui.json template merge tests. Add test for production `historical_managed_plugins` values removing old local paths.

16. **Update `tests/test_opencode_module.bats`** — Remove/update any assertions about local plugin files being deployed.

17. **Update `tests/test_update_flag.bats`** — Remove/update any assertions about local plugin files.

18. **Update `opencode/README.md`** — Remove `plugins/` and `plugins-dev/` documentation sections. Note that TUI customization comes from `@skwid138/opencode-tui` npm package.

19. **Update `CONTEXT.md`** — Remove references to local plugin development. Update curated assets description if it mentions plugins directory content.

### 6. Testing strategy

- Run `bats tests/` after all changes to verify no regressions
- `test_opencode_lib.bats`: verify tui config merge produces correct npm plugin reference; verify historical_managed_plugins strips old local paths from existing configs
- `test_tui_preview.bats`: verify generated tui.json content
- `test_opencode_module.bats` and `test_update_flag.bats`: verify no references to deleted files
- CI: verify `plugin-tests` job removal doesn't break workflow

### 7. Data shapes

N/A — no data shapes involved. Only config file format changes (JSON plugin array entries).

### 8. Risks and open questions

- **Risk:** Users with existing installs have old `./plugins/home-prompt.tsx` in their `tui.json`. Mitigated by `historical_managed_plugins` auto-cleanup on next bootstrap run.
- **Risk:** `@skwid138/opencode-tui@1.0.0` not yet published (user must publish before testing end-to-end). Plan proceeds assuming it will be available.
- **Open:** If user has manually added the local plugin paths to their tui.json (outside bootstrap management), the historical cleanup handles this correctly since it strips by path match regardless of origin.

### 9. Verification

- All `bats tests/` pass
- CI workflow valid (no reference to removed job/files)
- `opencode/plugins/` contains only `.gitkeep`
- `opencode/plugins-dev/` does not exist
- `tui.json.template` references `@skwid138/opencode-tui@1.0.0`
- `lib/opencode.sh` historical array contains both old paths
- No remaining references to `home-prompt.tsx` or `justvibes-logo.tsx` in active (non-archive) files
