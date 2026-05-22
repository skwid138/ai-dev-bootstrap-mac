#!/usr/bin/env bats
# Tests for scripts/agent/bootstrap-update-check.sh.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/agent/bootstrap-update-check.sh"
  export REPO_ROOT SCRIPT

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config/ai-bootstrap"
}

write_state_dir() {
  local dir="$1"
  cat >"$HOME/.config/ai-bootstrap/state.sh" <<EOF
#!/bin/bash
export AI_BOOTSTRAP_WORKSPACE='$HOME/code'
export AI_BOOTSTRAP_TIER='recommended'
export AI_BOOTSTRAP_VERSION='0.0.0-test'
export AI_BOOTSTRAP_FIRST_RUN_AT='2026-05-02T00:00:00Z'
export AI_BOOTSTRAP_LAST_RUN_AT='2026-05-02T00:00:00Z'
export AI_BOOTSTRAP_DIR='$dir'
EOF
}

git_commit() {
  local repo="$1"
  local message="$2"
  git -C "$repo" -c user.name="Test User" -c user.email="test@example.com" add .
  git -C "$repo" -c user.name="Test User" -c user.email="test@example.com" commit -m "$message" >/dev/null
}

make_repo_pair() {
  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  SEED="$BATS_TEST_TMPDIR/seed"
  CLONE="$BATS_TEST_TMPDIR/bootstrap"
  export ORIGIN SEED CLONE

  git init --bare --initial-branch=main "$ORIGIN" >/dev/null
  git clone "$ORIGIN" "$SEED" >/dev/null 2>&1
  mkdir -p "$SEED/opencode/skill/base"
  echo base >"$SEED/opencode/skill/base/SKILL.md"
  git_commit "$SEED" "base"
  git -C "$SEED" push origin main >/dev/null 2>&1
  git clone "$ORIGIN" "$CLONE" >/dev/null 2>&1
  write_state_dir "$CLONE"
}

push_change() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$SEED/$path")"
  printf '%s\n' "$content" >"$SEED/$path"
  git_commit "$SEED" "change $path"
  git -C "$SEED" push origin main >/dev/null 2>&1
}

@test "bootstrap-update-check outputs valid JSON with required structure" {
  make_repo_pair
  push_change "scripts/agent/new-helper.sh" "helper"

  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  echo "$output" | jq empty
  [ "$(echo "$output" | jq -r 'has("up_to_date")')" = "true" ]
  [ "$(echo "$output" | jq -r 'has("commits_behind")')" = "true" ]
  [ "$(echo "$output" | jq -r 'has("detached_head")')" = "true" ]
  [ "$(echo "$output" | jq -r 'has("categories")')" = "true" ]
  [ "$(echo "$output" | jq -r '.bootstrap_dir')" = "$CLONE" ]
}

@test "bootstrap-update-check categorizes skill, command, script, config, launcher, and other changes" {
  make_repo_pair
  push_change "opencode/skill/check-updates/SKILL.md" "skill"
  push_change "opencode/command/check-updates.md" "command"
  push_change "scripts/agent/bootstrap-update-check.sh" "script"
  push_change "lib/update.sh" "config"
  push_change "launcher/launch-helper.sh" "launcher"
  push_change "README.md" "other"

  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.categories.skills')" = "1" ]
  [ "$(echo "$output" | jq -r '.categories.commands')" = "1" ]
  [ "$(echo "$output" | jq -r '.categories.scripts')" = "1" ]
  [ "$(echo "$output" | jq -r '.categories.config')" = "1" ]
  [ "$(echo "$output" | jq -r '.categories.launcher')" = "1" ]
  [ "$(echo "$output" | jq -r '.categories.other')" = "1" ]
}

@test "bootstrap-update-check falls back to HOME/code/ai-dev-bootstrap-mac when state is missing" {
  make_repo_pair
  rm -f "$HOME/.config/ai-bootstrap/state.sh"
  mkdir -p "$HOME/code"
  mv "$CLONE" "$HOME/code/ai-dev-bootstrap-mac"
  CLONE="$HOME/code/ai-dev-bootstrap-mac"

  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.bootstrap_dir')" = "$HOME/code/ai-dev-bootstrap-mac" ]
}

@test "bootstrap-update-check returns error JSON outside a git repo" {
  mkdir -p "$BATS_TEST_TMPDIR/not-git"
  write_state_dir "$BATS_TEST_TMPDIR/not-git"

  run "$SCRIPT" --json
  [ "$status" -ne 0 ]
  echo "$output" | jq empty
  [[ "$(echo "$output" | jq -r '.error')" == *"not a git repo"* ]]
}

@test "bootstrap-update-check reports up_to_date true when no commits are behind" {
  make_repo_pair

  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.up_to_date')" = "true" ]
  [ "$(echo "$output" | jq -r '.commits_behind')" = "0" ]
}

@test "bootstrap-update-check compares detached HEAD to origin/main" {
  make_repo_pair
  git -C "$CLONE" checkout --detach HEAD >/dev/null 2>&1
  push_change "opencode/command/new-command.md" "command"

  run "$SCRIPT" --json
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | jq -r '.detached_head')" = "true" ]
  [ "$(echo "$output" | jq -r '.commits_behind')" = "1" ]
  [ "$(echo "$output" | jq -r '.categories.commands')" = "1" ]
}
