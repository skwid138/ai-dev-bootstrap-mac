#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env
}

teardown() {
  teardown_test_env
}

collect_tier() {
  local tier="$1"
  local results
  results=$(get_tier_packages "$tier")
  echo "$results"
}

@test "get_tier_packages essential includes key packages" {
  essential_packages=$(collect_tier essential)

  run sh -c "echo \"$essential_packages\" | grep -c '^xcode$'"
  [ "$output" -eq 1 ]
  run sh -c "echo \"$essential_packages\" | grep -c '^homebrew$'"
  [ "$output" -eq 1 ]
  # Phase 7.5: Homebrew bash 5.x is essential. macOS ships bash 3.2;
  # learners and AI-tutor sessions assume bash 5+. Bootstrap installs
  # it once, ships forever. Regression gate for the registry change.
  run sh -c "echo \"$essential_packages\" | grep -c '^bash$'"
  [ "$output" -eq 1 ]
  run sh -c "echo \"$essential_packages\" | grep -c '^git$'"
  [ "$output" -eq 1 ]
  run sh -c "echo \"$essential_packages\" | grep -c '^opencode$'"
  [ "$output" -eq 1 ]
}

@test "get_tier_packages recommended includes essential and recommended" {
  essential_packages=$(collect_tier essential)
  recommended_packages=$(collect_tier recommended)

  for pkg in $essential_packages; do
    run sh -c "echo \"$recommended_packages\" | grep -c '^${pkg}$'"
    [ "$output" -eq 1 ]
  done

  run sh -c "echo \"$recommended_packages\" | grep -c '^ghostty$'"
  [ "$output" -eq 1 ]
  run sh -c "echo \"$recommended_packages\" | grep -c '^fd$'"
  [ "$output" -eq 1 ]
}

@test "get_tier_packages complete includes all packages" {
  complete_packages=$(collect_tier complete)

  for pkg in "${PACKAGES[@]}"; do
    run sh -c "echo \"$complete_packages\" | grep -c '^${pkg}$'"
    [ "$output" -eq 1 ]
  done
}

@test "get_tier_description returns non-empty strings" {
  [ -n "$(get_tier_description essential)" ]
  [ -n "$(get_tier_description recommended)" ]
  [ -n "$(get_tier_description complete)" ]
}

@test "package registry has entries" {
  [ "${#PACKAGES[@]}" -gt 0 ]
}
