#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR

  SANDBOX="$(mktemp -d)"
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME/.config/opencode" "$HOME/.config/ai-bootstrap"

  CONFIG="$HOME/.config/opencode/opencode.json"
  STATE_FILE="$HOME/.config/ai-bootstrap/state.sh"
  SCRIPT="${BOOTSTRAP_DIR}/scripts/agent/set-models.sh"
  PROFILE="${BOOTSTRAP_DIR}/scripts/model-profiles.json"
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

write_config() {
  cat >"$CONFIG" <<'JSON'
{
  "custom": "preserve-me",
  "model": "old/root-model",
  "small_model": "old/small-model",
  "agent": {
    "plan": { "mode": "subagent", "hidden": true, "marker": "keep-plan" },
    "build": { "mode": "subagent", "hidden": true, "marker": "keep-build" },
    "general": { "hidden": true, "marker": "keep-general" },
    "gandalf": { "model": "old/gandalf", "stale": true },
    "aragorn": { "model": "old/aragorn", "stale": true },
    "saruman": { "model": "old/saruman", "stale": true },
    "legolas": { "model": "old/legolas", "stale": true, "enable_thinking": true },
    "radagast": { "model": "old/radagast", "stale": true, "enable_thinking": true },
    "compaction": { "model": "old/compaction", "stale": true }
  }
}
JSON
}

write_config_with_council() {
  cat >"$CONFIG" <<'JSON'
{
  "custom": "preserve-me",
  "model": "old/root-model",
  "small_model": "old/small-model",
  "plugin": [
    "@tarquinen/opencode-dcp@3.1.11",
    ["@skwid138/opencode-council@0.1.2", {"council": {"reviewer": "saruman", "aggregator": "elrond", "models": []}}]
  ],
  "agent": {
    "plan": { "mode": "subagent", "hidden": true, "marker": "keep-plan" },
    "build": { "mode": "subagent", "hidden": true, "marker": "keep-build" },
    "general": { "hidden": true, "marker": "keep-general" },
    "gandalf": { "model": "old/gandalf", "stale": true },
    "aragorn": { "model": "old/aragorn", "stale": true },
    "saruman": { "model": "old/saruman", "stale": true },
    "legolas": { "model": "old/legolas", "stale": true, "enable_thinking": true },
    "radagast": { "model": "old/radagast", "stale": true, "enable_thinking": true },
    "compaction": { "model": "old/compaction", "stale": true }
  }
}
JSON
}

write_state() {
  local curated_value="${1-__absent__}"
  cat >"$STATE_FILE" <<'EOF'
#!/bin/bash
export AI_BOOTSTRAP_WORKSPACE='/tmp/workspace'
export AI_BOOTSTRAP_TIER='recommended'
EOF
  if [ "$curated_value" != "__absent__" ]; then
    printf "export AI_BOOTSTRAP_CURATED_MODELS='%s'\n" "$curated_value" >>"$STATE_FILE"
  fi
}

write_profile() {
  if [ "$PROFILE" != "${BOOTSTRAP_DIR}/scripts/model-profiles.json" ]; then
    cp "${BOOTSTRAP_DIR}/scripts/model-profiles.json" "$PROFILE"
  fi
}

stage_script_fixture() {
  local root="$SANDBOX/workspace/scripts"
  mkdir -p "$root/agent"
  cp "$PROFILE" "$root/model-profiles.json"
  cp "$SCRIPT" "$root/agent/set-models.sh"
  chmod +x "$root/agent/set-models.sh"
  SCRIPT="$root/agent/set-models.sh"
  PROFILE="$root/model-profiles.json"
}

run_script() {
  run "$SCRIPT" "$@"
}

@test "set-models default: applies optimal models and provider-specific reasoning config" {
  write_config
  write_state ""

  run_script default
  [ "$status" -eq 0 ]

  [ "$(jq -r '.model' "$CONFIG")" = "opencode-go/kimi-k2.6" ]
  [ "$(jq -r '.small_model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
  [ "$(jq -r '.agent.gandalf.model' "$CONFIG")" = "opencode-go/kimi-k2.6" ]
  [ "$(jq -r '.agent.gandalf.thinking.type' "$CONFIG")" = "enabled" ]
  [ "$(jq -r '.agent.aragorn.model' "$CONFIG")" = "opencode-go/minimax-m2.5" ]
  [ "$(jq -r '.agent.aragorn | has("thinking")' "$CONFIG")" = "false" ]
  [ "$(jq -r '.agent.saruman.model' "$CONFIG")" = "opencode-go/minimax-m2.7" ]
  [ "$(jq -r '.agent.legolas.model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
  [ "$(jq -r '.agent.legolas.thinking.type' "$CONFIG")" = "enabled" ]
  [ "$(jq -r '.agent.legolas.reasoningEffort' "$CONFIG")" = "high" ]
  [ "$(jq -r '.agent.radagast.model' "$CONFIG")" = "opencode-go/qwen3.6-plus" ]
  [ "$(jq -r '.agent.radagast.enable_thinking' "$CONFIG")" = "true" ]
  [ "$(jq -r '.agent.compaction.model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
  [ "$(jq -r '.agent.compaction.thinking.type' "$CONFIG")" = "disabled" ]
}

@test "set-models default: applies council models to plugin tuple" {
  write_config_with_council
  write_state ""

  run_script default
  [ "$status" -eq 0 ]

  [ "$(jq -r '.plugin[1][1].council.models | length' "$CONFIG")" = "3" ]
  [ "$(jq -r '.plugin[1][1].council.models[0].providerID' "$CONFIG")" = "opencode-go" ]
  [ "$(jq -r '.plugin[1][1].council.models[0].modelID' "$CONFIG")" = "deepseek-v4-pro" ]
}

@test "set-models default: no argument is the same as default" {
  write_config
  write_state ""

  run_script
  [ "$status" -eq 0 ]

  [ "$(jq -r '.model' "$CONFIG")" = "opencode-go/kimi-k2.6" ]
  [ "$(jq -r '.agent.radagast.model' "$CONFIG")" = "opencode-go/qwen3.6-plus" ]
}

@test "set-models eco: applies economical models and provider-specific reasoning config" {
  write_config
  write_state ""

  run_script eco
  [ "$status" -eq 0 ]

  [ "$(jq -r '.model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
  [ "$(jq -r '.small_model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
  [ "$(jq -r '.agent.gandalf.model' "$CONFIG")" = "opencode-go/kimi-k2.6" ]
  [ "$(jq -r '.agent.gandalf.thinking.type' "$CONFIG")" = "enabled" ]
  [ "$(jq -r '.agent.aragorn.model' "$CONFIG")" = "opencode-go/minimax-m2.5" ]
  [ "$(jq -r '.agent.saruman.model' "$CONFIG")" = "opencode-go/minimax-m2.7" ]
  [ "$(jq -r '.agent.legolas.model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
  [ "$(jq -r '.agent.legolas.thinking.type' "$CONFIG")" = "disabled" ]
  [ "$(jq -r '.agent.legolas | has("reasoningEffort")' "$CONFIG")" = "false" ]
  [ "$(jq -r '.agent.radagast.model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
  [ "$(jq -r '.agent.radagast.thinking.type' "$CONFIG")" = "enabled" ]
  [ "$(jq -r '.agent.radagast.reasoningEffort' "$CONFIG")" = "high" ]
  [ "$(jq -r '.agent.radagast | has("enable_thinking")' "$CONFIG")" = "false" ]
  [ "$(jq -r '.agent.compaction.thinking.type' "$CONFIG")" = "disabled" ]
}

@test "set-models eco: applies eco council models" {
  write_config_with_council
  write_state ""

  run_script eco
  [ "$status" -eq 0 ]

  [ "$(jq -r '.plugin[1][1].council.models | length' "$CONFIG")" = "3" ]
  [ "$(jq -r '.plugin[1][1].council.models[0].modelID' "$CONFIG")" = "deepseek-v4-flash" ]
}

@test "set-models reset: deletes root model keys and all six script-owned agent blocks" {
  write_config
  write_state "default"
  run_script default
  [ "$status" -eq 0 ]

  run_script reset
  [ "$status" -eq 0 ]

  [ "$(jq -r 'has("model")' "$CONFIG")" = "false" ]
  [ "$(jq -r 'has("small_model")' "$CONFIG")" = "false" ]
  for agent in gandalf aragorn saruman legolas radagast compaction; do
    [ "$(jq -r --arg agent "$agent" '.agent | has($agent)' "$CONFIG")" = "false" ]
  done
}

@test "set-models reset: clears council models to empty array" {
  write_config_with_council
  write_state "default"
  run_script default
  [ "$status" -eq 0 ]

  run_script reset
  [ "$status" -eq 0 ]

  [ "$(jq -r '.plugin[1][1].council.models | length' "$CONFIG")" = "0" ]
  [ "$(jq -r '.plugin[1][1].council.reviewer' "$CONFIG")" = "saruman" ]
}

@test "set-models: council pass is no-op when plugin tuple absent" {
  write_config
  write_state ""

  run_script default
  [ "$status" -eq 0 ]

  [ "$(jq -r '.model' "$CONFIG")" = "opencode-go/kimi-k2.6" ]
  run jq -e '.plugin' "$CONFIG"
  [ "$status" -ne 0 ]
}

@test "set-models reset: writes an empty curated-models state value" {
  write_config
  write_state "eco"
  run_script reset
  [ "$status" -eq 0 ]

  # shellcheck disable=SC1090
  source "$STATE_FILE"
  [ "${AI_BOOTSTRAP_CURATED_MODELS-__unset__}" = "" ]
  ! grep -q "AI_BOOTSTRAP_CURATED_MODELS='reset'" "$STATE_FILE"
}

@test "set-models: preserves hidden built-in agents through apply and reset" {
  write_config
  write_state ""

  run_script eco
  [ "$status" -eq 0 ]
  [ "$(jq -r '.agent.plan.marker' "$CONFIG")" = "keep-plan" ]
  [ "$(jq -r '.agent.build.marker' "$CONFIG")" = "keep-build" ]
  [ "$(jq -r '.agent.general.marker' "$CONFIG")" = "keep-general" ]

  run_script reset
  [ "$status" -eq 0 ]
  [ "$(jq -r '.agent.plan.marker' "$CONFIG")" = "keep-plan" ]
  [ "$(jq -r '.agent.build.marker' "$CONFIG")" = "keep-build" ]
  [ "$(jq -r '.agent.general.marker' "$CONFIG")" = "keep-general" ]
}

@test "set-models tier switch: replaces agent blocks without stale keys" {
  write_config
  write_state ""

  run_script default
  [ "$status" -eq 0 ]
  [ "$(jq -r '.agent.radagast.enable_thinking' "$CONFIG")" = "true" ]
  [ "$(jq -r '.agent.legolas.reasoningEffort' "$CONFIG")" = "high" ]

  run_script eco
  [ "$status" -eq 0 ]
  [ "$(jq -r '.model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
  [ "$(jq -r '.agent.radagast | has("enable_thinking")' "$CONFIG")" = "false" ]
  [ "$(jq -r '.agent.legolas | has("reasoningEffort")' "$CONFIG")" = "false" ]
  [ "$(jq -r '.agent.radagast.reasoningEffort' "$CONFIG")" = "high" ]
}

@test "set-models atomic write: malformed profile leaves config unchanged" {
  stage_script_fixture
  write_config
  write_state ""
  before="$SANDBOX/before.json"
  cp "$CONFIG" "$before"
  printf '{ not valid json\n' >"$PROFILE"

  run_script default
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error: invalid profile JSON"* ]]
  cmp "$before" "$CONFIG"
  local backups=( "$CONFIG".bak.*.* )
  [[ ${#backups[@]} -eq 0 || ! -e "${backups[0]}" ]]
}

@test "set-models atomic write: missing tier key in valid profile exits with error" {
  stage_script_fixture
  write_config
  write_state ""
  before="$SANDBOX/before.json"
  cp "$CONFIG" "$before"
  printf '{"default": {"gandalf": {"model": "x"}}}\n' >"$PROFILE"

  run_script eco
  [ "$status" -eq 1 ]
  [[ "$output" == *"tier 'eco' not found"* ]]
  cmp "$before" "$CONFIG"
  local backups=( "$CONFIG".bak.*.* )
  [[ ${#backups[@]} -eq 0 || ! -e "${backups[0]}" ]]
}

@test "set-models output validation: empty transform output is rejected" {
  stage_script_fixture
  write_config
  write_state ""
  write_profile

  local real_jq
  real_jq="$(command -v jq)"
  local fake_bin="$SANDBOX/fake_bin"
  mkdir -p "$fake_bin"

  # Fake jq: transform calls produce no output; all other calls delegate to real jq
  printf '#!/bin/bash\nif [[ "$*" == *--slurpfile* ]] || [[ "$*" == *del\\(* ]]; then true; else exec "%s" "$@"; fi\n' "$real_jq" >"$fake_bin/jq"
  chmod +x "$fake_bin/jq"

  local before="$SANDBOX/before.json"
  cp "$CONFIG" "$before"

  PATH="$fake_bin:$PATH" run_script default
  [ "$status" -ne 0 ]
  [[ "$output" == *"transform produced invalid JSON"* ]]
  cmp "$before" "$CONFIG"
}

@test "set-models idempotent: applying the same tier twice produces identical config" {
  write_config
  write_state ""

  run_script eco
  [ "$status" -eq 0 ]
  first="$SANDBOX/first.json"
  cp "$CONFIG" "$first"

  run_script eco
  [ "$status" -eq 0 ]
  cmp "$first" "$CONFIG"
}

@test "set-models creates a timestamped backup before changing config" {
  write_config
  write_state ""

  run_script default
  [ "$status" -eq 0 ]

  backups=("$CONFIG".bak.*.*)
  [ "${#backups[@]}" -eq 1 ]
  [[ "${backups[0]}" =~ opencode\.json\.bak\.[0-9]{8}-[0-9]{6}\.[0-9]+$ ]]
  [ "$(jq -r '.model' "${backups[0]}")" = "old/root-model" ]
}

@test "set-models reset creates backup" {
  write_config
  write_state "default"

  run_script reset
  [ "$status" -eq 0 ]

  local backups=( "$CONFIG".bak.*.* )
  [ "${#backups[@]}" -eq 1 ]
  [ -e "${backups[0]}" ]
  [ "$(jq -r '.model' "${backups[0]}")" = "old/root-model" ]
}

@test "set-models updates existing curated-models state field" {
  write_config
  write_state "default"

  run_script eco
  [ "$status" -eq 0 ]

  # shellcheck disable=SC1090
  source "$STATE_FILE"
  [ "$AI_BOOTSTRAP_CURATED_MODELS" = "eco" ]
  [ "$(grep -c '^export AI_BOOTSTRAP_CURATED_MODELS=' "$STATE_FILE")" -eq 1 ]
}

@test "set-models appends curated-models state field when absent" {
  write_config
  write_state

  run_script default
  [ "$status" -eq 0 ]

  # shellcheck disable=SC1090
  source "$STATE_FILE"
  [ "$AI_BOOTSTRAP_CURATED_MODELS" = "default" ]
}

@test "set-models invalid tier: prints usage, exits non-zero, and leaves config unchanged" {
  write_config
  write_state ""
  before="$SANDBOX/before.json"
  cp "$CONFIG" "$before"

  run_script fast
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage: set-models.sh [default|eco|reset]"* ]]
  cmp "$before" "$CONFIG"
  local backups=( "$CONFIG".bak.*.* )
  [[ ${#backups[@]} -eq 0 || ! -e "${backups[0]}" ]]
}

@test "set-models missing jq: prints a clear error and exits non-zero" {
  stage_script_fixture
  write_config
  write_state ""
  no_jq_bin="$SANDBOX/no-jq-bin"
  mkdir -p "$no_jq_bin"
  ln -s /bin/bash "$no_jq_bin/bash"
  ln -s /usr/bin/dirname "$no_jq_bin/dirname"

  PATH="$no_jq_bin" run_script default
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error: jq is required"* ]]
}

@test "set-models missing config: prints a clear error and exits non-zero" {
  write_state ""
  rm -f "$CONFIG"

  run_script default
  [ "$status" -ne 0 ]
  [[ "$output" == *"Error: $CONFIG not found"* ]]
}

@test "set-models missing state file: applies config and prints a warning" {
  write_config
  rm -f "$STATE_FILE"

  run_script eco
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning: state file not found, skipping state update"* ]]
  [ "$(jq -r '.model' "$CONFIG")" = "opencode-go/deepseek-v4-flash" ]
}

@test "model profile JSON contains only the supported curated tiers" {
  run jq -r 'keys | sort | join(",")' "$PROFILE"
  [ "$status" -eq 0 ]
  [ "$output" = "default,eco" ]
}

@test "opencode template allows the set-models helper script" {
  run jq -r '.permission.bash["$AI_BOOTSTRAP_WORKSPACE/scripts/agent/set-models.sh *"]' \
    "${BOOTSTRAP_DIR}/opencode/opencode.json.template"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]
}

@test "set-models skill documents detection, preflight checks, and model-name-free non-Go guidance" {
  skill_file="${BOOTSTRAP_DIR}/opencode/skill/set-models/SKILL.md"
  [ -f "$skill_file" ]

  grep -q 'AI_BOOTSTRAP_CURATED_MODELS' "$skill_file"
  grep -q 'scripts/agent/set-models.sh' "$skill_file"
  grep -q 'model-profiles.json' "$skill_file"
  grep -q 'Research summary (2026-05-22)' "$skill_file"

  non_go_section="$SANDBOX/non-go-section.txt"
  awk '/^## For users without OpenCode Go/{flag=1; next} /^## /{flag=0} flag{print}' "$skill_file" >"$non_go_section"
  [ -s "$non_go_section" ]
  ! grep -Eq 'opencode-go/|kimi|deepseek|qwen|minimax' "$non_go_section"
}
