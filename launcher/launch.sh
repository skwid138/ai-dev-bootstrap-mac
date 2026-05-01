#!/usr/bin/env bash
#
# Vibe Code launcher — opens Ghostty in the user's workspace and starts opencode.
#
# This script ships in the repo as launcher/launch.sh and is copied into
# Vibe Code.app/Contents/MacOS/launch (the bundle's CFBundleExecutable) at
# build time. macOS launches it directly when the user opens the .app — no
# AppleScript shim involved. Kept tiny so a curious user can read it.

set -u

# Defaults; overridable via env (mainly for tests).
LAUNCH_OPENCODE="${VIBE_CODE_LAUNCH_OPENCODE:-1}"
STATE_FILE="${AI_BOOTSTRAP_STATE_FILE:-$HOME/.config/ai-bootstrap/state.sh}"
GHOSTTY_APP="${VIBE_CODE_GHOSTTY_APP:-Ghostty.app}"
OPEN_BIN="${VIBE_CODE_OPEN_BIN:-/usr/bin/open}"
OSASCRIPT_BIN="${VIBE_CODE_OSASCRIPT_BIN:-/usr/bin/osascript}"

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

args=(-na "$GHOSTTY_APP" --args "--working-directory=$workspace")
if [[ "$LAUNCH_OPENCODE" == "1" ]]; then
  args+=(-e opencode)
fi

exec "$OPEN_BIN" "${args[@]}"
