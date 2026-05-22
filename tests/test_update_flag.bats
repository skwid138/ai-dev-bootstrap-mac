#!/usr/bin/env bats
# Tests for `bootstrap.sh --update` — the fast path that refreshes managed
# OpenCode assets/scripts/config, shell config, and the Just Vibes launcher
# without re-running the full installer.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config/ai-bootstrap" "$HOME/.config/opencode"

  WORKSPACE="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$WORKSPACE/scripts/agent"
  export WORKSPACE

  MOCKS_DIR="$BATS_TEST_TMPDIR/mocks"
  mkdir -p "$MOCKS_DIR"
  cat >"$MOCKS_DIR/brew" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --prefix) echo "${MOCK_BREW_PREFIX:-/opt/homebrew}" ;;
  list) exit 0 ;;
  install) echo "brew install ${*:2}" >>"${MOCK_LOG:-/dev/null}" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$MOCKS_DIR/brew"

  export PATH="$MOCKS_DIR:$PATH"
  export MOCK_BREW_PREFIX="$BATS_TEST_TMPDIR/brew-prefix"
  export MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
  mkdir -p "$MOCK_BREW_PREFIX/bin" "$MOCK_BREW_PREFIX/sbin"
  : >"$MOCK_LOG"

  export JUST_VIBES_DEST_DIR_OVERRIDE="$BATS_TEST_TMPDIR/Applications"
  mkdir -p "$JUST_VIBES_DEST_DIR_OVERRIDE/Just Vibes.app"
}

write_state() {
  local tier="$1"
  cat >"$HOME/.config/ai-bootstrap/state.sh" <<EOF
#!/bin/bash
export AI_BOOTSTRAP_WORKSPACE='$WORKSPACE'
export AI_BOOTSTRAP_TIER='$tier'
export AI_BOOTSTRAP_VERSION='0.0.0-test'
export AI_BOOTSTRAP_FIRST_RUN_AT='2026-05-02T00:00:00Z'
export AI_BOOTSTRAP_LAST_RUN_AT='2026-05-02T00:00:00Z'
EOF
}

save_current_launcher_checksum() {
  # shellcheck source=../lib/launcher.sh
  source "$REPO_ROOT/lib/launcher.sh"
  launcher_checksum_compute >"$HOME/.config/ai-bootstrap/launcher-checksum"
}

@test "--update refreshes assets, scripts, config, shell config, and state without rebuilding unchanged launcher" {
  write_state "recommended"
  save_current_launcher_checksum
  echo "keep-me-if-launcher-skipped" >"$JUST_VIBES_DEST_DIR_OVERRIDE/Just Vibes.app/UNCHANGED"
  cat >"$HOME/.config/opencode/opencode.json" <<'EOF'
{"model":"openai/gpt-5.2"}
EOF
  echo "stale helper" >"$WORKSPACE/scripts/agent/opencode-deps-check.sh"

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/opencode/skill/tdd/SKILL.md" ]
  [ -f "$HOME/.config/opencode/command/help-me.md" ]
  [ -f "$WORKSPACE/scripts/agent/opencode-deps-check.sh" ]
  grep -qF "Usage: opencode-deps-check" "$WORKSPACE/scripts/agent/opencode-deps-check.sh"
  [ "$(jq -r '.model' "$HOME/.config/opencode/opencode.json")" = "openai/gpt-5.2" ]
  grep -qF "$MOCK_BREW_PREFIX/bin" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
  [ -f "$JUST_VIBES_DEST_DIR_OVERRIDE/Just Vibes.app/UNCHANGED" ]
  grep -qF "export AI_BOOTSTRAP_DIR='$REPO_ROOT'" "$HOME/.config/ai-bootstrap/state.sh"
}

@test "--update errors clearly when state file is missing" {
  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -ne 0 ]
  [[ "$output" == *"state.sh"* ]]
  [[ "$output" == *"Run the full bootstrap"* ]]
}

@test "--update rejects custom tier and directs user to full installer" {
  write_state "custom"

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -ne 0 ]
  [[ "$output" == *"custom-tier"* ]]
  [[ "$output" == *"full installer"* ]]
}

@test "--update errors clearly when jq is missing" {
  write_state "recommended"

  hermetic_bin="$BATS_TEST_TMPDIR/no-jq-bin"
  mkdir -p "$hermetic_bin"
  ln -s /usr/bin/dirname "$hermetic_bin/dirname"
  ln -s /bin/pwd "$hermetic_bin/pwd"

  PATH="$hermetic_bin" run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -ne 0 ]
  [[ "$output" == *"jq"* ]]
  [[ "$output" == *"required"* ]]
}

@test "--update rebuilds launcher when checksum mismatches" {
  write_state "essential"
  echo "old-checksum" >"$HOME/.config/ai-bootstrap/launcher-checksum"
  mkdir -p "$JUST_VIBES_DEST_DIR_OVERRIDE/Just Vibes.app"
  echo "stale" >"$JUST_VIBES_DEST_DIR_OVERRIDE/Just Vibes.app/STALE"

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -eq 0 ]
  [ -f "$JUST_VIBES_DEST_DIR_OVERRIDE/Just Vibes.app/Contents/Info.plist" ]
  [ ! -f "$JUST_VIBES_DEST_DIR_OVERRIDE/Just Vibes.app/STALE" ]
  # shellcheck source=../lib/launcher.sh
  source "$REPO_ROOT/lib/launcher.sh"
  [ "$(cat "$HOME/.config/ai-bootstrap/launcher-checksum")" = "$(launcher_checksum_compute)" ]
}

@test "--update writes AI_BOOTSTRAP_DIR to state" {
  write_state "essential"
  save_current_launcher_checksum

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -eq 0 ]
  grep -qF "export AI_BOOTSTRAP_DIR='$REPO_ROOT'" "$HOME/.config/ai-bootstrap/state.sh"
}
