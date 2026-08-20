#!/usr/bin/env bats
# Tests for lib/state_source_validation.sh.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/state_source_validation.sh
  # shellcheck disable=SC1091
  source "${BOOTSTRAP_DIR}/lib/state_source_validation.sh"

  SANDBOX="$(mktemp -d)"
  STATE="$SANDBOX/state.sh"
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

@test "state_validate_sourceable_file: returns 1 when file missing" {
  run state_validate_sourceable_file "$SANDBOX/no-such-file.sh"
  [ "$status" -eq 1 ]
}

@test "state_validate_sourceable_file: accepts bootstrap state export lines" {
  cat >"$STATE" <<EOF
#!/bin/bash
# ai-bootstrap state

export AI_BOOTSTRAP_WORKSPACE='$SANDBOX/code'
export AI_BOOTSTRAP_TIER='recommended'
export AI_BOOTSTRAP_VERSION='2.0.0'
export AI_BOOTSTRAP_FIRST_RUN_AT='2026-05-01T00:00:00Z'
export AI_BOOTSTRAP_LAST_RUN_AT='2026-05-02T00:00:00Z'
EOF

  run state_validate_sourceable_file "$STATE"
  [ "$status" -eq 0 ]
}

@test "state_validate_sourceable_file: rejects unsafe executable content" {
  cat >"$STATE" <<EOF
#!/bin/bash
export AI_BOOTSTRAP_TIER='recommended'
touch '$SANDBOX/pwned'
EOF

  run state_validate_sourceable_file "$STATE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not read saved workspace settings"* ]]
  [ ! -e "$SANDBOX/pwned" ]
}

@test "state_validate_sourceable_file: rejects unquoted exports" {
  echo "export AI_BOOTSTRAP_TIER=recommended" >"$STATE"

  run state_validate_sourceable_file "$STATE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not read saved workspace settings"* ]]
}
