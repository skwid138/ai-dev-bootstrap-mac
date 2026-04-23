#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env
}

teardown() {
  teardown_test_env
}

@test "command_exists returns expected statuses" {
  run command_exists bash
  [ "$status" -eq 0 ]

  run command_exists nonexistent_command_xyz
  [ "$status" -eq 1 ]
}

@test "is_selected returns 0 when selected, 1 when not" {
  SELECTED_PACKAGES=(git jq)

  run is_selected git
  [ "$status" -eq 0 ]

  run is_selected ghostty
  [ "$status" -eq 1 ]
}

@test "ensure_dir creates a directory" {
  target_dir="${TMP_DIR}/nested/path"
  [ ! -d "$target_dir" ]

  run ensure_dir "$target_dir"
  [ "$status" -eq 0 ]
  [ -d "$target_dir" ]
}

@test "append_line_if_missing adds line once" {
  target_file="${TMP_DIR}/config/test.conf"
  line="export TEST_VALUE=1"

  run append_line_if_missing "$line" "$target_file"
  [ "$status" -eq 0 ]

  run append_line_if_missing "$line" "$target_file"
  [ "$status" -eq 0 ]

  run sh -c "grep -c '^${line}$' \"$target_file\""
  [ "$output" -eq 1 ]
}

@test "result tracking arrays start empty" {
  [ "${#RESULTS_INSTALLED[@]}" -eq 0 ]
  [ "${#RESULTS_SKIPPED[@]}" -eq 0 ]
  [ "${#RESULTS_FAILED[@]}" -eq 0 ]
}
