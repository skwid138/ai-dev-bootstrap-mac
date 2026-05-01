#!/usr/bin/env bats
# Integration tests for modules/09-opencode.sh.

bats_require_minimum_version 1.5.0

#
# Strategy:
#   - Create a sandboxed $HOME so all writes (~/.config/opencode/...)
#     land in a temp dir we can assert against.
#   - Prepend tests/mocks/ to PATH so brew/gh/opencode invocations are
#     captured (and never actually shell out to the real CLIs).
#   - Set OPENCODE_BOOTSTRAP_TEST=1 to bypass ui_choose/ui_confirm
#     and let env vars drive the menu choice.
#   - Source bootstrap.sh's library deps the same way the real flow
#     does (lib/ui.sh, lib/common.sh) so log_*/install_brew_formula
#     are defined.
#
# Each test is a full module run against a fresh sandbox. We assert on:
#   - $MOCK_LOG (exact CLI command sequence)
#   - $HOME/.config/opencode/{opencode.json,AGENTS.md,agents/,...}
#   - Module exit status

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR

  SANDBOX="$(mktemp -d)"
  export HOME="$SANDBOX"
  export MOCK_LOG="$SANDBOX/mock.log"
  : >"$MOCK_LOG"

  # Prepend mocks dir so our stubs win over any real CLIs on PATH.
  export PATH="${BOOTSTRAP_DIR}/tests/mocks:$PATH"

  # Non-interactive mode for the module.
  export OPENCODE_BOOTSTRAP_TEST=1

  # Default mock state: gh not authed, brew has nothing pre-installed.
  unset MOCK_GH_AUTHED
  unset OPENCODE_TEST_USE_COPILOT
  unset OPENCODE_TEST_MENU_SELECTION
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# Run the module in a clean subshell with all the deps the real
# bootstrap.sh would have loaded. Captures stdout+stderr.
run_module() {
  run bash -c "
    set +e
    export BOOTSTRAP_DIR='$BOOTSTRAP_DIR'
    source '$BOOTSTRAP_DIR/lib/ui.sh'
    source '$BOOTSTRAP_DIR/lib/checks.sh'
    source '$BOOTSTRAP_DIR/config/packages.sh' 2>/dev/null || true
    source '$BOOTSTRAP_DIR/config/tiers.sh' 2>/dev/null || true
    source '$BOOTSTRAP_DIR/lib/common.sh'
    source '$BOOTSTRAP_DIR/modules/09-opencode.sh'
  "
}

# ── Path 1: gh authed + user agrees -> Copilot ───────────────────────────────
@test "module: gh authed + use_copilot=yes -> copilot login + sonnet-4.5 model" {
  export MOCK_GH_AUTHED=1
  export OPENCODE_TEST_USE_COPILOT=yes

  run_module
  [ "$status" -eq 0 ]

  # Copilot login was driven non-interactively.
  grep -q "opencode auth login --provider github-copilot --method oauth" "$MOCK_LOG"

  # opencode.json has the Copilot model.
  [ -f "$HOME/.config/opencode/opencode.json" ]
  run jq -r '.model' "$HOME/.config/opencode/opencode.json"
  [ "$output" = "github-copilot/claude-sonnet-4.5" ]

  # Curated assets landed (note: dirs are 'instruction' singular and
  # 'plugins' plural per the source tree).
  [ -d "$HOME/.config/opencode/agent" ]
  [ -d "$HOME/.config/opencode/skill" ]
  [ -d "$HOME/.config/opencode/command" ]
  [ -d "$HOME/.config/opencode/instruction" ]
  [ -d "$HOME/.config/opencode/plugins" ]
  [ -f "$HOME/.config/opencode/AGENTS.md" ]

  # Brew install was attempted. (The module skips 'brew tap' when our
  # mock's bare 'brew tap' already lists anomalyco/tap, which is the
  # correct behavior — assert on the install instead.)
  grep -q "brew install" "$MOCK_LOG"
  grep -q "anomalyco/tap/opencode" "$MOCK_LOG"
}

# ── Path 2: gh authed but user declines -> menu -> anthropic ─────────────────
@test "module: gh authed + use_copilot=no + menu=anthropic -> anthropic login" {
  export MOCK_GH_AUTHED=1
  export OPENCODE_TEST_USE_COPILOT=no
  export OPENCODE_TEST_MENU_SELECTION=anthropic

  run_module
  [ "$status" -eq 0 ]

  # Anthropic login (NOT copilot) was driven.
  grep -q "opencode auth login --provider anthropic" "$MOCK_LOG"
  run ! grep -q "opencode auth login --provider github-copilot" "$MOCK_LOG"

  run jq -r '.model' "$HOME/.config/opencode/opencode.json"
  [ "$output" = "anthropic/claude-sonnet-4.5" ]
}

# ── Path 3: gh not authed -> menu -> openai ──────────────────────────────────
@test "module: gh not authed + menu=openai -> openai login + gpt-5.2 model" {
  export OPENCODE_TEST_MENU_SELECTION=openai

  run_module
  [ "$status" -eq 0 ]

  grep -q "opencode auth login --provider openai" "$MOCK_LOG"
  run ! grep -q "opencode auth login --provider github-copilot" "$MOCK_LOG"

  run jq -r '.model' "$HOME/.config/opencode/opencode.json"
  [ "$output" = "openai/gpt-5.2" ]
}

# ── Path 4: gh not authed -> menu -> gemini ──────────────────────────────────
@test "module: gh not authed + menu=gemini -> google login + flash model" {
  export OPENCODE_TEST_MENU_SELECTION=gemini

  run_module
  [ "$status" -eq 0 ]

  grep -q "opencode auth login --provider google" "$MOCK_LOG"

  run jq -r '.model' "$HOME/.config/opencode/opencode.json"
  [ "$output" = "google/gemini-2.5-flash" ]
}

# ── Path 5: gh not authed -> menu -> zen ─────────────────────────────────────
@test "module: gh not authed + menu=zen -> opencode-zen login + sonnet-4.6 model" {
  export OPENCODE_TEST_MENU_SELECTION=zen

  run_module
  [ "$status" -eq 0 ]

  grep -q "opencode auth login --provider opencode-zen" "$MOCK_LOG"

  run jq -r '.model' "$HOME/.config/opencode/opencode.json"
  [ "$output" = "opencode/claude-sonnet-4.6" ]
}

# ── Path 6: skip path -> no auth login + no model field in config ────────────
@test "module: skip path -> opencode.json has no model + no auth login called" {
  export OPENCODE_TEST_MENU_SELECTION=skip

  run_module
  [ "$status" -eq 0 ]
  module_output="$output"

  # No auth login subcommand should have been invoked at all.
  run ! grep -q "opencode auth login" "$MOCK_LOG"

  # Config exists but has no model field (so opencode falls back to default).
  [ -f "$HOME/.config/opencode/opencode.json" ]
  module_has_model=$(jq 'has("model")' "$HOME/.config/opencode/opencode.json")
  [ "$module_has_model" = "false" ]

  # Module's post-install help should mention /connect for the user.
  [[ "$module_output" == *"/connect"* ]]
}

# ── Idempotency: rerun preserves user-edited AGENTS.md ───────────────────────
@test "module: rerun preserves user-edited AGENTS.md, refreshes other assets" {
  export MOCK_GH_AUTHED=1
  export OPENCODE_TEST_USE_COPILOT=yes

  # First run.
  run_module
  [ "$status" -eq 0 ]

  # User edits AGENTS.md and adds a custom skill.
  echo "# my custom rules" >>"$HOME/.config/opencode/AGENTS.md"
  user_agents_md_hash=$(md5 -q "$HOME/.config/opencode/AGENTS.md")
  mkdir -p "$HOME/.config/opencode/skill/my-custom-skill"
  echo "custom" >"$HOME/.config/opencode/skill/my-custom-skill/SKILL.md"

  # User damages a curated asset to verify it gets restored.
  bug_hunter="$HOME/.config/opencode/skill/bug-hunter/SKILL.md"
  echo "DAMAGED" >"$bug_hunter"

  # Reset mock log for the second run.
  : >"$MOCK_LOG"

  # Second run.
  run_module
  [ "$status" -eq 0 ]

  # AGENTS.md preserved bit-for-bit.
  rerun_hash=$(md5 -q "$HOME/.config/opencode/AGENTS.md")
  [ "$user_agents_md_hash" = "$rerun_hash" ]

  # User's custom skill survived (we copy curated dirs but don't nuke
  # untouched user files inside them — verify).
  [ -f "$HOME/.config/opencode/skill/my-custom-skill/SKILL.md" ]

  # Damaged curated asset got restored.
  run ! grep -q "DAMAGED" "$bug_hunter"
  grep -q "bug-hunter" "$bug_hunter"
}
