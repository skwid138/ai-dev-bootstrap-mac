#!/usr/bin/env bats
# Tests for `bootstrap.sh --update` — the fast path that refreshes managed
# OpenCode assets/scripts/config, shell config, and the JustVibes launcher
# without re-running the full installer.

bats_require_minimum_version 1.5.0

# shellcheck source=helpers/mock_osacompile.bash
source "${BATS_TEST_DIRNAME}/helpers/mock_osacompile.bash"

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
  create_osacompile_mock "$MOCKS_DIR"
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

  export JUSTVIBES_DEST_DIR_OVERRIDE="$BATS_TEST_TMPDIR/Applications"
  mkdir -p "$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app/Contents"
  cat >"$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>dev.aibootstrap.justvibes</string>
</dict>
</plist>
EOF
}

seed_legacy_launcher() {
  local legacy_app="$JUSTVIBES_DEST_DIR_OVERRIDE/Just Vibes.app"
  mkdir -p "$legacy_app/Contents"
  cat >"$legacy_app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>dev.aibootstrap.justvibes</string>
</dict>
</plist>
EOF
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
  echo "keep-me-if-launcher-skipped" >"$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app/UNCHANGED"
  cat >"$HOME/.config/opencode/opencode.json" <<'EOF'
{"model":"openai/gpt-5.2"}
EOF
  cat >"$HOME/.config/opencode/tui.json" <<'EOF'
{
  "$schema": "old-schema",
  "theme": "catppuccin",
  "plugin": [
    ["./plugins/home-prompt.tsx", {"stale": true}],
    ["./plugins/justvibes-logo.tsx", {"stale": true}],
    ["./plugins/user-plugin.tsx", {"enabled": true}]
  ]
}
EOF
  echo "stale helper" >"$WORKSPACE/scripts/agent/opencode-deps-check.sh"

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -eq 0 ]
  [ -f "$HOME/.config/opencode/skill/tdd/SKILL.md" ]
  [ -f "$HOME/.config/opencode/command/help-me.md" ]
  [ -f "$WORKSPACE/scripts/agent/opencode-deps-check.sh" ]
  grep -qF "Usage: opencode-deps-check" "$WORKSPACE/scripts/agent/opencode-deps-check.sh"
  [ "$(jq -r '.model' "$HOME/.config/opencode/opencode.json")" = "openai/gpt-5.2" ]
  jq -e '.theme == "catppuccin"' "$HOME/.config/opencode/tui.json"
  jq -e '.plugin == [["@skwid138/opencode-tui@1.0.0", {}], ["./plugins/user-plugin.tsx", {"enabled": true}]]' "$HOME/.config/opencode/tui.json"
  tui_backups=("$HOME"/.config/opencode/tui.json.bak.*)
  [ "${#tui_backups[@]}" -eq 1 ]
  jq -e '.theme == "catppuccin"' "${tui_backups[0]}"
  grep -qF "$MOCK_BREW_PREFIX/bin" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
  [ -f "$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app/UNCHANGED" ]
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
  mkdir -p "$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app"
  echo "stale" >"$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app/STALE"

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -eq 0 ]
  [ -f "$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app/Contents/Info.plist" ]
  [ ! -f "$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app/STALE" ]
  # shellcheck source=../lib/launcher.sh
  source "$REPO_ROOT/lib/launcher.sh"
  [ "$(cat "$HOME/.config/ai-bootstrap/launcher-checksum")" = "$(launcher_checksum_compute)" ]
}

@test "--update removes legacy Just Vibes.app after rebuilding launcher" {
  write_state "essential"
  echo "old-checksum" >"$HOME/.config/ai-bootstrap/launcher-checksum"
  seed_legacy_launcher

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -eq 0 ]
  [ -d "$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app" ]
  [ ! -d "$JUSTVIBES_DEST_DIR_OVERRIDE/Just Vibes.app" ]
}

@test "--update removes legacy Just Vibes.app even when launcher rebuild is skipped" {
  write_state "recommended"
  save_current_launcher_checksum
  seed_legacy_launcher

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -eq 0 ]
  [ -d "$JUSTVIBES_DEST_DIR_OVERRIDE/JustVibes.app" ]
  [ ! -d "$JUSTVIBES_DEST_DIR_OVERRIDE/Just Vibes.app" ]
}

@test "--update writes AI_BOOTSTRAP_DIR to state" {
  write_state "essential"
  save_current_launcher_checksum

  run "$REPO_ROOT/bootstrap.sh" --update

  [ "$status" -eq 0 ]
  grep -qF "export AI_BOOTSTRAP_DIR='$REPO_ROOT'" "$HOME/.config/ai-bootstrap/state.sh"
}
