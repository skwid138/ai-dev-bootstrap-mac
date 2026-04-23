#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env

  HAS_GUM=false
}

teardown() {
  teardown_test_env
}

@test "ui_header outputs the provided text" {
  text="Hello Header"
  run ui_header "$text"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "$text"
}

@test "ui_success outputs the provided text" {
  text="Success Message"
  run ui_success "$text"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "$text"
}

@test "ui_error outputs the provided text" {
  text="Error Message"
  run ui_error "$text"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "$text"
}
