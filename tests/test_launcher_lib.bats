#!/usr/bin/env bats
# Helper- and bundle-level tests for the Vibe Code launcher.
#
# Three layers covered here:
#   1. lib/launcher.sh        — install / uninstall helpers (file IO).
#   2. launcher/build.sh      — bundle assembly (structure + plist sanity).
#   3. launcher/launch.sh     — runtime behavior with mocked open/osascript.
#
# Real `open` and `osascript` are never invoked. We override the binary paths
# via VIBE_CODE_OPEN_BIN / VIBE_CODE_OSASCRIPT_BIN, drop tiny shell mocks at
# those paths, and grep their log to assert exact argv. This is the same
# mocking pattern used for brew/gh/opencode in the opencode integration tests.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/launcher.sh
  source "${BOOTSTRAP_DIR}/lib/launcher.sh"

  SANDBOX="$(mktemp -d)"
  MOCK_LOG="$SANDBOX/mock.log"
  : >"$MOCK_LOG"
  export MOCK_LOG
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# Drop a mock `open` that just logs its argv. Always exits 0.
_mock_open() {
  cat >"$SANDBOX/open" <<'EOF'
#!/usr/bin/env bash
echo "open $*" >>"$MOCK_LOG"
EOF
  chmod +x "$SANDBOX/open"
}

# Drop a mock `osascript`. By default, "exists application" succeeds; alerts
# are accepted silently. Pass "missing" as $1 to make the existence check fail
# (simulating Ghostty not installed).
_mock_osascript() {
  local mode="${1:-present}"
  cat >"$SANDBOX/osascript" <<EOF
#!/usr/bin/env bash
echo "osascript \$*" >>"\$MOCK_LOG"
case "\$*" in
  *"exists application"*) [[ "$mode" == "missing" ]] && exit 1 || exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$SANDBOX/osascript"
}

# Run launch.sh with overrides pointed at the mocks. Any extra args are
# treated as VAR=VALUE env-var overrides, layered on top of the defaults.
_run_launch() {
  env \
    "VIBE_CODE_OPEN_BIN=$SANDBOX/open" \
    "VIBE_CODE_OSASCRIPT_BIN=$SANDBOX/osascript" \
    "AI_BOOTSTRAP_STATE_FILE=$SANDBOX/state.sh" \
    "$@" \
    bash "${BOOTSTRAP_DIR}/launcher/launch.sh"
}

# ── lib/launcher.sh ─────────────────────────────────────────────────────────

@test "launcher_install: builds and places Vibe Code.app in dest dir" {
  dest="$SANDBOX/Applications"
  run launcher_install "${BOOTSTRAP_DIR}/launcher/build.sh" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  [ -d "$dest/Vibe Code.app" ]
  [ -f "$dest/Vibe Code.app/Contents/Info.plist" ]
  [ -x "$dest/Vibe Code.app/Contents/MacOS/launch" ]
  [ -f "$dest/Vibe Code.app/Contents/Resources/VibeCode.icns" ]
}

@test "launcher_install: creates dest dir if missing" {
  dest="$SANDBOX/never/existed/Applications"
  run launcher_install "${BOOTSTRAP_DIR}/launcher/build.sh" "$dest"
  [ "$status" -eq 0 ]
  [ -d "$dest/Vibe Code.app" ]
}

@test "launcher_install: replaces an existing bundle (always rebuild)" {
  dest="$SANDBOX/Applications"
  mkdir -p "$dest/Vibe Code.app"
  echo "stale-marker" >"$dest/Vibe Code.app/STALE"

  run launcher_install "${BOOTSTRAP_DIR}/launcher/build.sh" "$dest"
  [ "$status" -eq 0 ]
  [ ! -f "$dest/Vibe Code.app/STALE" ]
  [ -x "$dest/Vibe Code.app/Contents/MacOS/launch" ]
}

@test "launcher_install: errors when build script missing" {
  run launcher_install "$SANDBOX/no-such-script.sh" "$SANDBOX/Applications"
  [ "$status" -eq 1 ]
  [[ "$output" == *"build script not found"* ]]
}

@test "launcher_uninstall: removes an installed bundle" {
  dest="$SANDBOX/Applications"
  mkdir -p "$dest/Vibe Code.app/Contents"

  run launcher_uninstall "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "removed" ]
  [ ! -d "$dest/Vibe Code.app" ]
}

@test "launcher_uninstall: reports absent when no bundle present" {
  run launcher_uninstall "$SANDBOX/Applications"
  [ "$status" -eq 0 ]
  [ "$output" = "absent" ]
}

# ── launcher/build.sh ───────────────────────────────────────────────────────

@test "build.sh: produces a plutil-valid Info.plist" {
  "${BOOTSTRAP_DIR}/launcher/build.sh" "$SANDBOX" >/dev/null
  run plutil -lint "$SANDBOX/Vibe Code.app/Contents/Info.plist"
  [ "$status" -eq 0 ]
}

@test "build.sh: bundle declares correct CFBundleExecutable + CFBundleIconFile" {
  "${BOOTSTRAP_DIR}/launcher/build.sh" "$SANDBOX" >/dev/null
  plist="$SANDBOX/Vibe Code.app/Contents/Info.plist"
  run /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist"
  [ "$output" = "launch" ]
  run /usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$plist"
  [ "$output" = "VibeCode" ]
}

@test "build.sh: errors with usage when called with no args" {
  run "${BOOTSTRAP_DIR}/launcher/build.sh"
  [ "$status" -eq 64 ]
  [[ "$output" == *"usage:"* ]]
}

# ── launcher/launch.sh ──────────────────────────────────────────────────────

@test "launch.sh: defaults launch ghostty with --working-directory + opencode" {
  _mock_open
  _mock_osascript present
  mkdir -p "$SANDBOX/workspace"
  echo "AI_BOOTSTRAP_WORKSPACE=\"$SANDBOX/workspace\"" >"$SANDBOX/state.sh"

  run _run_launch
  [ "$status" -eq 0 ]
  grep -q "open -na Ghostty.app --args --working-directory=$SANDBOX/workspace -e opencode" "$MOCK_LOG"
}

@test "launch.sh: VIBE_CODE_LAUNCH_OPENCODE=0 omits the -e opencode arg" {
  _mock_open
  _mock_osascript present
  mkdir -p "$SANDBOX/workspace"
  echo "AI_BOOTSTRAP_WORKSPACE=\"$SANDBOX/workspace\"" >"$SANDBOX/state.sh"

  run _run_launch VIBE_CODE_LAUNCH_OPENCODE=0
  [ "$status" -eq 0 ]
  # opencode must not appear at all in the open invocation
  saved="$(cat "$MOCK_LOG")"
  [[ "$saved" != *"-e opencode"* ]]
  grep -q "open -na Ghostty.app --args --working-directory=$SANDBOX/workspace" "$MOCK_LOG"
}

@test "launch.sh: missing state file falls back to \$HOME" {
  _mock_open
  _mock_osascript present
  # No state.sh written.

  run _run_launch
  [ "$status" -eq 0 ]
  grep -q "open -na Ghostty.app --args --working-directory=$HOME" "$MOCK_LOG"
}

@test "launch.sh: invalid workspace path in state falls back to \$HOME" {
  _mock_open
  _mock_osascript present
  echo "AI_BOOTSTRAP_WORKSPACE=\"$SANDBOX/does-not-exist\"" >"$SANDBOX/state.sh"

  run _run_launch
  [ "$status" -eq 0 ]
  grep -q "open -na Ghostty.app --args --working-directory=$HOME" "$MOCK_LOG"
}

@test "launch.sh: missing ghostty shows alert and exits 1 without opening" {
  _mock_open
  _mock_osascript missing

  run _run_launch
  [ "$status" -eq 1 ]
  # No `open` call should have been made.
  saved="$(cat "$MOCK_LOG")"
  [[ "$saved" != *"open -na"* ]]
  # User-facing alert must be issued.
  grep -q "display alert" "$MOCK_LOG"
}

@test "launch.sh: respects VIBE_CODE_GHOSTTY_APP override (e.g. for forks)" {
  _mock_open
  _mock_osascript present
  mkdir -p "$SANDBOX/workspace"
  echo "AI_BOOTSTRAP_WORKSPACE=\"$SANDBOX/workspace\"" >"$SANDBOX/state.sh"

  run _run_launch VIBE_CODE_GHOSTTY_APP=Wezterm.app
  [ "$status" -eq 0 ]
  grep -q "open -na Wezterm.app --args" "$MOCK_LOG"
}
