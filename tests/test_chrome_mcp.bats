#!/usr/bin/env bats
# Unit tests for the Chrome DevTools MCP helper.

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env

  PORT="9222"
  USER_DATA_DIR="/tmp/chrome-devtools-mcp-auth"
  PS_FIXTURE=""

  ps() {
    printf '%s\n' "${PS_FIXTURE:-}"
  }

  curl() {
    return 1
  }

  open() {
    return 0
  }

  sleep() {
    :
  }

  # shellcheck source=scripts/agent/chrome_mcp.sh
  source "${BOOTSTRAP_DIR}/scripts/agent/chrome_mcp.sh"
}

teardown() {
  teardown_test_env
}

@test "matching_instance_pids: empty process list emits no output" {
  PS_FIXTURE=""

  run matching_instance_pids

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "matching_instance_pids: single matching process emits one pid" {
  PS_FIXTURE="123 /Applications/Google Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-devtools-mcp-auth"

  run matching_instance_pids

  [ "$status" -eq 0 ]
  [ "$output" = "123" ]
}

@test "matching_instance_pids: single-flag processes emit no output" {
  PS_FIXTURE="123 /Applications/Google Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/other-chrome-profile
456 /Applications/Google Chrome --user-data-dir=/tmp/chrome-devtools-mcp-auth"

  run matching_instance_pids

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "matching_instance_pids: multiple matching processes emit all pids" {
  PS_FIXTURE="123 /Applications/Google Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-devtools-mcp-auth
456 /Applications/Google Chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-devtools-mcp-auth"

  run matching_instance_pids

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "123" ]
  [ "${lines[1]}" = "456" ]
}

@test "matching_instance_pids: non-numeric first token is filtered out" {
  PS_FIXTURE="not-a-pid --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-devtools-mcp-auth"

  run matching_instance_pids

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
