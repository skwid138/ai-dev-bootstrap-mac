#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"

  DF_AVAILABLE_KB="52428800"

  df() {
    [ "$#" -eq 2 ]
    [ "$1" = "-Pk" ]
    [ "$2" = "/" ]

    printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
    printf '/dev/disk1s1 100000000 50000000 %s 50%% /\n' "${DF_AVAILABLE_KB:-52428800}"
  }

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

@test "warn_disk_space warns when free space is below 10GB and returns 0" {
  DF_AVAILABLE_KB="5242880"

  run warn_disk_space

  [ "$status" -eq 0 ]
  [[ "$output" == *"You have about 5GB of free space"* ]]
}

@test "warn_disk_space is silent when free space is at least 10GB and returns 0" {
  DF_AVAILABLE_KB="52428800"

  run warn_disk_space

  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "run_preflight calls advisory disk-space warning directly and still returns 0" {
  DF_AVAILABLE_KB="52428800"

  run run_preflight

  [ "$status" -eq 0 ]
}

@test "warn_disk_space returns 0 under strict mode when df fails with non-numeric output" {
  run env BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" bash -euo pipefail -c '
    source "${BATS_TEST_DIRNAME}/test_helper.sh"

    df() {
      [ "$#" -eq 2 ]
      [ "$1" = "-Pk" ]
      [ "$2" = "/" ]
      printf "Filesystem 1024-blocks Used Available Capacity Mounted on\n"
      printf "/dev/disk1s1 100000000 50000000 not-a-number 50%% /\n"
      return 1
    }

    setup_test_env
    warn_disk_space
  '

  [ "$status" -eq 0 ]
}
