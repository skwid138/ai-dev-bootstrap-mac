#!/usr/bin/env bash
#
# Vibe Code launcher — opens Ghostty in the user's workspace and starts opencode.
#
# This script ships in the repo as launcher/launch.sh and is copied into
# Vibe Code.app/Contents/MacOS/launch (the bundle's CFBundleExecutable) at
# build time. macOS launches it directly when the user opens the .app — no
# AppleScript shim involved. Kept tiny so a curious user can read it.
#
# PATH resolution gotcha:
#
#   When Ghostty is invoked via `open -na Ghostty.app -e <cmd>`, Ghostty
#   spawns the command through `/usr/bin/login -flp <user> <cmd>`. That's
#   a LOGIN shell (sources /etc/zprofile, ~/.zprofile, ~/.zshenv) but NOT
#   an interactive shell — so ~/.zshrc never runs. Homebrew's shellenv is
#   commonly added to ~/.zshrc rather than ~/.zprofile, so a bare
#   `opencode` command fails with "No such file or directory" even though
#   it works fine in the user's terminal.
#
#   Two ways to fix: (1) force `zsh -lic 'opencode'` so ~/.zshrc runs, or
#   (2) resolve opencode's absolute path before invoking Ghostty. We use
#   (2) — fewer moving parts, doesn't depend on the user's shell config
#   being sane, and the path resolution is the same logic any shell init
#   would do.

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

args=(-na "$GHOSTTY_APP" --args "--working-directory=$workspace")
if [[ "$LAUNCH_OPENCODE" == "1" ]]; then
  args+=(-e "$opencode_bin")
fi

exec "$OPEN_BIN" "${args[@]}"
