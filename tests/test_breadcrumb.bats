#!/usr/bin/env bats
# Tests for add-on module breadcrumb helpers.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT

  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg-config"
  mkdir -p "$HOME" "$XDG_CONFIG_HOME"
}

@test "breadcrumb_write creates a pending breadcrumb that breadcrumb_clear removes" {
  source "$REPO_ROOT/lib/breadcrumb.sh"

  run breadcrumb_exists tailscale
  [ "$status" -eq 1 ]

  run breadcrumb_write tailscale
  [ "$status" -eq 0 ]
  [ -f "$XDG_CONFIG_HOME/ai-bootstrap/breadcrumbs/tailscale" ]

  run breadcrumb_exists tailscale
  [ "$status" -eq 0 ]

  run breadcrumb_clear tailscale
  [ "$status" -eq 0 ]

  run breadcrumb_exists tailscale
  [ "$status" -eq 1 ]
}

@test "breadcrumb_pending lists pending add-on names and returns 1 when none exist" {
  source "$REPO_ROOT/lib/breadcrumb.sh"

  run breadcrumb_pending
  [ "$status" -eq 1 ]
  [ "$output" = "" ]

  breadcrumb_write tailscale
  breadcrumb_write another-addon

  run breadcrumb_pending
  [ "$status" -eq 0 ]
  [[ "$output" == *"tailscale"* ]]
  [[ "$output" == *"another-addon"* ]]
}
