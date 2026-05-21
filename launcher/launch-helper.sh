#!/usr/bin/env bash
#
# Just Vibes launcher helper — opens Ghostty in the user's workspace and
# starts opencode.
#
# This script ships in the repo as launcher/launch-helper.sh and is copied
# into Just Vibes.app/Contents/Resources/launch-helper.sh at build time.
# It is invoked by the AppleScript host (Just Vibes.app/Contents/MacOS/applet,
# compiled from launcher/launch.applescript) via `do shell script`. The
# AppleScript host owns the Dock tile / Cmd+Tab / Activity Monitor identity
# (Branch F, launcher_improvement_plan.md §8); this helper is the
# behavioral core (probe Ghostty install, resolve opencode, conditional -n,
# `/usr/bin/open` invocation). Kept as a standalone bash script so:
#   1. The bats suite (tests/test_launcher_lib.bats) can exercise it
#      directly with mocked open/osascript binaries — AppleScript itself
#      has no good unit-test framework, so the testable logic stays in
#      bash.
#   2. A curious user can `cat` it and read what the launcher does.
#
# Pre-Branch-F (commits up to 086c419 on main), this script lived at
# launcher/launch.sh and was the bundle's CFBundleExecutable directly.
# That meant the bundle's process was a transient bash → exec'd open →
# Ghostty took over the Dock identity. Branch F inserts an AppleScript
# applet host so macOS sees a persistent "Just Vibes" process with the
# piggy-bank icon. The shell logic below is unchanged from the rev-6
# version that shipped on 086c419 — Branch F is purely an identity win,
# not a behavioral change.
#
# Why we use --command=, not -e:
#
#   The original launcher passed `-e <opencode_bin>` to Ghostty via
#   `open` with the `-n` and `-a` flags (i.e. `-n -a Ghostty.app
#   --args -e <bin>`, or the equivalent flag-cluster `-na`). That arg
#   is delivered through TWO separate code paths inside Ghostty: once
#   during applicationDidFinishLaunching, and once via the LaunchServices
#   "open URLs/files" delegate. Both fire, both spawn a tab, both run the
#   command — producing two tabs and an "Allow Ghostty to execute …"
#   security prompt on every launch (Ghostty's own application-level
#   prompt, GHSA-q9fg-cpmh-c78x).
#
#   Phase 5 verification (zsh_init_plan.md §A.1) confirmed that
#   `--command=zsh -l -i -c <opencode_bin>` produces the desired UX:
#   single tab, no security prompt, full login-shell PATH inside the tab.
#   That's the form we use here. Decision matrix at §8 line 868
#   selected this as Option A.
#
# PATH resolution belt-and-suspenders:
#
#   The three-tier shell init shipped by this bootstrap (env/profile/rc)
#   guarantees /opt/homebrew/bin is on PATH for any login shell, so
#   `--command=zsh -l -i -c opencode` (bare name) would also work after
#   a successful install. We pass the absolute path anyway because:
#     (1) It works on machines that didn't run this bootstrap (custom
#         dotfiles, partial installs).
#     (2) It side-steps any path_helper / login-shell PATH ordering
#         surprises in `/etc/zprofile`.
#     (3) `resolve_opencode` already does the lookup; reusing its output
#         is free.
#   The `zsh -l -i -c` wrapper still earns its keep: it ensures the
#   shell that hosts opencode has a fully-initialized environment
#   (aliases, functions, $LANG, mise shims, etc.) so opencode's tool
#   calls inherit a sane PATH and locale.
#
# Why we use `open -F`, conditional `-n`, and `--title=Just Vibes` (rev-8 / Phase 6.5 / Phase 6.6):
#
#   `-F` (see `man open`) opens the application "fresh," without
#   restoring saved windows. Without it, clicking Just Vibes reopens
#   whatever windows/tabs/panes the user had when Ghostty was last
#   quit — macOS app-restoration fires through `open -na` and Ghostty
#   (with default `window-save-state = default`) cooperates. That
#   violates the "1 window, 1 tab, opencode" UX contract for this
#   launcher's target audience. `-F` is per-invocation: it does NOT
#   modify the user's ~/.config/ghostty/config and does NOT affect
#   Spotlight/Dock/manual `open -a` launches of Ghostty. The accepted
#   trade-off is that manually-added tabs in a Just Vibes session do
#   not persist across `Cmd+Q` and re-launch (see zsh_init_plan.md
#   §3.10). `--title=Just Vibes` sets the spawned window's title bar
#   so the launcher origin is visually identifiable.
#
#   `-n` is **conditional** on Ghostty's running state at launch time:
#
#     * If Ghostty is NOT running (cold-state): we use `-Fa` (no `-n`).
#       Adding `-n` from a `.app`-bundle context cold-state spawns an
#       extra bare `ghostty` process alongside the flagged one — a
#       persistent invisible "ghost" with no window. This is the bug
#       that motivated the original launcher investigation; verified
#       reproducible 2026-05-03 in launcher_improvement_plan.md §1.5.4.2
#       H4. Hypothesis: from a `.app` parent context, LaunchServices
#       interprets `open -n -a Ghostty.app --args …` as two distinct
#       lifecycle events (a bundle-launch event + a `--args` URL-event
#       delivery), and the bundle-launch fork emerges as a separate
#       bare `ghostty` process. From Terminal context the two events
#       fold into one fork, which is why the bug only manifests for
#       end-users (Finder/Dock/Spotlight clicks all go through `.app`
#       parent context).
#
#     * If Ghostty IS running (hot-state): we use `-nFa` (with `-n`).
#       Without `-n`, `open -a` against an already-running Ghostty
#       activates the existing process and **silently discards `--args`**
#       — no new window, no error, no signal. Verified 2026-05-03 in
#       launcher_improvement_plan.md §1.5.4.1 hypothesis 3.
#
#   Detection uses `osascript -e 'running of application "Ghostty"'`,
#   which returns "true" / "false" without firing TCC prompts (the same
#   `osascript` binary already used for the existence check below).
#   Reuses `OSASCRIPT_BIN` so tests can substitute a mock. There is a
#   ~200ms TOCTOU window between the check and `open`; in practice this
#   only matters if the user double-clicks Just Vibes.app twice within
#   200ms of a fresh login, which collapses to a single window (matching
#   typical Finder UX).
#
#   Flag-cluster ordering matters: we use `-Fa "$GHOSTTY_APP"` (cold) or
#   `-nFa "$GHOSTTY_APP"` (hot), NOT `-naF` or `-aF`. macOS `open(1)`
#   parses these such that `-a`'s required argument is not satisfied by
#   the next token, so `Ghostty.app` becomes a positional file path
#   (resolved against cwd, which is `/` for Finder/Spotlight launches)
#   and the launch fails with "The file /Ghostty.app does not exist."
#   Putting `-a` last in the cluster lets it consume the next token as
#   its app argument. This was discovered during Phase 6.5 manual matrix
#   verification on 2026-05-03 — the original plan §3.10 prescribed
#   `-naF`; that prescription is corrected in the plan erratum at the
#   top of zsh_init_plan.md.

set -u

HELPER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${JUST_VIBES_STATE_VALIDATION_LIB:-}" && -f "$JUST_VIBES_STATE_VALIDATION_LIB" ]]; then
  # shellcheck disable=SC1090
  source "$JUST_VIBES_STATE_VALIDATION_LIB"
elif [[ -f "$HELPER_DIR/state_source_validation.sh" ]]; then
  # Bundled app path: build.sh copies the shared validator beside this helper.
  # shellcheck disable=SC1091
  source "$HELPER_DIR/state_source_validation.sh"
elif [[ -f "$HELPER_DIR/../lib/state_source_validation.sh" ]]; then
  # Repo path: tests and direct developer runs execute launcher/launch-helper.sh in place.
  # shellcheck disable=SC1091
  source "$HELPER_DIR/../lib/state_source_validation.sh"
fi

# Defaults; overridable via env (mainly for tests).
LAUNCH_OPENCODE="${JUST_VIBES_LAUNCH_OPENCODE:-1}"
STATE_FILE="${AI_BOOTSTRAP_STATE_FILE:-$HOME/.config/ai-bootstrap/state.sh}"
GHOSTTY_APP="${JUST_VIBES_GHOSTTY_APP:-Ghostty.app}"
OPEN_BIN="${JUST_VIBES_OPEN_BIN:-/usr/bin/open}"
OSASCRIPT_BIN="${JUST_VIBES_OSASCRIPT_BIN:-/usr/bin/osascript}"

# Where to look for the Ghostty bundle, in priority order. Standard macOS
# install dirs first; overridable via JUST_VIBES_GHOSTTY_SEARCH_PATHS
# (colon-separated parent dirs) for tests / per-user overrides.
GHOSTTY_SEARCH_PATHS="${JUST_VIBES_GHOSTTY_SEARCH_PATHS:-/Applications:$HOME/Applications}"

# Where to look for opencode, in priority order. Apple Silicon brew, Intel
# brew, opencode's own installer fallback, then PATH (in case the user
# installed it somewhere unusual). Overridable via JUST_VIBES_OPENCODE_PATHS
# (colon-separated) for tests.
OPENCODE_PATHS="${JUST_VIBES_OPENCODE_PATHS:-/opt/homebrew/bin/opencode:/usr/local/bin/opencode:$HOME/.local/bin/opencode}"

# Resolve opencode's absolute path. Returns 0 + echoes path on success;
# returns 1 + echoes nothing if not found.
resolve_opencode() {
  local IFS=':'
  local candidate
  for candidate in $OPENCODE_PATHS; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  # PATH fallback — this works if the launcher is run from an environment
  # that already has brew on PATH (e.g. dev testing from terminal).
  if command -v opencode >/dev/null 2>&1; then
    command -v opencode
    return 0
  fi
  return 1
}

# Resolve the workspace dir. State file is sourced if present; if it is missing
# or sets an invalid path, we fall back to $HOME so the launcher still works.
workspace=""
if [[ -r "$STATE_FILE" ]]; then
  if declare -F state_validate_sourceable_file >/dev/null && state_validate_sourceable_file "$STATE_FILE" 2>/dev/null; then
    # shellcheck disable=SC1090
    source "$STATE_FILE" || true
    workspace="${AI_BOOTSTRAP_WORKSPACE:-}"
  else
    echo "Could not read saved workspace settings. Opening home folder instead. To fix this, run the installer again." >&2
  fi
fi
if [[ -z "$workspace" || ! -d "$workspace" ]]; then
  workspace="$HOME"
fi

# Verify Ghostty is installed before invoking `open`. `open` would surface a
# generic "could not find application" dialog otherwise; this gives a clearer
# message in Console.app for anyone debugging.
#
# IMPORTANT: We use a filesystem check here, NOT `osascript -e 'exists
# application "Ghostty.app"'`. The osascript form triggers LaunchServices to
# *launch* Ghostty as a side effect of resolving the bundle — producing an
# extra bare `ghostty` process (the original "two Dock icons" / "ghost
# process" symptom diagnosed across Phase 6.5/6.6 and §1.5.4 of
# `launcher_improvement_plan.md`). The filesystem check is side-effect-free.
ghostty_found=0
IFS=':' read -ra _search_dirs <<<"$GHOSTTY_SEARCH_PATHS"
for _dir in "${_search_dirs[@]}"; do
  if [[ -d "$_dir/$GHOSTTY_APP" ]]; then
    ghostty_found=1
    break
  fi
done
if [[ "$ghostty_found" -eq 0 ]]; then
  "$OSASCRIPT_BIN" -e 'display alert "Just Vibes" message "Ghostty is not installed. Re-run the bootstrap installer to set it up." as critical' >/dev/null 2>&1 || true
  exit 1
fi

# Resolve opencode's absolute path before invoking Ghostty. If opencode
# isn't installed, surface a friendly alert instead of a cryptic Ghostty
# launch error.
opencode_bin=""
if [[ "$LAUNCH_OPENCODE" == "1" ]]; then
  if ! opencode_bin=$(resolve_opencode); then
    "$OSASCRIPT_BIN" -e 'display alert "Just Vibes" message "OpenCode is not installed. Re-run the bootstrap installer to set it up." as critical' >/dev/null 2>&1 || true
    exit 1
  fi
fi

# Detect whether Ghostty is already running. The result determines whether
# we pass `-n` to `open` — see the "conditional `-n`" header comment above.
# `osascript -e 'running of application "..."'` returns "true" or "false";
# a non-zero exit (which we map to "false") means osascript itself failed.
# Note: empty array expansion under `set -u` differs across bash versions
# (3.x on stock macOS errors on `${arr[@]}` when arr is empty), so we
# expand a flat string instead.
n_flag=""
if "$OSASCRIPT_BIN" -e "running of application \"${GHOSTTY_APP%.app}\"" 2>/dev/null | grep -qx "true"; then
  n_flag="-n"
fi

launch_command="$opencode_bin"
if [[ "$LAUNCH_OPENCODE" == "1" ]]; then
  if command -v tailscale &>/dev/null \
    && security find-generic-password -s opencode-server-password -a "$USER" -w &>/dev/null; then
    launch_command="'\"$workspace/scripts/personal/opensession.sh\" || \"$opencode_bin\"'"
  fi
fi

if [[ -n "$n_flag" ]]; then
  args=("$n_flag" -Fa "$GHOSTTY_APP" --args "--title=Just Vibes" "--working-directory=$workspace")
else
  args=(-Fa "$GHOSTTY_APP" --args "--title=Just Vibes" "--working-directory=$workspace")
fi
if [[ "$LAUNCH_OPENCODE" == "1" ]]; then
  # See header comment for why --command= replaces -e.
  args+=("--command=zsh -l -i -c $launch_command")
fi

# `open -Fa` returns immediately (the spawned ghostty is reparented to
# launchd). We invoke it synchronously rather than exec'ing into it so
# that we can subsequently capture the spawned ghostty's PID for the
# Branch F.1 reopen-focus handler (launcher_improvement_plan.md §8.7).
"$OPEN_BIN" "${args[@]}"
open_rc=$?

# ── Branch F.1 (§8.7): track spawned Ghostty PID for the reopen handler ──
#
# After `open` returns, poll for up to 2s for the most recent ghostty
# process whose argv contains both `Ghostty.app/Contents/MacOS/ghostty`
# (the canonical Mach-O path — only Ghostty's own binary runs from
# there) AND `--title=Just Vibes` (so we don't pick up an unrelated
# user-launched ghostty). Write the PID to $TMPDIR/just-vibes/ghostty.pid
# so `on reopen` in launch.applescript can resolve it.
#
# Failure to capture is non-fatal: the AppleScript reopen handler reads
# the file and falls back to a fresh `runHelper()` call when missing.
# The 2s deadline guards against runaway polling on hosts where ghostty
# never appears (e.g. crashed mid-launch); 250ms is the typical
# real-world time for the process to show up.
#
# Gated behind JUST_VIBES_TRACK_GHOSTTY_PID so the feature can be
# disabled without rebuilding the bundle (§8.7.6 rollback / off-switch).
if [[ "${JUST_VIBES_TRACK_GHOSTTY_PID:-1}" = "1" ]]; then
  _pid_dir="${TMPDIR:-/tmp}/just-vibes"
  _pid_file="$_pid_dir/ghostty.pid"
  _deadline=$(($(date +%s) + 2))
  _ghostty_pid=""
  while [ "$(date +%s)" -lt "$_deadline" ]; do
    _ghostty_pid="$(pgrep -nf "Ghostty.app/Contents/MacOS/ghostty .*--title=Just Vibes" 2>/dev/null || true)"
    if [[ -n "$_ghostty_pid" ]]; then
      break
    fi
    sleep 0.1
  done
  if [[ -n "$_ghostty_pid" ]]; then
    mkdir -p "$_pid_dir" 2>/dev/null || true
    printf '%s\n' "$_ghostty_pid" >"$_pid_file" 2>/dev/null || true
  fi
fi

exit "$open_rc"
