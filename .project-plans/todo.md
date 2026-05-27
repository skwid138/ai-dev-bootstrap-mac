## Future Considerations

### Always-on OpenCode web daemon via LaunchAgent

**Context**: The Tailscale remote access module (14-tailscale.sh) currently starts the OpenCode web daemon on-demand via `opensession` when Ghostty launches. Tailscale Serve persists across reboots, so the HTTPS endpoint stays configured — but if the Mac reboots and the user hasn't opened Ghostty yet, the tailnet URL returns a dead port.

**Consideration**: Install a macOS LaunchAgent (`~/Library/LaunchAgents/com.opencode.web.plist`) that starts `opencode web` at login, independent of Ghostty. This would make the phone-access experience truly "always on when Mac is on" rather than "on when Ghostty is open."

**Why deferred**: Adds significant complexity — LaunchAgent lifecycle management, log rotation, restart-on-crash policy, interaction with caffeinate (LaunchAgent vs login session sleep prevention), potential conflict with Ghostty-launched daemon (two daemons on same port), and the question of whether the daemon should run in a specific working directory or not. The current UX ("works when Ghostty is open") matches the target user's likely workflow — they open Ghostty to work, and phone access is available during that session.

**If implementing**:
- LaunchAgent plist with `RunAtLoad=true`, `KeepAlive=false` (or `KeepAlive.SuccessfulExit=false` for restart-on-crash)
- Must coordinate with opensession/openweb to avoid port conflicts (check if already running before starting)
- Password must be loadable non-interactively from Keychain (already works — `security find-generic-password` doesn't require GUI prompt for login keychain items in a login session)
- Logging to `~/.local/share/opencode/log/launchagent-*.log` with rotation
- caffeinate integration: LaunchAgent-spawned process may need `caffeinate -is` wrapper to prevent sleep during active remote sessions, but this conflicts with letting the Mac sleep when idle
- Consider: should the LaunchAgent version skip caffeinate entirely and let the Mac sleep (killing the daemon), relying on KeepAlive to restart it when the Mac wakes?

### Per-module and full uninstall capability

**Context**: The bootstrap currently has no uninstall or teardown mechanism. Once modules are installed, their artifacts (packages, scripts, shell config, Keychain entries, LaunchAgents, app configs) persist indefinitely. If a user wants to remove a specific module's effects or do a clean uninstall of everything the bootstrap touched, there's no supported path.

**Why this matters**: 
- The Tailscale module (14-tailscale.sh) installs scripts, creates Keychain entries, configures Tailscale Serve, modifies shell config, and modifies the launcher. Reversing all of that manually requires knowing exactly what the module did.
- Other modules install Homebrew packages, create directories, write config files, append lines to dotfiles. A user switching to a different setup (or troubleshooting by elimination) has no clean way to undo.
- Design priority #6 ("Safe re-runs") implies the system should be manageable — uninstall is the logical complement.

**Per-module uninstall** (`./bootstrap.sh --uninstall --module tailscale`):
- Each module would need a teardown function or companion uninstall script
- Tailscale example: `tailscale serve reset`, remove scripts from `$WORKSPACE/scripts/personal/` and `scripts/lib/keychain.sh`+`opencode-daemon.sh`, remove `rc/tailscale.zsh`, remove Keychain entry, revert launcher to bare `opencode`, remove `.provenance` file
- Shell config: remove the `rc/tailscale.zsh` file (the conditional source line in `init_rc.zsh` becomes a harmless no-op)
- Homebrew packages: `brew uninstall <pkg>` for module-specific packages
- Challenge: some artifacts are shared (e.g., `scripts/lib/common.sh` is used by multiple modules if they exist). Need dependency tracking or "only remove if no other module needs it."

**Full uninstall** (`./bootstrap.sh --uninstall`):
- Remove `~/.config/ai-bootstrap/` (state file, shell config)
- Remove source lines from `~/.zshenv`, `~/.zprofile`, `~/.zshrc`
- Remove `$WORKSPACE/scripts/` (bootstrap-deployed scripts)
- Optionally: `brew uninstall` all bootstrap-installed packages (dangerous — user may have installed other things via Homebrew since)
- Optionally: remove Homebrew itself (very dangerous — only if bootstrap installed it)
- Remove `/Applications/JustVibes.app` or `~/Applications/JustVibes.app`
- Remove `~/.config/opencode/` managed assets (but NOT user sessions/data in `~/.local/share/opencode/`)
- Challenge: distinguishing "bootstrap installed this" from "user installed this independently." The state file and `.managed-files` manifest help but may not cover everything.

**Design considerations**:
- Should uninstall require confirmation per destructive action, or batch with a summary + single confirm?
- Should it create a backup/snapshot before uninstalling (tarball of everything it's about to remove)?
- Should `bootstrap-doctor.sh` gain an `--audit` mode that shows what's installed and what would be removed?
- How to handle Homebrew packages that were installed by bootstrap but the user has since added as dependencies of their own formulae?

**Why deferred**: V1 focus is on installation working correctly and idempotently. Uninstall is the inverse problem and significantly harder (tracking provenance of every artifact across re-runs). Better to ship install-only, gather real usage patterns, then design uninstall with knowledge of what actually needs reversing.

### Remove legacy "Just Vibes" cleanup code

**Context**: The rename from "Just Vibes" to "JustVibes" (2026-05-22) added migration cleanup logic in `lib/launcher.sh` (`launcher_cleanup_legacy`) that detects and removes old `Just Vibes.app` bundles on install/update. This code is only useful during the transition period — once the maintainer has updated their own machine, no `Just Vibes.app` will ever exist again.

**Action**: After confirming the maintainer's machine has been updated (run the installer once post-rename), remove:
- `launcher_cleanup_legacy()` function from `lib/launcher.sh`
- Its call site in the install/update path
- Migration-specific tests in `tests/test_update_flag.bats` (the ones that seed a fake `Just Vibes.app`)

**Why deferred**: The cleanup code is harmless (no-ops when no legacy app exists) and ensures a clean transition. Remove it once the transition is confirmed complete to reduce code surface.

**Status note (2026-05-24):** This seems like it could be done now — will confirm later.

### Scrub adopted files for hardcoded local paths

**Context**: When adopting files from `~/code/scripts` or `~/.config/opencode` into this repo, all files (scripts, tests, fixtures, skill definitions) must be scrubbed for `/Users/hunter` or other machine-specific paths. The `tests/test_opencode_assets.bats` forbidden-path grep will catch SKILL.md and command files, but scripts and test fixtures are not currently covered by that check.

**Action**: After the permission-audit adoption PR, audit all previously adopted files (`scripts/agent/opencode-deps-check.sh`, any existing skill reference files) for hardcoded paths. Consider extending the forbidden-path bats test to cover `scripts/agent/` and `tests/fixtures/`.

### Add tilde-form permission rules for agent scripts

**Context**: The `opencode.json.template` uses `$AI_BOOTSTRAP_WORKSPACE/scripts/agent/<script> *` for permission allowlist rules. At runtime, OpenCode expands this to the absolute path. However, agents sometimes invoke scripts using `~/code/scripts/agent/...` (tilde form), which won't match the absolute-path rule. Users currently work around this by manually adding broad `~/code/scripts/agent/*` rules to their deployed config.

**Consideration**: Add a post-install step (or template enhancement) that writes both the `$AI_BOOTSTRAP_WORKSPACE` form and a tilde-expanded form for each agent script. Challenges:
- `~/code` is only correct for the default workspace; custom workspaces would need `~/<relative-path>/scripts/agent/...`
- Could use a second template variable like `$AI_BOOTSTRAP_WORKSPACE_TILDE` that holds the tilde-relative form
- Alternative: add a single broad rule `~/*/scripts/agent/*` but this is overly permissive
- Alternative: post-render step that computes the tilde form from the workspace path and injects it via jq

**Why deferred**: The existing `opencode-deps-check.sh` has the same gap. This is not unique to `permission-audit` and should be solved holistically for all agent scripts at once.

### Remove historical managed plugin cleanup from TUI config deploy

**Context**: When migrating from local TUI plugins (`./plugins/home-prompt.tsx`, `./plugins/justvibes-logo.tsx`) to the npm package `@skwid138/opencode-tui@1.0.0`, the `opencode_deploy_tui_config()` function in `lib/opencode.sh` was updated to include those two paths in the `historical_managed_plugins` array. This causes the merge logic to strip those entries from existing user `tui.json` files on upgrade — ensuring users get the npm plugin instead of dangling references to deleted local files.

**Action**: After sufficient time has passed (all users have run the installer at least once post-migration), remove:
- The two entries from `historical_managed_plugins` array in `opencode_deploy_tui_config()` (lines near the top of the function, around line 233 area of `lib/opencode.sh`)
- The `OPENCODE_TEST_HISTORICAL_MANAGED_PLUGINS` test injection mechanism can stay (it's generic infrastructure) or be removed if no other historical plugins exist
- Related test cases in `tests/test_opencode_lib.bats` that specifically test historical plugin removal (tests named like "historical managed plugins are removed" and "template-derived plugins are not duplicated by historical list")

**Why deferred**: The cleanup code is harmless (no-ops when no user has the old entries) and ensures a clean transition for any user who hasn't re-run the installer yet.

### Migrate OpenCode config template to JSONC

**What**: Rename `opencode/opencode.json.template` to `opencode/opencode.jsonc.template` and update all references so the rendered OpenCode config uses JSONC (`opencode.jsonc`) instead of JSON. This enables comments in the generated config.

**Why**: JSONC allows inline comments in the rendered config, improving readability for users who inspect their OpenCode config directly.

**Known touchpoints**:
- `opencode/opencode.json.template` (rename)
- `modules/09-opencode.sh` — `opencode_render_config()` function (output filename)
- `scripts/agent/set-models.sh` — reads/writes `opencode.json` by name
- `scripts/opencode-deps-check.sh` — checks for config file existence
- `bootstrap.sh` — backup logic references `.json`
- `tests/test_set_models.bats` — creates mock `opencode.json`
- `tests/test_opencode_assets.bats` — may assert config filename

**Consideration**: Confirm OpenCode supports `.jsonc` config before implementing. Current evidence: the local dev config at `~/.config/opencode/` already uses `opencode.jsonc`.
