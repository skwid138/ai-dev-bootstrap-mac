#!/usr/bin/env bats
#
# Unit tests for lib/opencode.sh helpers.
#
# These are filesystem-level tests using a per-test sandbox under
# $BATS_TEST_TMPDIR; they don't touch ~/.config/opencode and they don't
# require opencode/jq/gh to be running interactively (they DO require
# jq to be on PATH for the render_config tests, which is fine — jq is
# an Essential bootstrap package and is already installed in CI).

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env

  # shellcheck source=lib/opencode.sh
  source "${BOOTSTRAP_DIR}/lib/opencode.sh"

  SANDBOX="${BATS_TEST_TMPDIR}/sandbox"
  mkdir -p "$SANDBOX"
  export SANDBOX
}

teardown() {
  teardown_test_env
}

# ── opencode_deploy_assets ───────────────────────────────────────────────────

@test "opencode_deploy_assets: copies expected subtrees" {
  src="$SANDBOX/src"
  dest="$SANDBOX/dest"
  mkdir -p "$src"/{agent,skill/foo,command,instruction}
  echo "agent" >"$src/agent/x.md"
  echo "skill" >"$src/skill/foo/SKILL.md"
  echo "cmd" >"$src/command/c.md"
  echo "ins" >"$src/instruction/i.md"

  run opencode_deploy_assets "$src" "$dest"
  [ "$status" -eq 0 ]

  [ -f "$dest/agent/x.md" ]
  [ -f "$dest/skill/foo/SKILL.md" ]
  [ -f "$dest/command/c.md" ]
  [ -f "$dest/instruction/i.md" ]
}

@test "opencode_deploy_assets: skips missing subdirs gracefully" {
  src="$SANDBOX/src"
  dest="$SANDBOX/dest"
  mkdir -p "$src/agent"
  echo "agent" >"$src/agent/x.md"
  # Note: no skill/, command/, instruction/ — should be fine.

  run opencode_deploy_assets "$src" "$dest"
  [ "$status" -eq 0 ]
  [ -f "$dest/agent/x.md" ]
  [ ! -d "$dest/skill" ]
}

@test "opencode_deploy_assets: overwrites existing destination files" {
  src="$SANDBOX/src"
  dest="$SANDBOX/dest"
  mkdir -p "$src/agent" "$dest/agent"
  echo "new" >"$src/agent/x.md"
  echo "old" >"$dest/agent/x.md"

  run opencode_deploy_assets "$src" "$dest"
  [ "$status" -eq 0 ]
  run cat "$dest/agent/x.md"
  [ "$output" = "new" ]
}

@test "opencode_deploy_assets: leaves user-added files untouched" {
  # User has put a custom agent in agent/. We must not delete it.
  src="$SANDBOX/src"
  dest="$SANDBOX/dest"
  mkdir -p "$src/agent" "$dest/agent"
  echo "ours" >"$src/agent/gandalf.md"
  echo "user" >"$dest/agent/my-custom-agent.md"

  run opencode_deploy_assets "$src" "$dest"
  [ "$status" -eq 0 ]
  [ -f "$dest/agent/gandalf.md" ]
  [ -f "$dest/agent/my-custom-agent.md" ]
}

@test "opencode_deploy_assets: errors when source dir missing" {
  run opencode_deploy_assets "$SANDBOX/nope" "$SANDBOX/dest"
  [ "$status" -ne 0 ]
}

# ── opencode_deploy_agents_md ────────────────────────────────────────────────

@test "opencode_deploy_agents_md: installs when destination missing" {
  src="$SANDBOX/AGENTS.md"
  dest="$SANDBOX/dest/AGENTS.md"
  echo "rules" >"$src"

  run opencode_deploy_agents_md "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  run cat "$dest"
  [ "$output" = "rules" ]
}

@test "opencode_deploy_agents_md: skips when destination exists (overwrite-protect)" {
  src="$SANDBOX/AGENTS.md"
  dest="$SANDBOX/dest/AGENTS.md"
  echo "new" >"$src"
  mkdir -p "$(dirname "$dest")"
  echo "user" >"$dest"

  run opencode_deploy_agents_md "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "skipped" ]
  run cat "$dest"
  [ "$output" = "user" ]
}

@test "opencode_deploy_agents_md: errors when source missing" {
  run opencode_deploy_agents_md "$SANDBOX/nope.md" "$SANDBOX/dest/AGENTS.md"
  [ "$status" -ne 0 ]
}

# ── opencode_deploy_dcp_config ───────────────────────────────────────────────

@test "opencode_deploy_dcp_config: installs when destination missing" {
  src="$SANDBOX/dcp.jsonc"
  dest="$SANDBOX/dest/dcp.jsonc"
  echo '{ "compress": { "maxContextLimit": "65%" } }' >"$src"

  run opencode_deploy_dcp_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  [ -f "$dest" ]
  run grep -q '"maxContextLimit": "65%"' "$dest"
  [ "$status" -eq 0 ]
}

@test "opencode_deploy_dcp_config: skips when destination exists (overwrite-protect)" {
  src="$SANDBOX/dcp.jsonc"
  dest="$SANDBOX/dest/dcp.jsonc"
  echo '{ "new": true }' >"$src"
  mkdir -p "$(dirname "$dest")"
  echo '{ "user_tweaked": true }' >"$dest"

  run opencode_deploy_dcp_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "skipped" ]
  run cat "$dest"
  [ "$output" = '{ "user_tweaked": true }' ]
}

@test "opencode_deploy_dcp_config: errors when source missing" {
  run opencode_deploy_dcp_config "$SANDBOX/nope.jsonc" "$SANDBOX/dest/dcp.jsonc"
  [ "$status" -ne 0 ]
}

# ── opencode_render_config ───────────────────────────────────────────────────

@test "opencode_render_config: sets model when provided" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.json.template"
  dest="$SANDBOX/opencode.json"

  run opencode_render_config "$src" "$dest" "github-copilot/claude-sonnet-4.5"
  [ "$status" -eq 0 ]

  run jq -r '.model' "$dest"
  [ "$output" = "github-copilot/claude-sonnet-4.5" ]
}

@test "opencode_render_config: deletes model when blank (skip path)" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.json.template"
  dest="$SANDBOX/opencode.json"

  run opencode_render_config "$src" "$dest" ""
  [ "$status" -eq 0 ]

  # Key must be ABSENT, not just empty — opencode reads "absent" as
  # "use my default" but reads "" as "user explicitly chose empty",
  # which would fail.
  run jq 'has("model")' "$dest"
  [ "$output" = "false" ]
}

@test "opencode_render_config: deletes model when 3rd arg omitted entirely" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.json.template"
  dest="$SANDBOX/opencode.json"

  run opencode_render_config "$src" "$dest"
  [ "$status" -eq 0 ]
  run jq 'has("model")' "$dest"
  [ "$output" = "false" ]
}

@test "opencode_render_config: preserves the rest of the template" {
  # Spot-check that we didn't accidentally strip MCPs or the plugin
  # array while doing the model field surgery.
  src="${BOOTSTRAP_DIR}/opencode/opencode.json.template"
  dest="$SANDBOX/opencode.json"

  run opencode_render_config "$src" "$dest" "x/y"
  [ "$status" -eq 0 ]

  run jq -r '.mcp | keys | sort | join(",")' "$dest"
  [ "$output" = "chrome-devtools,context7,exa" ]

  run jq -r '.plugin | length' "$dest"
  [ "$output" = "1" ]
}

@test "opencode_render_config: errors when template missing" {
  run opencode_render_config "$SANDBOX/nope.json" "$SANDBOX/out.json" ""
  [ "$status" -ne 0 ]
}

@test "opencode_render_config: overwrites existing config" {
  # We've documented that opencode.json is bootstrap-managed. Verify it
  # actually overwrites — silent skipping would be much worse than
  # known-overwrite.
  src="${BOOTSTRAP_DIR}/opencode/opencode.json.template"
  dest="$SANDBOX/opencode.json"
  echo '{"old":true}' >"$dest"

  run opencode_render_config "$src" "$dest" "x/y"
  [ "$status" -eq 0 ]
  run jq 'has("old")' "$dest"
  [ "$output" = "false" ]
  run jq -r '.model' "$dest"
  [ "$output" = "x/y" ]
}

# ── opencode_decide_provider_path ────────────────────────────────────────────
# 5 menu options × {gh authed, gh not authed} = 10 baseline cases, plus
# 1 unknown-selection case = 11. The function is pure, so each case is a
# clean assertion against stdout.

# Helper: capture both lines of stdout into provider/model vars.
_decide() {
  local gh="$1" sel="$2"
  local out
  if ! out=$(opencode_decide_provider_path "$gh" "$sel" 2>/dev/null); then
    return 1
  fi
  PROVIDER=$(echo "$out" | sed -n '1p')
  MODEL=$(echo "$out" | sed -n '2p')
  return 0
}

@test "decide: copilot with gh authed -> github-copilot/claude-sonnet-4.5" {
  _decide yes copilot
  [ "$PROVIDER" = "github-copilot" ]
  [ "$MODEL" = "github-copilot/claude-sonnet-4.5" ]
}

@test "decide: copilot without gh authed -> error (contract violation)" {
  # Orchestrator should never call us with this combination; verify the
  # contract is enforced rather than silently falling through.
  run opencode_decide_provider_path "no" "copilot"
  [ "$status" -eq 2 ]
}

@test "decide: anthropic -> anthropic/claude-sonnet-4.5 regardless of gh state" {
  _decide yes anthropic
  [ "$PROVIDER" = "anthropic" ]
  [ "$MODEL" = "anthropic/claude-sonnet-4.5" ]

  _decide no anthropic
  [ "$PROVIDER" = "anthropic" ]
  [ "$MODEL" = "anthropic/claude-sonnet-4.5" ]
}

@test "decide: openai -> openai/gpt-5.2" {
  _decide yes openai
  [ "$PROVIDER" = "openai" ]
  [ "$MODEL" = "openai/gpt-5.2" ]

  _decide no openai
  [ "$PROVIDER" = "openai" ]
  [ "$MODEL" = "openai/gpt-5.2" ]
}

@test "decide: gemini -> google/gemini-2.5-flash" {
  _decide yes gemini
  [ "$PROVIDER" = "google" ]
  [ "$MODEL" = "google/gemini-2.5-flash" ]

  _decide no gemini
  [ "$PROVIDER" = "google" ]
  [ "$MODEL" = "google/gemini-2.5-flash" ]
}

@test "decide: zen -> opencode-zen / opencode/claude-sonnet-4.6" {
  _decide yes zen
  [ "$PROVIDER" = "opencode-zen" ]
  [ "$MODEL" = "opencode/claude-sonnet-4.6" ]

  _decide no zen
  [ "$PROVIDER" = "opencode-zen" ]
  [ "$MODEL" = "opencode/claude-sonnet-4.6" ]
}

@test "decide: skip -> none with empty model (so opencode falls back)" {
  _decide yes skip
  [ "$PROVIDER" = "none" ]
  [ "$MODEL" = "" ]

  _decide no skip
  [ "$PROVIDER" = "none" ]
  [ "$MODEL" = "" ]
}

@test "decide: unknown selection -> exit 2" {
  run opencode_decide_provider_path "yes" "garbage-string"
  [ "$status" -eq 2 ]
}
