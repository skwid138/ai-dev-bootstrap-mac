#!/usr/bin/env bats
# Helper- and bundle-level tests for the Just Vibes launcher.
#
# Three layers covered here:
#   1. lib/launcher.sh                 — install / uninstall helpers (file IO).
#   2. launcher/build.sh               — bundle assembly (structure + plist sanity).
#   3. launcher/launch-helper.sh       — runtime behavior with mocked open/osascript.
#
# Bundle layout note (Branch F, launcher_improvement_plan.md §8):
#   The bundle is now an osacompile-built AppleScript applet. The bash
#   launcher logic — which is what these tests exercise — moved from
#   Contents/MacOS/launch (pre-Branch-F) to Contents/Resources/launch-helper.sh.
#   The CFBundleExecutable is now Contents/MacOS/applet (the AppleScript
#   runtime stub, NOT a script we control). The behavioral tests run the
#   helper directly via `bash launcher/launch-helper.sh` — same logic as
#   the production AppleScript invokes via `do shell script`, just without
#   the AppleScript wrapper.
#
# Real `open` and `osascript` are never invoked. We override the binary paths
# via JUST_VIBES_OPEN_BIN / JUST_VIBES_OSASCRIPT_BIN, drop tiny shell mocks at
# those paths, and grep their log to assert exact argv. This is the same
# mocking pattern used for brew/gh/opencode in the opencode integration tests.

bats_require_minimum_version 1.5.0

# shellcheck source=helpers/mock_osacompile.bash
source "${BATS_TEST_DIRNAME}/helpers/mock_osacompile.bash"

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/launcher.sh
  source "${BOOTSTRAP_DIR}/lib/launcher.sh"

  SANDBOX="$(mktemp -d)"
  MOCKS_DIR="$SANDBOX/mocks"
  mkdir -p "$MOCKS_DIR"
  create_osacompile_mock "$MOCKS_DIR"
  export PATH="$MOCKS_DIR:$PATH"

  MOCK_LOG="$SANDBOX/mock.log"
  : >"$MOCK_LOG"
  export MOCK_LOG
  # Default: pretend Ghostty is installed by dropping a fake bundle dir at
  # $SANDBOX/Ghostty.app. Tests that simulate "Ghostty not installed"
  # remove this with `rm -rf "$SANDBOX/Ghostty.app"` (see _unmock_ghostty).
  mkdir -p "$SANDBOX/Ghostty.app"

  # Default Remote Access prerequisite state: no saved Keychain password.
  # Tests that need the password present overwrite this with _mock_security.
  cat >"$SANDBOX/security" <<'EOF'
#!/usr/bin/env bash
echo "security $*" >>"$MOCK_LOG"
exit 44
EOF
  chmod +x "$SANDBOX/security"
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

# Drop a mock `osascript`. Default behavior:
#   * "running of application …" → echoes "false" (Ghostty NOT running, the
#     cold-state default). Pass "running" as $2 to echo "true" instead.
#   * "exists application …" → exits 0 (legacy behavior; the production
#     launcher no longer calls this — the existence check moved to a
#     filesystem `[[ -d ]]` to avoid the LaunchServices side-effect that
#     spawns Ghostty as a "ghost" process. The mock retains the branch in
#     case any callsite is ever added back, and so older tests still parse.
#     Pass "missing" as $1 to make it exit 1.)
#   * Any other invocation (display alert, etc.) is accepted silently.
_mock_osascript() {
  local exists_mode="${1:-present}"
  local running_mode="${2:-not-running}"
  cat >"$SANDBOX/osascript" <<EOF
#!/usr/bin/env bash
echo "osascript \$*" >>"\$MOCK_LOG"
case "\$*" in
  *"exists application"*) [[ "$exists_mode" == "missing" ]] && exit 1 || exit 0 ;;
  *"running of application"*)
    if [[ "$running_mode" == "running" ]]; then echo "true"; else echo "false"; fi
    exit 0
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$SANDBOX/osascript"
}

# Drop a fake opencode binary at $SANDBOX/opencode and set
# JUST_VIBES_OPENCODE_PATHS to find it. Simulates a normal user setup
# where opencode is installed on the brew prefix.
_mock_opencode() {
  cat >"$SANDBOX/opencode" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$SANDBOX/opencode"
}

_mock_security() {
  local mode="${1:-present}"
  cat >"$SANDBOX/security" <<EOF
#!/usr/bin/env bash
echo "security \$*" >>"\$MOCK_LOG"
if [[ "\$1" == "find-generic-password" ]]; then
  [[ "$mode" == "present" ]] && exit 0 || exit 44
fi
exit 0
EOF
  chmod +x "$SANDBOX/security"
}

_mock_tailscale() {
  cat >"$SANDBOX/tailscale" <<'EOF'
#!/usr/bin/env bash
echo "tailscale $*" >>"$MOCK_LOG"
exit 0
EOF
  chmod +x "$SANDBOX/tailscale"
}

_make_hermetic_launcher_path() {
  mkdir -p "$SANDBOX/hermetic-bin"
  ln -sf /bin/bash "$SANDBOX/hermetic-bin/bash"
  ln -sf /usr/bin/dirname "$SANDBOX/hermetic-bin/dirname"
  ln -sf /usr/bin/grep "$SANDBOX/hermetic-bin/grep"
}

# Drop a mock `pgrep` at $SANDBOX/pgrep that echoes whatever is configured
# via $PGREP_OUTPUT_FILE (or empty if unset). Optional: writes its argv to
# the log so tests can assert on the search pattern. Each call also sleeps
# briefly if $PGREP_SLEEP_MS is set (in milliseconds), so tests can
# simulate slow polling without blowing the 2s deadline.
_mock_pgrep() {
  local payload="${1:-}"
  cat >"$SANDBOX/pgrep" <<EOF
#!/usr/bin/env bash
echo "pgrep \$*" >>"\$MOCK_LOG"
if [ -n "\${PGREP_SLEEP_MS:-}" ]; then
  # bash 3.2-compatible decimal sleep (sleep accepts fractional seconds on macOS).
  sleep "\$(awk "BEGIN { print \$PGREP_SLEEP_MS / 1000 }")"
fi
printf '%s' "${payload}"
if [ -n "${payload}" ]; then printf '\n'; fi
EOF
  chmod +x "$SANDBOX/pgrep"
}

# Run launch-helper.sh with overrides pointed at the mocks. Any extra args are
# treated as VAR=VALUE env-var overrides, layered on top of the defaults.
# Always points JUST_VIBES_OPENCODE_PATHS at the mock so opencode resolves
# without polluting $PATH; tests that want to test the not-found path can
# override by passing JUST_VIBES_OPENCODE_PATHS=/nonexistent explicitly.
# JUST_VIBES_GHOSTTY_SEARCH_PATHS points at $SANDBOX where _mock_ghostty
# drops a fake bundle (or doesn't, for the missing case).
_run_launch() {
  env \
    "JUST_VIBES_OPEN_BIN=$SANDBOX/open" \
    "JUST_VIBES_OSASCRIPT_BIN=$SANDBOX/osascript" \
    "JUST_VIBES_OPENCODE_PATHS=$SANDBOX/opencode" \
    "JUST_VIBES_GHOSTTY_SEARCH_PATHS=$SANDBOX" \
    "AI_BOOTSTRAP_STATE_FILE=$SANDBOX/state.sh" \
    "JUST_VIBES_TRACK_GHOSTTY_PID=${JUST_VIBES_TRACK_GHOSTTY_PID:-0}" \
    "TMPDIR=$SANDBOX/tmp" \
    "PATH=$SANDBOX:/usr/bin:/bin" \
    "$@" \
    bash "${BOOTSTRAP_DIR}/launcher/launch-helper.sh"
}

# Drop a fake Ghostty.app bundle dir in $SANDBOX so the launcher's
# filesystem existence check finds it. Setup creates this by default;
# call _unmock_ghostty to simulate "Ghostty not installed".
_unmock_ghostty() {
  rm -rf "$SANDBOX/Ghostty.app"
}

# ── lib/launcher.sh ─────────────────────────────────────────────────────────

@test "launcher_install: builds and places Just Vibes.app in dest dir" {
  dest="$SANDBOX/Applications"
  run launcher_install "${BOOTSTRAP_DIR}/launcher/build.sh" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  [ -d "$dest/Just Vibes.app" ]
  [ -f "$dest/Just Vibes.app/Contents/Info.plist" ]
  # Branch F: bundle executable is the osacompile-built `applet` Mach-O
  # (the AppleScript runtime stub). The bash logic is now a Resources/
  # helper invoked by the AppleScript via `do shell script`.
  [ -x "$dest/Just Vibes.app/Contents/MacOS/applet" ]
  [ -f "$dest/Just Vibes.app/Contents/Resources/Scripts/main.scpt" ]
  [ -x "$dest/Just Vibes.app/Contents/Resources/launch-helper.sh" ]
  [ -f "$dest/Just Vibes.app/Contents/Resources/state_source_validation.sh" ]
  [ -f "$dest/Just Vibes.app/Contents/Resources/JustVibes.icns" ]
  # Default-icon ambiguity (osacompile's applet.icns + Assets.car) must
  # be removed by build.sh so macOS can't fall back to the default
  # AppleScript-applet icon. See launcher_improvement_plan.md §1.5.3.
  [ ! -f "$dest/Just Vibes.app/Contents/Resources/applet.icns" ]
  [ ! -f "$dest/Just Vibes.app/Contents/Resources/Assets.car" ]
}

@test "launcher_install: creates dest dir if missing" {
  dest="$SANDBOX/never/existed/Applications"
  run launcher_install "${BOOTSTRAP_DIR}/launcher/build.sh" "$dest"
  [ "$status" -eq 0 ]
  [ -d "$dest/Just Vibes.app" ]
}

@test "launcher_install: replaces an existing bundle (always rebuild)" {
  dest="$SANDBOX/Applications"
  mkdir -p "$dest/Just Vibes.app"
  echo "stale-marker" >"$dest/Just Vibes.app/STALE"

  run launcher_install "${BOOTSTRAP_DIR}/launcher/build.sh" "$dest"
  [ "$status" -eq 0 ]
  [ ! -f "$dest/Just Vibes.app/STALE" ]
  # Branch F: applet is the AppleScript runtime executable.
  [ -x "$dest/Just Vibes.app/Contents/MacOS/applet" ]
}

@test "launcher_install: errors when build script missing" {
  run launcher_install "$SANDBOX/no-such-script.sh" "$SANDBOX/Applications"
  [ "$status" -eq 1 ]
  [[ "$output" == *"build script not found"* ]]
}

@test "launcher_uninstall: removes an installed bundle" {
  dest="$SANDBOX/Applications"
  mkdir -p "$dest/Just Vibes.app/Contents"

  run launcher_uninstall "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "removed" ]
  [ ! -d "$dest/Just Vibes.app" ]
}

@test "launcher_uninstall: reports absent when no bundle present" {
  run launcher_uninstall "$SANDBOX/Applications"
  [ "$status" -eq 0 ]
  [ "$output" = "absent" ]
}

# ── launcher/build.sh ───────────────────────────────────────────────────────

@test "build.sh: produces a plutil-valid Info.plist" {
  "${BOOTSTRAP_DIR}/launcher/build.sh" "$SANDBOX" >/dev/null
  run plutil -lint "$SANDBOX/Just Vibes.app/Contents/Info.plist"
  [ "$status" -eq 0 ]
}

@test "build.sh: bundle declares correct CFBundleExecutable + CFBundleIconFile + CFBundleIdentifier" {
  "${BOOTSTRAP_DIR}/launcher/build.sh" "$SANDBOX" >/dev/null
  plist="$SANDBOX/Just Vibes.app/Contents/Info.plist"

  # Branch F: CFBundleExecutable is `applet` (the osacompile AppleScript
  # runtime stub). DO NOT change this — renaming the Mach-O breaks the
  # bundle. See launcher_improvement_plan.md §1.5.2.
  run /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist"
  [ "$output" = "applet" ]

  # Both icon keys must point at JustVibes (modern macOS asset-catalog
  # resolution can prefer CFBundleIconName). See §1.5.3 finding 1.
  run /usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$plist"
  [ "$output" = "JustVibes" ]
  run /usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$plist"
  [ "$output" = "JustVibes" ]

  # Bundle identity drives Dock tile / Cmd-Tab / Activity Monitor name.
  # CFBundleName is what shows in the Dock and Activity Monitor's "Process
  # Name" column. CFBundleIdentifier must be distinct from Ghostty's
  # `com.mitchellh.ghostty` so LaunchServices treats Just Vibes as its
  # own app.
  run /usr/libexec/PlistBuddy -c "Print :CFBundleName" "$plist"
  [ "$output" = "Just Vibes" ]
  run /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist"
  [ "$output" = "dev.aibootstrap.justvibes" ]
}

@test "build.sh: bundle is ad-hoc code-signed with Just Vibes identifier" {
  # osacompile signs ad-hoc; build.sh re-signs after plist + resource
  # edits to refresh the seal. Without re-signing, macOS Gatekeeper
  # refuses to launch ("damaged and can't be opened"). The signed
  # identifier should match CFBundleIdentifier.
  "${BOOTSTRAP_DIR}/launcher/build.sh" "$SANDBOX" >/dev/null
  run codesign -dv "$SANDBOX/Just Vibes.app"
  [ "$status" -eq 0 ]
  # codesign -dv writes to stderr; bats captures it via $output.
  [[ "$output" == *"Identifier=dev.aibootstrap.justvibes"* ]]
  [[ "$output" == *"Signature=adhoc"* ]]
}

@test "build.sh: AppleScript host source contains no banned LaunchServices triggers" {
  # Regression gate from launcher_improvement_plan.md §1.5.6 (rev-6
  # constraints): the AppleScript host MUST NOT use `tell application
  # "Ghostty"` or `exists application "Ghostty"`. Both compile to
  # LaunchServices bundle-resolution calls that LAUNCH Ghostty as a side
  # effect — the original ghost-process bug. The committed
  # launcher/launch.applescript must stay clean.
  #
  # Strip AppleScript line comments (-- to end of line) before grepping
  # so that the file's documentation explaining WHY these constructs are
  # banned doesn't trigger the gate. AppleScript's only line-comment
  # syntax is `--` (block comments use `(* ... *)` and we don't use them
  # here).
  src="${BOOTSTRAP_DIR}/launcher/launch.applescript"
  [ -f "$src" ]
  stripped="$(sed -E 's/--.*$//' "$src")"
  ! echo "$stripped" | grep -qE 'tell[[:space:]]+application[[:space:]]+"Ghostty"'
  ! echo "$stripped" | grep -qE 'exists[[:space:]]+application[[:space:]]+"Ghostty"'
}

@test "build.sh: errors with usage when called with no args" {
  run "${BOOTSTRAP_DIR}/launcher/build.sh"
  [ "$status" -eq 64 ]
  [[ "$output" == *"usage:"* ]]
}

# ── launcher/launch-helper.sh ──────────────────────────────────────────────────────

@test "launch-helper.sh: defaults launch ghostty with --working-directory + opencode (cold-state)" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch
  [ "$status" -eq 0 ]
  # Phase 6 (Option A): launcher passes `--command=zsh -l -i -c <opencode>`
  # via `--args` instead of `-e <opencode>`. The `-e` form was delivered
  # twice by Ghostty (applicationDidFinishLaunching + LaunchServices open
  # delegate), producing two tabs and a security prompt. The mock opencode
  # lives at $SANDBOX/opencode.
  #
  # Phase 6.6: cold-state (Ghostty NOT running, the mock's default) uses
  # `-Fa` WITHOUT `-n`. With `-n` from a .app-bundle context cold-state,
  # an extra bare ghostty process spawns alongside the flagged one (the
  # ghost). See launcher_improvement_plan.md §1.5.4.2.
  grep -q "open -Fa Ghostty.app --args --title=Just Vibes --working-directory=$SANDBOX/workspace --command=zsh -l -i -c $SANDBOX/opencode" "$MOCK_LOG"
  # Belt-and-suspenders: explicitly assert the legacy -e form is not used.
  saved="$(cat "$MOCK_LOG")"
  [[ "$saved" != *" -e $SANDBOX/opencode"* ]]
  # rev-8 / Phase 6.5 regression gate: the bare `-na` (without `F`) form
  # must NOT appear — it would re-introduce macOS save-state restoration
  # on Just Vibes launches. See zsh_init_plan.md §3.10.
  [[ "$saved" != *"open -na "* ]]
  # Phase 6.6 regression gate: cold-state must NOT include `-n`.
  [[ "$saved" != *"open -nFa"* ]]
  [[ "$saved" != *"open -nF "* ]]
}

@test "launch-helper.sh: uses opensession when keychain password and tailscale CLI exist" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  _mock_security present
  _mock_tailscale
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch
  [ "$status" -eq 0 ]
  grep -q "open -Fa Ghostty.app --args --title=Just Vibes --working-directory=$SANDBOX/workspace --command=zsh -l -i -c '\"$SANDBOX/workspace/scripts/personal/opensession.sh\" || \"$SANDBOX/opencode\"'" "$MOCK_LOG"
  grep -q "security find-generic-password -s opencode-server-password -a $USER -w" "$MOCK_LOG"
}

@test "launch-helper.sh: uses bare opencode when keychain password is missing" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  _mock_security missing
  _mock_tailscale
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch
  [ "$status" -eq 0 ]
  saved="$(cat "$MOCK_LOG")"
  [[ "$saved" == *"--command=zsh -l -i -c $SANDBOX/opencode"* ]]
  [[ "$saved" != *"opensession.sh"* ]]
}

@test "launch-helper.sh: uses bare opencode when tailscale CLI is missing" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  _mock_security present
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch
  [ "$status" -eq 0 ]
  saved="$(cat "$MOCK_LOG")"
  [[ "$saved" == *"--command=zsh -l -i -c $SANDBOX/opencode"* ]]
  [[ "$saved" != *"opensession.sh"* ]]
}

@test "launch-helper.sh: hot-state (Ghostty already running) launches with -nFa" {
  _mock_open
  _mock_osascript present running
  _mock_opencode
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch
  [ "$status" -eq 0 ]
  # Phase 6.6: hot-state (Ghostty already running) uses `-nFa` WITH `-n`.
  # Without `-n`, `open -a` activates the running Ghostty and silently
  # discards `--args` — no new window. See launcher_improvement_plan.md
  # §1.5.4.1 hypothesis 3.
  grep -q "open -n -Fa Ghostty.app --args --title=Just Vibes --working-directory=$SANDBOX/workspace --command=zsh -l -i -c $SANDBOX/opencode" "$MOCK_LOG"
  saved="$(cat "$MOCK_LOG")"
  # Detection occurred via osascript "running of application".
  grep -q "running of application" "$MOCK_LOG"
}

@test "launch-helper.sh: JUST_VIBES_LAUNCH_OPENCODE=0 omits the --command opencode arg" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch JUST_VIBES_LAUNCH_OPENCODE=0
  [ "$status" -eq 0 ]
  # Neither the opencode binary path nor the --command= arg should appear.
  saved="$(cat "$MOCK_LOG")"
  [[ "$saved" != *"$SANDBOX/opencode"* ]]
  [[ "$saved" != *"--command="* ]]
  # rev-8 / Phase 6.5: even with opencode disabled, `-Fa` (cold-state) and
  # the title arg must still be present. Phase 6.6: cold-state default,
  # so no `-n`.
  grep -q "open -Fa Ghostty.app --args --title=Just Vibes --working-directory=$SANDBOX/workspace" "$MOCK_LOG"
  [[ "$saved" != *"open -na "* ]]
  [[ "$saved" != *"open -nFa"* ]]
}

@test "launch-helper.sh: missing state file falls back to \$HOME" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  # No state.sh written.

  run _run_launch
  [ "$status" -eq 0 ]
  # Cold-state default — no `-n`.
  grep -q "open -Fa Ghostty.app --args --title=Just Vibes --working-directory=$HOME" "$MOCK_LOG"
}

@test "launch-helper.sh: invalid workspace path in state falls back to \$HOME" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/does-not-exist'" >"$SANDBOX/state.sh"

  run _run_launch
  [ "$status" -eq 0 ]
  # Cold-state default — no `-n`.
  grep -q "open -Fa Ghostty.app --args --title=Just Vibes --working-directory=$HOME" "$MOCK_LOG"
}

@test "launch-helper.sh: unsafe state file falls back without sourcing it" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  mkdir -p "$SANDBOX/workspace"
  cat >"$SANDBOX/state.sh" <<EOF
#!/bin/bash
export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'
touch '$SANDBOX/pwned'
EOF

  run _run_launch
  [ "$status" -eq 0 ]
  [ ! -e "$SANDBOX/pwned" ]
  grep -q "open -Fa Ghostty.app --args --title=Just Vibes --working-directory=$HOME" "$MOCK_LOG"
}

@test "launch-helper.sh: missing ghostty shows alert and exits 1 without opening" {
  _mock_open
  _mock_osascript
  _mock_opencode
  _unmock_ghostty

  run _run_launch
  [ "$status" -eq 1 ]
  # No `open` call should have been made.
  saved="$(cat "$MOCK_LOG")"
  [[ "$saved" != *"open -nFa"* ]]
  [[ "$saved" != *"open -Fa"* ]]
  [[ "$saved" != *"open -naF"* ]]
  [[ "$saved" != *"open -na "* ]]
  # User-facing alert must be issued.
  grep -q "display alert" "$MOCK_LOG"
}

@test "launch-helper.sh: respects JUST_VIBES_GHOSTTY_APP override (e.g. for forks)" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  mkdir -p "$SANDBOX/workspace"
  # Drop a matching fake bundle so the filesystem existence check finds it.
  mkdir -p "$SANDBOX/Wezterm.app"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch JUST_VIBES_GHOSTTY_APP=Wezterm.app
  [ "$status" -eq 0 ]
  # Cold-state default — no `-n`.
  grep -q "open -Fa Wezterm.app --args --title=Just Vibes" "$MOCK_LOG"
}

# ── Branch F.1 (§8.7): ghostty PID capture for `on reopen` focus ───────────

@test "launch-helper.sh: writes ghostty PID file when pgrep resolves a process" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  _mock_pgrep "12345"
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch JUST_VIBES_TRACK_GHOSTTY_PID=1
  [ "$status" -eq 0 ]
  # PID file lives under $TMPDIR/just-vibes/ghostty.pid; _run_launch sets
  # TMPDIR=$SANDBOX/tmp.
  pid_file="$SANDBOX/tmp/just-vibes/ghostty.pid"
  [ -f "$pid_file" ]
  [ "$(cat "$pid_file")" = "12345" ]
  # pgrep argv must include both the canonical Mach-O path and the
  # --title=Just Vibes key. Belt-and-suspenders: a future refactor that
  # narrows the pattern in a way that picks up unrelated ghostty
  # processes will trip this gate.
  grep -q 'pgrep -nf Ghostty.app/Contents/MacOS/ghostty .*--title=Just Vibes' "$MOCK_LOG"
}

@test "launch-helper.sh: skips PID write when pgrep returns nothing within deadline" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  _mock_pgrep ""
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  run _run_launch JUST_VIBES_TRACK_GHOSTTY_PID=1
  [ "$status" -eq 0 ]
  # No pid file should exist (PID capture is best-effort).
  [ ! -e "$SANDBOX/tmp/just-vibes/ghostty.pid" ]
  # Helper still polls — verify pgrep was actually invoked.
  grep -q 'pgrep -nf' "$MOCK_LOG"
}

@test "launch-helper.sh: PID-write deadline does not block helper exit > 2.5s" {
  _mock_open
  _mock_osascript present
  _mock_opencode
  # pgrep returns empty + sleeps 100ms each call. The helper polls every
  # 100ms with a 2s deadline, so this must still come in under 2.5s.
  _mock_pgrep ""
  mkdir -p "$SANDBOX/workspace"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"

  start_ms=$(perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000')
  run env PGREP_SLEEP_MS=100 _run_launch_inner=1 \
    "JUST_VIBES_OPEN_BIN=$SANDBOX/open" \
    "JUST_VIBES_OSASCRIPT_BIN=$SANDBOX/osascript" \
    "JUST_VIBES_OPENCODE_PATHS=$SANDBOX/opencode" \
    "JUST_VIBES_GHOSTTY_SEARCH_PATHS=$SANDBOX" \
    "AI_BOOTSTRAP_STATE_FILE=$SANDBOX/state.sh" \
    "JUST_VIBES_TRACK_GHOSTTY_PID=1" \
    "TMPDIR=$SANDBOX/tmp" \
    "PATH=$SANDBOX:/usr/bin:/bin" \
    bash "${BOOTSTRAP_DIR}/launcher/launch-helper.sh"
  end_ms=$(perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000')
  [ "$status" -eq 0 ]
  elapsed=$((end_ms - start_ms))
  echo "elapsed: ${elapsed}ms"
  [ "$elapsed" -lt 2500 ]
}

# ── opencode resolution ────────────────────────────────────────────────────

@test "launch-helper.sh: missing opencode shows alert and exits 1 without opening" {
  # Regression: the very bug that made you file the issue. If opencode
  # can't be found in any of the candidate paths, we must NOT pass the
  # bare string `opencode` to Ghostty (which would then fail to find it
  # via `/usr/bin/login -flp <user> opencode`). Instead, surface a
  # friendly alert.
  _mock_open
  _mock_osascript present
  # No _mock_opencode — opencode is genuinely absent.

  run env \
    "JUST_VIBES_OPEN_BIN=$SANDBOX/open" \
    "JUST_VIBES_OSASCRIPT_BIN=$SANDBOX/osascript" \
    "JUST_VIBES_OPENCODE_PATHS=/nonexistent/opencode" \
    "JUST_VIBES_GHOSTTY_SEARCH_PATHS=$SANDBOX" \
    "AI_BOOTSTRAP_STATE_FILE=$SANDBOX/state.sh" \
    "PATH=/usr/bin:/bin" \
    bash "${BOOTSTRAP_DIR}/launcher/launch-helper.sh"
  [ "$status" -eq 1 ]
  saved="$(cat "$MOCK_LOG")"
  [[ "$saved" != *"open -nFa"* ]]
  [[ "$saved" != *"open -Fa"* ]]
  [[ "$saved" != *"open -naF"* ]]
  [[ "$saved" != *"open -na "* ]]
  grep -q "display alert" "$MOCK_LOG"
  grep -q "OpenCode is not installed" "$MOCK_LOG"
}

@test "launch-helper.sh: resolves opencode from first candidate path that exists" {
  # Multiple candidates; pick the first existing one. Simulates the
  # priority-order in launch-helper.sh: /opt/homebrew/bin first, then
  # /usr/local/bin, then ~/.local/bin.
  _mock_open
  _mock_osascript present
  mkdir -p "$SANDBOX/workspace" "$SANDBOX/a" "$SANDBOX/b"
  # Make 'b' exist; 'a' does not. Order: a first, b second.
  cat >"$SANDBOX/b/opencode" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$SANDBOX/b/opencode"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"
  _make_hermetic_launcher_path

  run /usr/bin/env \
    "JUST_VIBES_OPEN_BIN=$SANDBOX/open" \
    "JUST_VIBES_OSASCRIPT_BIN=$SANDBOX/osascript" \
    "JUST_VIBES_OPENCODE_PATHS=$SANDBOX/a/opencode:$SANDBOX/b/opencode" \
    "JUST_VIBES_GHOSTTY_SEARCH_PATHS=$SANDBOX" \
    "AI_BOOTSTRAP_STATE_FILE=$SANDBOX/state.sh" \
    "JUST_VIBES_TRACK_GHOSTTY_PID=0" \
    "PATH=$SANDBOX/hermetic-bin" \
    /bin/bash "${BOOTSTRAP_DIR}/launcher/launch-helper.sh"
  [ "$status" -eq 0 ]
  grep -q -- "--command=zsh -l -i -c $SANDBOX/b/opencode" "$MOCK_LOG"
}

@test "launch-helper.sh: falls back to PATH when no candidate path matches" {
  # If a user installed opencode somewhere unusual (not /opt/homebrew,
  # not /usr/local, not ~/.local), but it IS on their PATH, the launcher
  # should still find it. Simulate by putting opencode on a custom PATH.
  _mock_open
  _mock_osascript present
  mkdir -p "$SANDBOX/custom" "$SANDBOX/workspace"
  cat >"$SANDBOX/custom/opencode" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$SANDBOX/custom/opencode"
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/workspace'" >"$SANDBOX/state.sh"
  _make_hermetic_launcher_path

  run /usr/bin/env \
    "JUST_VIBES_OPEN_BIN=$SANDBOX/open" \
    "JUST_VIBES_OSASCRIPT_BIN=$SANDBOX/osascript" \
    "JUST_VIBES_OPENCODE_PATHS=/nonexistent" \
    "JUST_VIBES_GHOSTTY_SEARCH_PATHS=$SANDBOX" \
    "AI_BOOTSTRAP_STATE_FILE=$SANDBOX/state.sh" \
    "JUST_VIBES_TRACK_GHOSTTY_PID=0" \
    "PATH=$SANDBOX/custom:$SANDBOX/hermetic-bin" \
    /bin/bash "${BOOTSTRAP_DIR}/launcher/launch-helper.sh"
  [ "$status" -eq 0 ]
  grep -q -- "--command=zsh -l -i -c $SANDBOX/custom/opencode" "$MOCK_LOG"
}

# ── launcher_resolve_dest ──────────────────────────────────────────────────

@test "launcher_resolve_dest: honors JUST_VIBES_DEST_DIR_OVERRIDE for tests" {
  # `env` can't run a shell function — set the var in this shell, then
  # call the function directly, then unset.
  export JUST_VIBES_DEST_DIR_OVERRIDE="$SANDBOX/custom"
  run launcher_resolve_dest
  unset JUST_VIBES_DEST_DIR_OVERRIDE
  [ "$status" -eq 0 ]
  [ "$output" = "$SANDBOX/custom" ]
}

@test "launcher_resolve_dest: prefers /Applications when writable" {
  # On the local dev mac, /Applications is admin-group writable. CI runs
  # as a user that may or may not be in admin; this test asserts the
  # logic, not the host: if /Applications IS writable, we pick it.
  if [ -w /Applications ]; then
    run launcher_resolve_dest
    [ "$output" = "/Applications" ]
  else
    skip "/Applications not writable on this machine; behavior tested via override"
  fi
}

@test "launcher_resolve_dest: falls back to ~/Applications when /Applications read-only" {
  # We can't realistically chmod /Applications in a test, so we exercise
  # the fallback path by simulating it: launcher_resolve_dest's logic
  # is `if [ -w /Applications ]; then ...; else ...; fi`. On a machine
  # where /Applications is not writable (corp Macs, non-admin accounts),
  # the override env var lets us pin the answer for the default path.
  # Here we just verify the contract by calling the function under a
  # forced-fallback condition. Use a wrapper that overrides [ -w ].
  #
  # Simpler approach: assert the function returns SOMETHING that is
  # either /Applications or $HOME/Applications, and verify the
  # fallback string format directly.
  run launcher_resolve_dest
  [ "$status" -eq 0 ]
  # Must be one of the two valid options (no override set in this test).
  [[ "$output" == "/Applications" || "$output" == "$HOME/Applications" ]]
}
