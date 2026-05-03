#!/usr/bin/env bash
#
# Vibe Code launcher — opens Ghostty in the user's workspace and starts opencode.
#
# This script ships in the repo as launcher/launch.sh and is copied into
# Vibe Code.app/Contents/MacOS/launch (the bundle's CFBundleExecutable) at
# build time. macOS launches it directly when the user opens the .app — no
# AppleScript shim involved. Kept tiny so a curious user can read it.
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
# Why we use `open -F` and `--title=Vibe Code` (rev-8 / Phase 6.5):
#
#   `-F` (see `man open`) opens the application "fresh," without
#   restoring saved windows. Without it, clicking Vibe Code reopens
#   whatever windows/tabs/panes the user had when Ghostty was last
#   quit — macOS app-restoration fires through `open -na` and Ghostty
#   (with default `window-save-state = default`) cooperates. That
#   violates the "1 window, 1 tab, opencode" UX contract for this
#   launcher's target audience. `-F` is per-invocation: it does NOT
#   modify the user's ~/.config/ghostty/config and does NOT affect
#   Spotlight/Dock/manual `open -a` launches of Ghostty. The accepted
#   trade-off is that manually-added tabs in a Vibe Code session do
#   not persist across `Cmd+Q` and re-launch (see zsh_init_plan.md
#   §3.10). `--title=Vibe Code` sets the spawned window's title bar
#   so the launcher origin is visually identifiable.
#
#   Flag-cluster ordering matters: we use `-nFa "$GHOSTTY_APP"`, NOT
#   `-naF`. macOS `open(1)` parses `-naF` such that `-a`'s required
#   argument is not satisfied by the next token, so `Ghostty.app`
#   becomes a positional file path (resolved against cwd, which is
#   `/` for Finder/Spotlight launches) and the launch fails with
#   "The file /Ghostty.app does not exist." Putting `-a` last in
#   the cluster (`-nFa`) lets it consume the next token as its app
#   argument. This was discovered during Phase 6.5 manual matrix
#   verification on 2026-05-03 — the original plan §3.10 prescribed
#   `-naF`; that prescription is corrected in the plan erratum at the
#   top of zsh_init_plan.md.

set -u

# Defaults; overridable via env (mainly for tests).
LAUNCH_OPENCODE="${VIBE_CODE_LAUNCH_OPENCODE:-1}"
STATE_FILE="${AI_BOOTSTRAP_STATE_FILE:-$HOME/.config/ai-bootstrap/state.sh}"
GHOSTTY_APP="${VIBE_CODE_GHOSTTY_APP:-Ghostty.app}"
OPEN_BIN="${VIBE_CODE_OPEN_BIN:-/usr/bin/open}"
OSASCRIPT_BIN="${VIBE_CODE_OSASCRIPT_BIN:-/usr/bin/osascript}"

# Where to look for opencode, in priority order. Apple Silicon brew, Intel
# brew, opencode's own installer fallback, then PATH (in case the user
# installed it somewhere unusual). Overridable via VIBE_CODE_OPENCODE_PATHS
# (colon-separated) for tests.
OPENCODE_PATHS="${VIBE_CODE_OPENCODE_PATHS:-/opt/homebrew/bin/opencode:/usr/local/bin/opencode:$HOME/.local/bin/opencode}"

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
  # shellcheck disable=SC1090
  source "$STATE_FILE" || true
  workspace="${AI_BOOTSTRAP_WORKSPACE:-}"
fi
if [[ -z "$workspace" || ! -d "$workspace" ]]; then
  workspace="$HOME"
fi

# Verify Ghostty is installed before invoking `open`. `open` would surface a
# generic "could not find application" dialog otherwise; this gives a clearer
# message in Console.app for anyone debugging.
if ! "$OSASCRIPT_BIN" -e "exists application \"$GHOSTTY_APP\"" >/dev/null 2>&1; then
  "$OSASCRIPT_BIN" -e 'display alert "Vibe Code" message "Ghostty is not installed. Re-run the bootstrap installer to set it up." as critical' >/dev/null 2>&1 || true
  exit 1
fi

# Resolve opencode's absolute path before invoking Ghostty. If opencode
# isn't installed, surface a friendly alert instead of a cryptic Ghostty
# launch error.
opencode_bin=""
if [[ "$LAUNCH_OPENCODE" == "1" ]]; then
  if ! opencode_bin=$(resolve_opencode); then
    "$OSASCRIPT_BIN" -e 'display alert "Vibe Code" message "OpenCode is not installed. Re-run the bootstrap installer to set it up." as critical' >/dev/null 2>&1 || true
    exit 1
  fi
fi

args=(-nFa "$GHOSTTY_APP" --args "--title=Vibe Code" "--working-directory=$workspace")
if [[ "$LAUNCH_OPENCODE" == "1" ]]; then
  # See header comment for why --command= replaces -e.
  args+=("--command=zsh -l -i -c $opencode_bin")
fi

exec "$OPEN_BIN" "${args[@]}"
