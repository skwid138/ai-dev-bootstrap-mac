#!/usr/bin/env bats
# AppleScript-host tests for the JustVibes launcher (Branch F.1, §8.7).
#
# These tests cover the `on reopen` focus handler added in Branch F.1.
# The handler's job is: when the user Cmd-Tabs to "JustVibes" while the
# applet is already running, bring the spawned Ghostty window forward
# instead of doing nothing visible.
#
# Why this is mostly static-grep, not full dynamic execution:
#
#   The `on reopen` handler delegates to three units:
#     1. `readGhostyPid` — `do shell script "cat …"` (bash, mockable).
#     2. `focusGhostty` — `tell application "System Events" …` (NOT
#        bash; a direct AppleEvent that cannot be intercepted via
#        PATH-based shell mocks).
#     3. `runHelper` — `do shell script "<helper>"` (bash, mockable).
#
#   Dynamic-test difficulty: the only observable that distinguishes
#   "focus succeeded" from "focus failed → fell back to runHelper" is
#   whether the helper was invoked. To trigger the success branch we'd
#   need a unix PID that System Events both finds AND can `set frontmost`
#   on — i.e. a real GUI process. CI runs macOS headless; using a real
#   GUI PID (Finder, etc.) is brittle there and creates cross-test
#   timing dependencies.
#
#   Following §8.7.4's pre-authorized fallback ("test the bash-callable
#   equivalents and rely on the static gate to prove the AppleScript
#   wires them correctly"), this file uses static-grep assertions for
#   the control-flow shape, PLUS one dynamic compile-and-fire test
#   that exercises the most important real-world path (missing pidfile
#   → falls through to helper) end-to-end through osacompile + the
#   AppleScript runtime. That dynamic case is reliable on CI because
#   it doesn't depend on System Events finding any specific process.
#
# Static-grep gates for the other two cases (valid PID → focus path,
# stale PID → clear-and-relaunch path) verify that the code paths exist
# in the source and call the right things. The full e2e of "Cmd-Tab
# brings the actual Ghostty window forward" is verified manually on a
# dev box per §8.7.8 Definition of Done.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  APPLESCRIPT_SRC="$BOOTSTRAP_DIR/launcher/launch.applescript"
  SANDBOX="$(mktemp -d)"
  export SANDBOX
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# Strip AppleScript line comments before grepping. AppleScript's only
# line-comment syntax is `--`; block comments are `(* ... *)` and we
# don't use them. Without stripping, the file's documentation about
# (e.g.) "do NOT use `tell application \"Ghostty\"`" would trigger
# negative-pattern gates.
_stripped() {
  sed -E 's/--.*$//' "$APPLESCRIPT_SRC"
}

# ── Static control-flow gates ───────────────────────────────────────────────

@test "launch.applescript: declares an on reopen handler" {
  # The whole point of Branch F.1 (§8.7). Without `on reopen`,
  # Cmd-Tabbing to JustVibes while it's running does nothing visible.
  _stripped | grep -qE '^[[:space:]]*on[[:space:]]+reopen[[:space:]]*$'
}

@test "launch.applescript: on reopen delegates to refocusOrRelaunch" {
  # Keep the reopen handler tiny — a single `my refocusOrRelaunch()`
  # call. The orchestration logic lives in refocusOrRelaunch where it
  # can be reasoned about in isolation. If a future refactor inlines
  # the logic into `on reopen`, this gate fails so we re-check the
  # control flow.
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+reopen[[:space:]]*$/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+reopen[[:space:]]*$/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE 'my[[:space:]]+refocusOrRelaunch'
}

@test "launch.applescript: refocusOrRelaunch reads the tracked PID via readGhostyPid" {
  # The PID-file path lives in launch-helper.sh; the AppleScript reads
  # it through readGhostyPid. If a refactor stops calling readGhostyPid
  # the focus path silently breaks (always-relaunch) — surface that.
  _stripped | grep -qE 'on[[:space:]]+refocusOrRelaunch'
  _stripped | grep -qE 'readGhostyPid'
}

@test "launch.applescript: refocusOrRelaunch invokes focusGhostty for non-zero PIDs" {
  # The success path: tracked PID exists → System Events focus call.
  # Static-grep is the strongest assertion we can make portably (see
  # file header for why we don't drive System Events in tests).
  _stripped | grep -qE 'focusGhostty'
}

@test "launch.applescript: refocusOrRelaunch clears stale pidfile before runHelper fallback" {
  # Stale-PID branch (process died, pidfile lingers): clear the file
  # so subsequent reopens don't keep trying the dead PID. The clear
  # must happen via `rm -f` (best-effort, no error on missing file)
  # in the same orchestrator.
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+refocusOrRelaunch[[:space:]]*\(\)[[:space:]]*$/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+refocusOrRelaunch[[:space:]]*$/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE 'rm[[:space:]]+-f.*ghostty\.pid'
}

@test "launch.applescript: focusGhostty uses System Events (not tell application Ghostty)" {
  # Branch F.1 §8.7.2 hard rule: focus must go through System Events
  # to avoid LaunchServices bundle resolution. `tell application
  # "Ghostty"` would re-introduce the ghost-process bug Branch E
  # fixed. The build.sh test in test_launcher_lib.bats already gates
  # the negative; this one is the positive.
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+focusGhostty/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+focusGhostty/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE 'tell[[:space:]]+application[[:space:]]+"System Events"'
}

@test "launch.applescript: focusGhostty handles errors (try/on error around System Events)" {
  # If System Events refuses (Accessibility denied, process dead),
  # focusGhostty must NOT propagate the error — it must return false
  # so refocusOrRelaunch can fall through to runHelper. A missing
  # try/on error would crash the AppleScript runtime instead.
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+focusGhostty/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+focusGhostty/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE '^[[:space:]]*try[[:space:]]*$'
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+focusGhostty/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+focusGhostty/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE '^[[:space:]]*on[[:space:]]+error[[:space:]]*$'
}

@test "launch.applescript: on quit cleans up tracked Ghostty PID best-effort before continuing quit" {
  # Branch F.2: quitting JustVibes should also ask the tracked Ghostty
  # process to terminate and remove the PID file. This must remain
  # best-effort (try-wrapped) and must still end with `continue quit` so
  # cleanup failures never strand the AppleScript applet.
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+quit[[:space:]]*$/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+quit[[:space:]]*$/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE 'set[[:space:]]+pid[[:space:]]+to[[:space:]]+my[[:space:]]+readGhostyPid\(\)'
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+quit[[:space:]]*$/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+quit[[:space:]]*$/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE 'do[[:space:]]+shell[[:space:]]+script[[:space:]]+"kill "[[:space:]]+&[[:space:]]+pid'
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+quit[[:space:]]*$/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+quit[[:space:]]*$/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE 'rm[[:space:]]+-f.*ghostty\.pid'
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+quit[[:space:]]*$/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+quit[[:space:]]*$/ { in_handler=0; next }
    in_handler && /^[[:space:]]*try[[:space:]]*$/ { tries++ }
    END { exit !(tries >= 2) }
  '
  _stripped | awk '
    /^[[:space:]]*on[[:space:]]+quit[[:space:]]*$/ { in_handler=1; next }
    in_handler && /^[[:space:]]*end[[:space:]]+quit[[:space:]]*$/ { in_handler=0; next }
    in_handler { print }
  ' | grep -qE '^[[:space:]]*continue[[:space:]]+quit[[:space:]]*$'
}

@test "launch.applescript: pid-file path matches launch-helper.sh writer" {
  # The reader (readGhostyPid in AppleScript) and the writer
  # (launch-helper.sh) must agree on the path. If a refactor moves
  # one without the other, the focus path silently never finds a PID
  # and we always fall back to relaunch. Assert both reference the
  # same `${TMPDIR:-/tmp}/justvibes/ghostty.pid` shape.
  _stripped | grep -qE '\$\{TMPDIR:-/tmp\}/justvibes/ghostty\.pid'
  grep -qE '\$\{TMPDIR:-/tmp\}/justvibes"' "$BOOTSTRAP_DIR/launcher/launch-helper.sh" \
    || grep -qE '\$\{TMPDIR:-/tmp\}/justvibes/ghostty\.pid' "$BOOTSTRAP_DIR/launcher/launch-helper.sh"
}

# ── Dynamic: compile + fire reopen against a missing pidfile ───────────────
#
# This is the one test that drives the AppleScript runtime end-to-end.
# It covers the most common real-world path (no PID tracked yet → cold
# fallback to runHelper) and proves that:
#   1. The AppleScript compiles cleanly with the new handlers.
#   2. The reopen handler actually fires (i.e. the bundle declares the
#      handler in a way macOS's AppleEvent dispatcher recognizes).
#   3. The runHelper fallback path actually invokes the helper script.
#
# The other two cases (valid PID → focus, stale PID → clear+relaunch)
# require a real GUI process to test System Events focus reliably; we
# rely on the static-grep gates above + manual dev-box verification per
# §8.7.8 Definition of Done.

@test "launch.applescript: on reopen with missing pidfile invokes the helper" {
  [[ -n "${CI:-}" ]] && skip "requires macOS GUI session for AppleEvent tests"

  # Skip when osacompile or osascript isn't on PATH (non-mac runner).
  command -v osacompile >/dev/null 2>&1 || skip "osacompile not available"
  command -v osascript >/dev/null 2>&1 || skip "osascript not available"

  # Build a sandboxed bundle whose helper is a logging shim. Use a
  # unique CFBundleIdentifier per test invocation so LaunchServices
  # doesn't cache a previous test's bundle and route the AppleEvent
  # to a stale `.app` location.
  bundle="$SANDBOX/Reopen Test.app"
  osacompile -s -o "$bundle" "$APPLESCRIPT_SRC"

  # Replace the bundle id with a unique-per-test value. Use plutil
  # (always available on macOS) to edit Info.plist in place.
  test_id="dev.aibootstrap.justvibes.test.$$.$RANDOM"
  plutil -replace CFBundleIdentifier -string "$test_id" "$bundle/Contents/Info.plist"

  # Drop a logging helper script into the bundle. The AppleScript's
  # `helperPath` resolves to <bundle>/Contents/Resources/launch-helper.sh.
  helper_log="$SANDBOX/helper.log"
  mkdir -p "$bundle/Contents/Resources"
  cat >"$bundle/Contents/Resources/launch-helper.sh" <<EOF
#!/usr/bin/env bash
echo "helper invoked at \$(date +%s)" >>"$helper_log"
exit 0
EOF
  chmod +x "$bundle/Contents/Resources/launch-helper.sh"

  # Re-sign ad-hoc after editing Info.plist + adding the helper. Without
  # this, Gatekeeper may refuse to run the bundle. Failure here is
  # non-fatal for tests (ad-hoc sign on a sandbox bundle has no real
  # gatekeeper impact), but cleanest to do it.
  codesign -s - --force --deep "$bundle" >/dev/null 2>&1 || true

  # Override TMPDIR so readGhostyPid looks at our sandbox, not the
  # host's real temp dir. Ensure the pidfile is genuinely absent.
  pid_dir="$SANDBOX/tmp/justvibes"
  rm -rf "$pid_dir"

  # Register the bundle with LaunchServices so `tell application id`
  # can find it. lsregister -dump would list it; -f forces a re-add.
  lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  if [ -x "$lsregister" ]; then
    "$lsregister" -f "$bundle" >/dev/null 2>&1 || true
  fi

  # Launch the applet executable directly in the background; the
  # applet's `on run` fires (which invokes the helper once — the
  # cold-state baseline). Wait for that, then fire reopen and observe a
  # SECOND helper invocation. Direct launch avoids LaunchServices quirks
  # where `open -g` can return 0 without actually starting temporary
  # unsigned applets in headless test sessions.
  #
  # We use `tell application id "<test_id>" to reopen` rather than the
  # bundle name because the unique id avoids LaunchServices ambiguity
  # if a real JustVibes is installed on the test host.
  TMPDIR="$SANDBOX/tmp" "$bundle/Contents/MacOS/applet" >/dev/null 2>&1 &
  app_pid=$!
  # Wait for `on run` to complete and write the first helper line.
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    if [ -s "$helper_log" ]; then break; fi
    sleep 0.2
  done

  # The on-run pass should have logged once. If it didn't, the bundle
  # either failed to launch or the AppleScript failed to compile —
  # either way, surface that as the test failure.
  [ -s "$helper_log" ] || { echo "helper was never invoked on initial launch"; cat "$bundle/Contents/Info.plist"; ls -laR "$bundle"; return 1; }
  initial_count=$(wc -l <"$helper_log" | tr -d ' ')

  # Fire reopen. Pidfile is absent → readGhostyPid returns 0 →
  # refocusOrRelaunch calls runHelper → helper is invoked again.
  TMPDIR="$SANDBOX/tmp" osascript -e "tell application id \"$test_id\" to reopen" >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    new_count=$(wc -l <"$helper_log" | tr -d ' ')
    if [ "$new_count" -gt "$initial_count" ]; then break; fi
    sleep 0.2
  done

  final_count=$(wc -l <"$helper_log" | tr -d ' ')
  echo "helper invocations: initial=$initial_count final=$final_count"
  [ "$final_count" -gt "$initial_count" ]

  # Cleanup: ask the applet to quit so it doesn't hang around.
  osascript -e "tell application id \"$test_id\" to quit" >/dev/null 2>&1 || true
  kill "$app_pid" >/dev/null 2>&1 || true
  # Best-effort de-register from LaunchServices so subsequent test runs
  # see a fresh bundle.
  if [ -x "$lsregister" ]; then
    "$lsregister" -u "$bundle" >/dev/null 2>&1 || true
  fi
}

@test "launch.applescript: on quit kills tracked PID and removes pidfile" {
  [[ -n "${CI:-}" ]] && skip "requires macOS GUI session for AppleEvent tests"

  command -v osacompile >/dev/null 2>&1 || skip "osacompile not available"
  command -v osascript >/dev/null 2>&1 || skip "osascript not available"

  bundle="$SANDBOX/Quit Test.app"
  osacompile -s -o "$bundle" "$APPLESCRIPT_SRC"

  test_id="dev.aibootstrap.justvibes.quit.test.$$.$RANDOM"
  plutil -replace CFBundleIdentifier -string "$test_id" "$bundle/Contents/Info.plist"

  mkdir -p "$bundle/Contents/Resources"
  cat >"$bundle/Contents/Resources/launch-helper.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$bundle/Contents/Resources/launch-helper.sh"
  codesign -s - --force --deep "$bundle" >/dev/null 2>&1 || true

  lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  if [ -x "$lsregister" ]; then
    "$lsregister" -f "$bundle" >/dev/null 2>&1 || true
  fi

  pid_dir="$SANDBOX/tmp/justvibes"
  mkdir -p "$pid_dir"
  term_log="$SANDBOX/term.log"
  /bin/sh -c 'trap "echo term > \"$1\"; exit 0" TERM; while :; do sleep 1; done' sh "$term_log" &
  ghostty_pid=$!
  echo "$ghostty_pid" >"$pid_dir/ghostty.pid"

  TMPDIR="$SANDBOX/tmp" "$bundle/Contents/MacOS/applet" >/dev/null 2>&1 &
  app_pid=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    TMPDIR="$SANDBOX/tmp" osascript -e "tell application id \"$test_id\" to get running" >/dev/null 2>&1 && break
    sleep 0.2
  done

  TMPDIR="$SANDBOX/tmp" osascript -e "tell application id \"$test_id\" to quit" >/dev/null 2>&1 || true

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if [ -s "$term_log" ]; then break; fi
    sleep 0.2
  done

  if [ ! -s "$term_log" ]; then
    kill "$ghostty_pid" >/dev/null 2>&1 || true
    wait "$ghostty_pid" 2>/dev/null || true
    echo "tracked process did not receive TERM from on quit"
    return 1
  fi
  wait "$ghostty_pid" 2>/dev/null || true

  [ ! -e "$pid_dir/ghostty.pid" ]
  kill "$app_pid" >/dev/null 2>&1 || true

  if [ -x "$lsregister" ]; then
    "$lsregister" -u "$bundle" >/dev/null 2>&1 || true
  fi
}
