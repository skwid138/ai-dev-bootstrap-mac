#!/usr/bin/env bats
# Tests for lib/plan.sh — dry-run plan renderer.
#
# The renderer is pure: given tier + workspace + (optional) custom
# package CSV, it emits a plan to stdout. No side effects, so testing
# is just "run it, grep the output."

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../config/packages.sh
  source "${BOOTSTRAP_DIR}/config/packages.sh"
  # shellcheck source=../config/tiers.sh
  source "${BOOTSTRAP_DIR}/config/tiers.sh"
  # shellcheck source=../lib/plan.sh
  source "${BOOTSTRAP_DIR}/lib/plan.sh"
}

@test "plan_render: prints header" {
  run plan_render "essential" "/Users/test/code" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry-run plan"* ]]
}

@test "plan_render: shows tier and workspace" {
  run plan_render "recommended" "/Users/test/code" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Tier:      recommended"* ]]
  [[ "$output" == *"Workspace: /Users/test/code"* ]]
}

@test "plan_render: essential tier lists essential packages only" {
  run plan_render "essential" "/Users/test/code" ""
  [ "$status" -eq 0 ]
  # Essential includes git, opencode, ripgrep, and (Phase 7.5) bash.
  [[ "$output" == *"Git"* ]]
  [[ "$output" == *"OpenCode"* ]]
  [[ "$output" == *"ripgrep"* ]]
  # Phase 7.5: Homebrew bash 5.x ships at the essential tier so dry-run
  # output must surface "Bash" (display name) for the user before they
  # confirm the install.
  [[ "$output" == *"Bash"* ]]
  # Essential does NOT include ghostty (recommended) or ollama (complete).
  [[ "$output" != *"Ghostty"* ]]
  [[ "$output" != *"Ollama"* ]]
}

@test "plan_render: recommended tier includes essential + recommended" {
  run plan_render "recommended" "/Users/test/code" ""
  [ "$status" -eq 0 ]
  # Has essentials.
  [[ "$output" == *"Git"* ]]
  # Has recommendeds.
  [[ "$output" == *"Ghostty"* ]]
  [[ "$output" == *"tmux"* ]]
  # Does not have completes.
  [[ "$output" != *"Ollama"* ]]
  [[ "$output" != *"OrbStack"* ]]
}

@test "plan_render: complete tier includes everything" {
  run plan_render "complete" "/Users/test/code" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Git"* ]]
  [[ "$output" == *"Ghostty"* ]]
  [[ "$output" == *"Ollama"* ]]
  [[ "$output" == *"OrbStack"* ]]
}

@test "plan_render: groups by package type" {
  run plan_render "complete" "/Users/test/code" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Brew formulae:"* ]]
  [[ "$output" == *"Brew casks:"* ]]
  [[ "$output" == *"Mise runtimes:"* ]]
}

@test "plan_render: lists state.sh and Brewfile as always-written" {
  run plan_render "essential" "/Users/test/code" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"~/.config/ai-bootstrap/state.sh"* ]]
  [[ "$output" == *"~/.config/ai-bootstrap/Brewfile"* ]]
}

@test "plan_render: shows ghostty config + launcher only when ghostty selected" {
  # Recommended tier includes ghostty.
  run plan_render "recommended" "/Users/test/code" ""
  [[ "$output" == *"~/.config/ghostty/config"* ]]
  [[ "$output" == *"JustVibes.app"* ]]

  # Essential tier does not include ghostty.
  run plan_render "essential" "/Users/test/code" ""
  [[ "$output" != *"~/.config/ghostty/config"* ]]
  [[ "$output" != *"JustVibes.app"* ]]
}

@test "plan_render: shows opencode assets only when opencode selected" {
  # Essential has opencode.
  run plan_render "essential" "/Users/test/code" ""
  [[ "$output" == *"~/.config/opencode/"* ]]
  [[ "$output" == *"AGENTS.md"* ]]
}

@test "plan_render: shows three-tier shell init wiring for ALL tiers" {
  # Per zsh_init_plan.md §5.1, the three-tier shell init is foundational
  # and ships for every tier (Essential, Recommended, Complete, Custom).
  # The dry-run must mention all three target dotfiles AND the install dir
  # in every tier's plan.
  local tier
  for tier in essential recommended complete; do
    run plan_render "$tier" "/Users/test/code" ""
    [ "$status" -eq 0 ]
    [[ "$output" == *"~/.zshenv"* ]]
    [[ "$output" == *"~/.zprofile"* ]]
    [[ "$output" == *"~/.zshrc"* ]]
    [[ "$output" == *"~/.config/ai-bootstrap/shell/"* ]]
  done
}

@test "plan_render: shows zplug plugins file only when zplug selected" {
  # Recommended includes zplug.
  run plan_render "recommended" "/Users/test/code" ""
  [[ "$output" == *"rc/zsh_plugins.zsh"* ]]

  # Essential does not include zplug → no plugins file mentioned.
  run plan_render "essential" "/Users/test/code" ""
  [[ "$output" != *"rc/zsh_plugins.zsh"* ]]
}

@test "plan_render: shows mise tool_hooks when mise selected" {
  # Essential and Recommended both include mise → profile/tool_hooks.zsh listed.
  run plan_render "essential" "/Users/test/code" ""
  [[ "$output" == *"profile/tool_hooks.zsh"* ]]

  # Custom with no mise → not listed.
  run plan_render "custom" "/Users/test/code" "git"
  [[ "$output" != *"profile/tool_hooks.zsh"* ]]
}

@test "plan_render: shows rc/tool_hooks when mise OR direnv selected" {
  # Essential has mise → rc/tool_hooks.zsh listed.
  run plan_render "essential" "/Users/test/code" ""
  [[ "$output" == *"rc/tool_hooks.zsh"* ]]

  # Custom with only direnv (no mise) → still listed.
  run plan_render "custom" "/Users/test/code" "direnv"
  [[ "$output" == *"rc/tool_hooks.zsh"* ]]

  # Custom with neither → not listed.
  run plan_render "custom" "/Users/test/code" "git"
  [[ "$output" != *"rc/tool_hooks.zsh"* ]]
}

@test "plan_render: ends with 'Nothing has been changed yet' message" {
  # Critical contract for users — the dry-run is safe.
  run plan_render "essential" "/Users/test/code" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing has been changed yet"* ]]
}

@test "plan_render: custom tier accepts CSV package list" {
  run plan_render "custom" "/Users/test/code" "git,opencode,ghostty"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Git"* ]]
  [[ "$output" == *"OpenCode"* ]]
  [[ "$output" == *"Ghostty"* ]]
  # tmux NOT in CSV, should not appear.
  [[ "$output" != *"tmux"* ]]
}

@test "plan_has_key: true when needle is in haystack" {
  run plan_has_key "git" "git" "opencode" "ghostty"
  [ "$status" -eq 0 ]
}

@test "plan_has_key: false when needle is not in haystack" {
  run plan_has_key "ollama" "git" "opencode" "ghostty"
  [ "$status" -eq 1 ]
}
