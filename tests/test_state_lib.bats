#!/usr/bin/env bats
# Tests for lib/state.sh (enriched-state writer + reader).
#
# The early workspace-only writer (lib/workspace.sh::workspace_write_state)
# is covered by test_workspace_lib.bats; this file covers the enriched
# state.sh that gets written at the END of bootstrap, including:
#
#   * tier preservation
#   * version stamping
#   * first-run-at preservation across re-runs
#   * last-run-at update on every run
#
# Time is pinned via AI_BOOTSTRAP_NOW_OVERRIDE so tests are deterministic.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/state.sh
  source "${BOOTSTRAP_DIR}/lib/state.sh"

  SANDBOX="$(mktemp -d)"
  STATE="$SANDBOX/state.sh"
}

teardown() {
  unset AI_BOOTSTRAP_NOW_OVERRIDE
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

@test "state_write: writes a sourceable file with all required fields" {
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-05-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE

  run state_write "$STATE" "$SANDBOX/code" "recommended"
  [ "$status" -eq 0 ]
  [ -f "$STATE" ]

  # Source it in a subshell and verify each field.
  values=$(
    # shellcheck disable=SC1090
    source "$STATE"
    echo "WS=$AI_BOOTSTRAP_WORKSPACE"
    echo "TIER=$AI_BOOTSTRAP_TIER"
    echo "VER=$AI_BOOTSTRAP_VERSION"
    echo "FIRST=$AI_BOOTSTRAP_FIRST_RUN_AT"
    echo "LAST=$AI_BOOTSTRAP_LAST_RUN_AT"
    echo "CURATED=${AI_BOOTSTRAP_CURATED_MODELS-__unset__}"
  )
  [[ "$values" == *"WS=$SANDBOX/code"* ]]
  [[ "$values" == *"TIER=recommended"* ]]
  [[ "$values" == *"VER=2.0.0"* ]]
  [[ "$values" == *"FIRST=2026-05-01T00:00:00Z"* ]]
  [[ "$values" == *"LAST=2026-05-01T00:00:00Z"* ]]
  [[ "$values" == *"CURATED="* ]]
}

@test "state_write: writes AI_BOOTSTRAP_DIR when bootstrap dir is provided" {
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-05-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE

  run state_write "$STATE" "$SANDBOX/code" "recommended" "$SANDBOX/ai-dev-bootstrap-mac"
  [ "$status" -eq 0 ]

  values=$(
    # shellcheck disable=SC1090
    source "$STATE"
    echo "DIR=$AI_BOOTSTRAP_DIR"
  )
  [[ "$values" == *"DIR=$SANDBOX/ai-dev-bootstrap-mac"* ]]
}

@test "state_write: omits AI_BOOTSTRAP_DIR when bootstrap dir is empty" {
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-05-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE

  run state_write "$STATE" "$SANDBOX/code" "recommended"
  [ "$status" -eq 0 ]
  ! grep -qF "AI_BOOTSTRAP_DIR" "$STATE"
}

@test "state_write: preserves AI_BOOTSTRAP_FIRST_RUN_AT across re-runs" {
  # Run 1: pin time T1, expect FIRST_RUN_AT=T1.
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-01-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE
  state_write "$STATE" "$SANDBOX/code" "essential"

  # Run 2: pin time T2, expect FIRST_RUN_AT=T1 (preserved), LAST_RUN_AT=T2.
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-06-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE
  state_write "$STATE" "$SANDBOX/code" "essential"

  values=$(
    # shellcheck disable=SC1090
    source "$STATE"
    echo "FIRST=$AI_BOOTSTRAP_FIRST_RUN_AT"
    echo "LAST=$AI_BOOTSTRAP_LAST_RUN_AT"
  )
  [[ "$values" == *"FIRST=2026-01-01T00:00:00Z"* ]]
  [[ "$values" == *"LAST=2026-06-01T00:00:00Z"* ]]
}

@test "state_write: updates tier on re-run (user upgraded essential -> complete)" {
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-01-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE
  state_write "$STATE" "$SANDBOX/code" "essential"

  AI_BOOTSTRAP_NOW_OVERRIDE="2026-06-01T00:00:00Z"
  state_write "$STATE" "$SANDBOX/code" "complete"

  tier=$(
    # shellcheck disable=SC1090
    source "$STATE"
    echo "$AI_BOOTSTRAP_TIER"
  )
  [ "$tier" = "complete" ]
}

@test "state_write: creates parent directory if missing" {
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-05-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE

  nested="$SANDBOX/never/existed/state.sh"
  run state_write "$nested" "$SANDBOX/code" "recommended"
  [ "$status" -eq 0 ]
  [ -f "$nested" ]
}

@test "state_write: does not rewrite existing state when temp file cannot be created" {
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-05-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE

  locked_dir="$SANDBOX/locked"
  mkdir -p "$locked_dir"
  state_file="$locked_dir/state.sh"
  echo "original" >"$state_file"
  chmod 500 "$locked_dir"

  run state_write "$state_file" "$SANDBOX/code" "recommended"
  chmod 700 "$locked_dir"

  [ "$status" -eq 1 ]
  run cat "$state_file"
  [ "$output" = "original" ]
}

@test "state_read_field: returns 1 when file missing" {
  run state_read_field "$SANDBOX/no-such-file.sh" "AI_BOOTSTRAP_TIER"
  [ "$status" -eq 1 ]
}

@test "state_read_field: returns 1 when var unset" {
  echo "export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/code'" >"$STATE"
  run state_read_field "$STATE" "AI_BOOTSTRAP_TIER"
  [ "$status" -eq 1 ]
}

@test "state_read_field: returns the value when set" {
  echo "export AI_BOOTSTRAP_TIER='recommended'" >"$STATE"
  run state_read_field "$STATE" "AI_BOOTSTRAP_TIER"
  [ "$status" -eq 0 ]
  [ "$output" = "recommended" ]
}

@test "state_read_field: rejects unsafe state content before sourcing" {
  cat >"$STATE" <<EOF
#!/bin/bash
export AI_BOOTSTRAP_TIER='recommended'
touch '$SANDBOX/pwned'
EOF

  run state_read_field "$STATE" "AI_BOOTSTRAP_TIER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not read saved workspace settings"* ]]
  [ ! -e "$SANDBOX/pwned" ]
}

@test "state_now: honors AI_BOOTSTRAP_NOW_OVERRIDE" {
  AI_BOOTSTRAP_NOW_OVERRIDE="2099-12-31T23:59:59Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE
  run state_now
  [ "$status" -eq 0 ]
  [ "$output" = "2099-12-31T23:59:59Z" ]
}

@test "state_now: returns ISO 8601 UTC timestamp by default" {
  unset AI_BOOTSTRAP_NOW_OVERRIDE
  run state_now
  [ "$status" -eq 0 ]
  # YYYY-MM-DDTHH:MM:SSZ
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "lib/version.sh: AI_BOOTSTRAP_VERSION is set and non-empty" {
  # shellcheck source=../lib/version.sh
  source "${BOOTSTRAP_DIR}/lib/version.sh"
  [ -n "$AI_BOOTSTRAP_VERSION" ]
  # SemVer-ish: at minimum X.Y.Z optionally followed by -suffix.
  [[ "$AI_BOOTSTRAP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]
}

@test "state_write: state.sh and Brewfile co-exist (no overwrite)" {
  # The state writer must not touch the Brewfile (different file). Quick
  # sanity check: drop a Brewfile in the same dir, run state_write, make
  # sure it's still there untouched.
  AI_BOOTSTRAP_NOW_OVERRIDE="2026-05-01T00:00:00Z"
  export AI_BOOTSTRAP_NOW_OVERRIDE

  brewfile="$SANDBOX/Brewfile"
  echo 'cask "ghostty"' >"$brewfile"

  state_write "$STATE" "$SANDBOX/code" "recommended"
  [ -f "$brewfile" ]
  run cat "$brewfile"
  [ "$output" = 'cask "ghostty"' ]
}
