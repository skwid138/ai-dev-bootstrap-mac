#!/usr/bin/env bats
# Tests for `bootstrap.sh --refresh-paths` — the fast-path that re-runs
# modules/10-shell-config.sh only with a freshly-resolved Homebrew prefix.
#
# Strategy: run `bootstrap.sh --refresh-paths` as a subshell with mocked
# brew, sandboxed HOME, and a pre-staged state.sh. Assert:
#   - errors cleanly when state.sh is missing
#   - errors cleanly when AI_BOOTSTRAP_TIER='custom'
#   - re-emits the three-tier source lines into ~/.zshenv/.zprofile/.zshrc
#   - is idempotent (running twice produces identical files)
#   - --dry-run shows preview without writing
#
# NOTE: bootstrap.sh's preflight + Phase 0 are skipped on the
# refresh-paths fast-path (the fast-path block runs `exit` before
# preflight). So this test does NOT need to mock xcode-select / gum.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT

  # Mocks dir: brew (returns prefix).
  MOCKS_DIR="$BATS_TEST_TMPDIR/mocks"
  mkdir -p "$MOCKS_DIR"
  cat >"$MOCKS_DIR/brew" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --prefix) echo "${MOCK_BREW_PREFIX:-/opt/homebrew}" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$MOCKS_DIR/brew"
  export PATH="$MOCKS_DIR:$PATH"

  # Sandboxed HOME and brew prefix that exists on disk.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config/ai-bootstrap"
  export MOCK_BREW_PREFIX="$BATS_TEST_TMPDIR/brew"
  mkdir -p "$MOCK_BREW_PREFIX/bin" "$MOCK_BREW_PREFIX/sbin"
}

# Helper: write a state.sh with a given tier.
write_state() {
  local tier="$1"
  cat >"$HOME/.config/ai-bootstrap/state.sh" <<EOF
#!/bin/bash
export AI_BOOTSTRAP_WORKSPACE='$HOME/code'
export AI_BOOTSTRAP_TIER='$tier'
export AI_BOOTSTRAP_VERSION='0.0.0-test'
export AI_BOOTSTRAP_FIRST_RUN_AT='2026-05-02T00:00:00Z'
export AI_BOOTSTRAP_LAST_RUN_AT='2026-05-02T00:00:00Z'
EOF
}

# ── Error scenarios ───────────────────────────────────────────────────────

@test "--refresh-paths errors when state.sh is missing" {
  # No state.sh.
  run "$REPO_ROOT/bootstrap.sh" --refresh-paths

  [ "$status" -ne 0 ]
  [[ "$output" == *"state.sh"* ]]
  [[ "$output" == *"Run the full bootstrap"* ]]
}

@test "--refresh-paths errors when AI_BOOTSTRAP_TIER is custom" {
  write_state "custom"

  run "$REPO_ROOT/bootstrap.sh" --refresh-paths

  [ "$status" -ne 0 ]
  [[ "$output" == *"custom-tier"* ]]
  [[ "$output" == *"Re-run"* ]]
}

# ── Happy path: re-emits dotfile source lines ─────────────────────────────

@test "--refresh-paths recommended tier creates install dir" {
  write_state "recommended"

  run "$REPO_ROOT/bootstrap.sh" --refresh-paths
  [ "$status" -eq 0 ]
  [ -d "$HOME/.config/ai-bootstrap/shell" ]
  [ -d "$HOME/.config/ai-bootstrap/shell/env" ]
  [ -d "$HOME/.config/ai-bootstrap/shell/profile" ]
  [ -d "$HOME/.config/ai-bootstrap/shell/rc" ]
}

@test "--refresh-paths essential tier copies all three barrels" {
  write_state "essential"

  run "$REPO_ROOT/bootstrap.sh" --refresh-paths
  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/ai-bootstrap/shell/init_env.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/init_profile.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/init_rc.zsh" ]
}

@test "--refresh-paths bakes brew prefix into env/paths.zsh" {
  write_state "recommended"

  run "$REPO_ROOT/bootstrap.sh" --refresh-paths
  [ "$status" -eq 0 ]

  grep -qF "$MOCK_BREW_PREFIX/bin" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
  ! grep -qF "__BREW_PREFIX__" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
}

@test "--refresh-paths wires source lines into .zshenv/.zprofile/.zshrc" {
  write_state "recommended"

  run "$REPO_ROOT/bootstrap.sh" --refresh-paths
  [ "$status" -eq 0 ]

  [ -f "$HOME/.zshenv" ]
  [ -f "$HOME/.zprofile" ]
  [ -f "$HOME/.zshrc" ]

  grep -qF "ai-bootstrap/shell/init_env.zsh" "$HOME/.zshenv"
  grep -qF "ai-bootstrap/shell/init_profile.zsh" "$HOME/.zprofile"
  grep -qF "ai-bootstrap/shell/init_rc.zsh" "$HOME/.zshrc"
}

# ── Idempotency ───────────────────────────────────────────────────────────

@test "--refresh-paths is idempotent: two runs produce identical dotfiles" {
  write_state "recommended"

  "$REPO_ROOT/bootstrap.sh" --refresh-paths >/dev/null
  cp "$HOME/.zshenv" "$BATS_TEST_TMPDIR/zshenv-after-1"
  cp "$HOME/.zshrc" "$BATS_TEST_TMPDIR/zshrc-after-1"

  "$REPO_ROOT/bootstrap.sh" --refresh-paths >/dev/null

  diff -q "$HOME/.zshenv" "$BATS_TEST_TMPDIR/zshenv-after-1"
  diff -q "$HOME/.zshrc" "$BATS_TEST_TMPDIR/zshrc-after-1"
}

@test "--refresh-paths is idempotent: source line not duplicated on re-run" {
  write_state "essential"

  "$REPO_ROOT/bootstrap.sh" --refresh-paths >/dev/null
  "$REPO_ROOT/bootstrap.sh" --refresh-paths >/dev/null
  "$REPO_ROOT/bootstrap.sh" --refresh-paths >/dev/null

  count=$(grep -cF "ai-bootstrap/shell/init_env.zsh" "$HOME/.zshenv")
  [ "$count" = "1" ]
}

# ── Dry-run composition ───────────────────────────────────────────────────

@test "--refresh-paths --dry-run prints preview and exits 0 without writing" {
  write_state "recommended"

  run "$REPO_ROOT/bootstrap.sh" --refresh-paths --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Dry-run plan (refresh paths)"* ]]
  [[ "$output" == *"Tier:"* ]]
  [[ "$output" == *"recommended"* ]]
  [[ "$output" == *"Nothing has been changed yet"* ]]

  # No install dir or dotfiles created.
  [ ! -d "$HOME/.config/ai-bootstrap/shell" ]
  [ ! -f "$HOME/.zshenv" ]
}
