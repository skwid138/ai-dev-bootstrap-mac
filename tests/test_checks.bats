#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "check_not_root passes for normal user" {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    skip "Running as root; check_not_root should fail"
  fi

  run check_not_root
  [ "$status" -eq 0 ]
}

@test "check_architecture exports ARCH" {
  check_architecture
  [ "$ARCH" = "arm64" ] || [ "$ARCH" = "x86_64" ]
}

@test "check_macos passes on current system" {
  run check_macos
  [ "$status" -eq 0 ]
}

@test "check_disk_space does not fail" {
  run check_disk_space
  [ "$status" -eq 0 ]
}
