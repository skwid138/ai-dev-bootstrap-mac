#!/usr/bin/env bats
# Tests for lib/summary.sh — final install summary renderer.
#
# The renderer is intentionally plain stdout (no gum dependency) so it works
# in non-interactive runs and is easy to assert against.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/summary.sh
  source "${BOOTSTRAP_DIR}/lib/summary.sh"
}

@test "summary_print: outputs generated workspace tier brewfile and launcher" {
  run summary_print \
    "/Users/test/code" \
    "recommended" \
    "/Users/test/.config/ai-bootstrap/Brewfile" \
    "/Applications/Just Vibes.app"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installation Summary"* ]]
  [[ "$output" == *"Workspace: /Users/test/code"* ]]
  [[ "$output" == *"Tier:      recommended"* ]]
  [[ "$output" == *"Brewfile:  /Users/test/.config/ai-bootstrap/Brewfile"* ]]
  [[ "$output" == *"Launcher:  /Applications/Just Vibes.app"* ]]
  [[ "$output" == *"Next steps:"* ]]
  [[ "$output" == *"Try running: opencode"* ]]
}

@test "summary_print: empty params show not generated" {
  run summary_print "" "" "" ""

  [ "$status" -eq 0 ]
  [[ "$output" == *"Workspace: (not generated)"* ]]
  [[ "$output" == *"Tier:      (not generated)"* ]]
  [[ "$output" == *"Brewfile:  (not generated)"* ]]
  [[ "$output" == *"Launcher:  (not generated)"* ]]
}

@test "summary_print_failure: lists failures without success celebration" {
  run summary_print_failure \
    "/Users/test/code" \
    "recommended" \
    "/Users/test/.config/ai-bootstrap/Brewfile" \
    "" \
    "Git and GitHub CLI" \
    "Shell configuration"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installation finished with issues"* ]]
  [[ "$output" == *"- Git and GitHub CLI"* ]]
  [[ "$output" == *"- Shell configuration"* ]]
  [[ "$output" != *"Start building something"* ]]
}
