#!/usr/bin/env bats
#
# Unit tests for lib/opencode.sh helpers.
#
# These are filesystem-level tests using a per-test sandbox under
# $BATS_TEST_TMPDIR; they don't touch ~/.config/opencode and they don't
# require opencode/jq/gh to be running interactively (they DO require
# jq to be on PATH for the render_config tests, which is fine — jq is
# an Essential bootstrap package and is already installed in CI).

bats_require_minimum_version 1.5.0

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env

  # shellcheck source=lib/common.sh
  [ -n "${BOOTSTRAP_DIR:-}" ] && [ -z "${AI_BOOTSTRAP_COMMON_SH_SOURCED:-}" ] && [ -f "${BOOTSTRAP_DIR}/lib/common.sh" ] && source "${BOOTSTRAP_DIR}/lib/common.sh"

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
  mkdir -p "$src"/{agent,skill/foo,command,instruction,plugins}
  echo "agent" >"$src/agent/x.md"
  echo "skill" >"$src/skill/foo/SKILL.md"
  echo "cmd" >"$src/command/c.md"
  echo "ins" >"$src/instruction/i.md"
  echo "plugin" >"$src/plugins/p.ts"

  run opencode_deploy_assets "$src" "$dest"
  [ "$status" -eq 0 ]

  [ -f "$dest/agent/x.md" ]
  [ -f "$dest/skill/foo/SKILL.md" ]
  [ -f "$dest/command/c.md" ]
  [ -f "$dest/instruction/i.md" ]
  [ -f "$dest/plugins/p.ts" ]
}

@test "opencode_deploy_assets: skips missing subdirs gracefully" {
  src="$SANDBOX/src"
  dest="$SANDBOX/dest"
  mkdir -p "$src/agent"
  echo "agent" >"$src/agent/x.md"
  # Note: no skill/, command/, instruction/, plugins/ — should be fine.

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

# ── opencode_deploy_scripts ──────────────────────────────────────────────────

@test "opencode_deploy_scripts: copies agent and lib scripts" {
  src="$SANDBOX/src-scripts"
  dest="$SANDBOX/workspace/scripts"
  mkdir -p "$src/agent" "$src/lib"
  echo "agent script" >"$src/agent/check.sh"
  echo "common lib" >"$src/lib/common.sh"

  run opencode_deploy_scripts "$src" "$dest"
  [ "$status" -eq 0 ]
  [ -f "$dest/agent/check.sh" ]
  [ -f "$dest/lib/common.sh" ]

  run cat "$dest/agent/check.sh"
  [ "$output" = "agent script" ]
}

@test "opencode_deploy_scripts: decline leaves existing scripts untouched" {
  src="$SANDBOX/src-scripts"
  dest="$SANDBOX/workspace/scripts"
  mkdir -p "$src/agent" "$dest/agent"
  echo "new" >"$src/agent/check.sh"
  echo "old" >"$dest/agent/check.sh"

  run bash -c "source '$BOOTSTRAP_DIR/lib/opencode.sh'; opencode_deploy_scripts '$src' '$dest' <<< n"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Overwrite?"* ]]
  [[ "$output" == *"No keeps your existing scripts"* ]]

  run cat "$dest/agent/check.sh"
  [ "$output" = "old" ]
}

@test "opencode_deploy_scripts: non-interactive mode overwrites without prompt" {
  src="$SANDBOX/src-scripts"
  dest="$SANDBOX/workspace/scripts"
  mkdir -p "$src/agent" "$dest/agent"
  echo "new" >"$src/agent/check.sh"
  echo "old" >"$dest/agent/check.sh"

  export BOOTSTRAP_NONINTERACTIVE=1
  run opencode_deploy_scripts "$src" "$dest"
  unset BOOTSTRAP_NONINTERACTIVE

  [ "$status" -eq 0 ]
  [[ "$output" != *"Overwrite?"* ]]
  run cat "$dest/agent/check.sh"
  [ "$output" = "new" ]
}

make_script_dependent_assets() {
  local config_dir="$1"
  mkdir -p \
    "$config_dir/skill/check-updates" \
    "$config_dir/skill/set-models" \
    "$config_dir/skill/permission-audit" \
    "$config_dir/skill/dependency-update" \
    "$config_dir/skill/check-my-site" \
    "$config_dir/command"
  for skill in check-updates set-models permission-audit dependency-update check-my-site; do
    echo "$skill" >"$config_dir/skill/$skill/SKILL.md"
  done
  for command in update-opencode-deps check-my-site check-updates permission-audit help-me; do
    echo "$command" >"$config_dir/command/$command.md"
  done
}

@test "opencode_cleanup_scripts_assets: removes only assets whose helper is absent" {
  config_dir="$SANDBOX/opencode"
  scripts_dir="$SANDBOX/workspace/scripts"
  make_script_dependent_assets "$config_dir"
  mkdir -p "$scripts_dir/agent"
  echo "helper" >"$scripts_dir/agent/opencode-deps-check.sh"

  run opencode_cleanup_scripts_assets "$config_dir" "$scripts_dir"
  [ "$status" -eq 0 ]
  [ -f "$config_dir/skill/dependency-update/SKILL.md" ]
  [ -f "$config_dir/command/update-opencode-deps.md" ]
  [ ! -e "$config_dir/skill/check-updates" ]
  [ ! -e "$config_dir/skill/set-models" ]
  [ ! -e "$config_dir/skill/permission-audit" ]
  [ ! -e "$config_dir/skill/check-my-site" ]
  [ ! -e "$config_dir/command/check-my-site.md" ]
  [ -f "$config_dir/command/check-updates.md" ]
  [ -f "$config_dir/command/permission-audit.md" ]
  [ -f "$config_dir/command/help-me.md" ]
}

@test "opencode_cleanup_scripts_assets: preserves all script-backed assets when helpers exist" {
  config_dir="$SANDBOX/opencode"
  scripts_dir="$SANDBOX/workspace/scripts"
  make_script_dependent_assets "$config_dir"
  mkdir -p "$scripts_dir/agent"
  for helper in bootstrap-update-check.sh set-models.sh permission-audit.sh opencode-deps-check.sh chrome_mcp.sh; do
    echo "helper" >"$scripts_dir/agent/$helper"
  done

  run opencode_cleanup_scripts_assets "$config_dir" "$scripts_dir"
  [ "$status" -eq 0 ]
  [ -f "$config_dir/skill/check-updates/SKILL.md" ]
  [ -f "$config_dir/skill/set-models/SKILL.md" ]
  [ -f "$config_dir/skill/permission-audit/SKILL.md" ]
  [ -f "$config_dir/skill/dependency-update/SKILL.md" ]
  [ -f "$config_dir/command/update-opencode-deps.md" ]
  [ -f "$config_dir/skill/check-my-site/SKILL.md" ]
  [ -f "$config_dir/command/check-my-site.md" ]
}

@test "opencode_cleanup_scripts_assets: no workspace removes script-backed assets but keeps same-named commands" {
  config_dir="$SANDBOX/opencode"
  make_script_dependent_assets "$config_dir"

  run opencode_cleanup_scripts_assets "$config_dir" ""
  [ "$status" -eq 0 ]
  [ ! -e "$config_dir/skill/check-updates" ]
  [ ! -e "$config_dir/skill/set-models" ]
  [ ! -e "$config_dir/skill/permission-audit" ]
  [ ! -e "$config_dir/skill/dependency-update" ]
  [ ! -e "$config_dir/command/update-opencode-deps.md" ]
  [ ! -e "$config_dir/skill/check-my-site" ]
  [ ! -e "$config_dir/command/check-my-site.md" ]
  [ -f "$config_dir/command/check-updates.md" ]
  [ -f "$config_dir/command/permission-audit.md" ]
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

# ── opencode_deploy_if_missing ───────────────────────────────────────────────

@test "opencode_deploy_if_missing: installs when destination missing" {
  src="$SANDBOX/dcp.jsonc"
  dest="$SANDBOX/dest/dcp.jsonc"
  echo '{ "compress": { "maxContextLimit": "65%" } }' >"$src"

  run opencode_deploy_if_missing "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  [ -f "$dest" ]
  run grep -q '"maxContextLimit": "65%"' "$dest"
  [ "$status" -eq 0 ]
}

@test "opencode_deploy_if_missing: skips when destination exists (overwrite-protect)" {
  src="$SANDBOX/dcp.jsonc"
  dest="$SANDBOX/dest/dcp.jsonc"
  echo '{ "new": true }' >"$src"
  mkdir -p "$(dirname "$dest")"
  echo '{ "user_tweaked": true }' >"$dest"

  run opencode_deploy_if_missing "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "skipped" ]
  run cat "$dest"
  [ "$output" = '{ "user_tweaked": true }' ]
}

@test "opencode_deploy_if_missing: errors when source missing" {
  run opencode_deploy_if_missing "$SANDBOX/nope.jsonc" "$SANDBOX/dest/dcp.jsonc"
  [ "$status" -ne 0 ]
}

# ── opencode_deploy_tui_config ───────────────────────────────────────────────

write_tui_template() {
  local path="$1"
  cat >"$path" <<'EOF'
{
  "$schema": "https://opencode.ai/tui.json",
  "plugin": [
    ["@skwid138/opencode-tui@1.1.1", {}]
  ]
}
EOF
}

@test "opencode_deploy_tui_config: fresh install writes template verbatim" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/config/tui.json"
  write_tui_template "$src"

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  [ -f "$dest" ]
  cmp -s "$src" "$dest"
  backups=("$SANDBOX"/dest/config/tui.json.bak.*)
  [ ! -e "${backups[0]}" ]
}

@test "opencode_deploy_tui_config: deployed config carries shipped logo rows" {
  src="${BOOTSTRAP_DIR}/opencode/tui.json.template"
  dest="$SANDBOX/dest/config/tui.json"

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]

  jq -e '(.plugin[] | select(.[0] == "@skwid138/opencode-tui@1.1.1") | .[1].logo.rows | length) == 6' "$dest"
}

@test "opencode_deploy_tui_config: existing valid config preserves theme and merges plugins" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<'EOF'
{
  "$schema": "old-schema",
  "theme": "catppuccin",
  "plugin": [
    ["@skwid138/opencode-tui@1.1.1", {"stale": true}],
    ["./plugins/user.tsx", {"enabled": true}]
  ],
  "other": {"keep": true}
}
EOF

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "updated" ]
  jq -e '.["$schema"] == "https://opencode.ai/tui.json"' "$dest"
  jq -e '.theme == "catppuccin" and .other.keep == true' "$dest"
  jq -e '.plugin == [["@skwid138/opencode-tui@1.1.1", {}], ["./plugins/user.tsx", {"enabled": true}]]' "$dest"
  backups=("$SANDBOX"/dest/tui.json.bak.*)
  [ "${#backups[@]}" -eq 1 ]
  jq -e '.theme == "catppuccin"' "${backups[0]}"
}

@test "opencode_deploy_tui_config: user plugins are preserved after managed plugins" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<'EOF'
{
  "plugin": [
    ["./plugins/first-user.tsx", {"a": 1}],
    ["./plugins/second-user.tsx", {"b": 2}]
  ]
}
EOF

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "updated" ]
  jq -e '.plugin | map(.[0]) == ["@skwid138/opencode-tui@1.1.1", "./plugins/first-user.tsx", "./plugins/second-user.tsx"]' "$dest"
}

@test "opencode_deploy_tui_config: existing config without plugin field merges cleanly" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  echo '{"theme":"dracula","custom_key":"preserved"}' >"$dest"

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "updated" ]
  jq -e '.theme == "dracula" and .custom_key == "preserved"' "$dest"
  jq -e '.plugin == [["@skwid138/opencode-tui@1.1.1", {}]]' "$dest"
}

@test "opencode_deploy_tui_config: malformed JSON is backed up and freshly installed" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  printf '{ bad json' >"$dest"

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  cmp -s "$src" "$dest"
  backups=("$SANDBOX"/dest/tui.json.bak.*)
  [ "${#backups[@]}" -eq 1 ]
  run cat "${backups[0]}"
  [ "$output" = "{ bad json" ]
}

@test "opencode_deploy_tui_config: valid non-object JSON is backed up and freshly installed" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  echo '["not", "object"]' >"$dest"

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  cmp -s "$src" "$dest"
  backups=("$SANDBOX"/dest/tui.json.bak.*)
  [ "${#backups[@]}" -eq 1 ]
  jq -e '. == ["not", "object"]' "${backups[0]}"
}

@test "opencode_deploy_tui_config: non-array plugin field is backed up and freshly installed" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  echo '{"theme":"lost-on-repair","plugin":{"bad":true}}' >"$dest"

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  cmp -s "$src" "$dest"
  jq -e 'has("theme") | not' "$dest"
  backups=("$SANDBOX"/dest/tui.json.bak.*)
  [ "${#backups[@]}" -eq 1 ]
  jq -e '.theme == "lost-on-repair"' "${backups[0]}"
}

@test "opencode_deploy_tui_config: malformed plugin entries are dropped" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<'EOF'
{
  "plugin": [
    "not-an-array",
    [],
    [42, {}],
    ["./plugins/user.tsx", {}]
  ]
}
EOF

  run opencode_deploy_tui_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "updated" ]
  jq -e '.plugin == [["@skwid138/opencode-tui@1.1.1", {}], ["./plugins/user.tsx", {}]]' "$dest"
}

@test "opencode_deploy_tui_config: production historical plugins remove old local TUI paths and previous npm package" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  old_tui_plugin="@skwid138/opencode-tui@1."
  old_tui_plugin+="0.0"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<EOF
{
  "plugin": [
    ["$old_tui_plugin", {"stale": true}],
    ["./plugins/home-prompt.tsx", {"stale": true}],
    ["./plugins/justvibes-logo.tsx", {"stale": true}],
    ["./plugins/user.tsx", {}]
  ]
}
EOF

  run opencode_deploy_tui_config "$src" "$dest"

  [ "$status" -eq 0 ]
  [ "$output" = "updated" ]
  jq -e '(.plugin | map(.[0])) == ["@skwid138/opencode-tui@1.1.1", "./plugins/user.tsx"]' "$dest"
  jq -e --arg old "$old_tui_plugin" 'all(.plugin[]; .[0] != $old)' "$dest"
}

@test "opencode_deploy_tui_config: production historical plugins remove previous 1.1.0 npm package" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<'EOF'
{
  "plugin": [
    ["@skwid138/opencode-tui@1.1.0", {"stale": true}],
    ["./plugins/user.tsx", {}]
  ]
}
EOF
  unset OPENCODE_BOOTSTRAP_TEST OPENCODE_TEST_HISTORICAL_MANAGED_PLUGINS

  run opencode_deploy_tui_config "$src" "$dest"

  [ "$status" -eq 0 ]
  [ "$output" = "updated" ]
  jq -e '.plugin == [["@skwid138/opencode-tui@1.1.1", {}], ["./plugins/user.tsx", {}]]' "$dest"
  jq -e 'all(.plugin[]; .[0] != "@skwid138/opencode-tui@1.1.0")' "$dest"
}

@test "opencode_deploy_tui_config: historical managed plugins are removed" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<'EOF'
{
  "plugin": [
    ["./plugins/old-managed.tsx", {"remove": true}],
    ["./plugins/user.tsx", {}]
  ]
}
EOF
  export OPENCODE_BOOTSTRAP_TEST=1
  export OPENCODE_TEST_HISTORICAL_MANAGED_PLUGINS="./plugins/old-managed.tsx"

  run opencode_deploy_tui_config "$src" "$dest"
  unset OPENCODE_BOOTSTRAP_TEST OPENCODE_TEST_HISTORICAL_MANAGED_PLUGINS

  [ "$status" -eq 0 ]
  [ "$output" = "updated" ]
  jq -e '(.plugin | map(.[0])) == ["@skwid138/opencode-tui@1.1.1", "./plugins/user.tsx"]' "$dest"
}

@test "opencode_deploy_tui_config: template-derived plugins are not duplicated by historical list" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  cat >"$dest" <<'EOF'
{
  "plugin": [
    ["@skwid138/opencode-tui@1.1.1", {"stale": true}],
    ["./plugins/user.tsx", {}]
  ]
}
EOF
  export OPENCODE_BOOTSTRAP_TEST=1
  # Inject the template-current version to exercise unique de-duping when it
  # appears in both lists; cross-version removals are covered separately above.
  export OPENCODE_TEST_HISTORICAL_MANAGED_PLUGINS="@skwid138/opencode-tui@1.1.1"

  run opencode_deploy_tui_config "$src" "$dest"
  unset OPENCODE_BOOTSTRAP_TEST OPENCODE_TEST_HISTORICAL_MANAGED_PLUGINS

  [ "$status" -eq 0 ]
  [ "$output" = "updated" ]
  jq -e '[.plugin[] | select(.[0] == "@skwid138/opencode-tui@1.1.1")] | length == 1' "$dest"
  jq -e '(.plugin | map(.[0])) == ["@skwid138/opencode-tui@1.1.1", "./plugins/user.tsx"]' "$dest"
}

@test "opencode_deploy_tui_config: jq merge failure leaves existing file untouched" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"
  mkdir -p "$(dirname "$dest")"
  echo '{"theme":"keep","plugin":[["./plugins/user.tsx",{}]]}' >"$dest"
  real_jq="$(command -v jq)"
  mock_dir="$SANDBOX/mock-bin"
  mkdir -p "$mock_dir"
  cat >"$mock_dir/jq" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "--argjson" ]; then
  exit 42
fi
exec "$real_jq" "\$@"
EOF
  chmod +x "$mock_dir/jq"
  old_path="$PATH"
  PATH="$mock_dir:$PATH"

  run opencode_deploy_tui_config "$src" "$dest"
  PATH="$old_path"

  [ "$status" -ne 0 ]
  run cat "$dest"
  [ "$output" = '{"theme":"keep","plugin":[["./plugins/user.tsx",{}]]}' ]
  temp_files=("$SANDBOX"/dest/.tui.json.*)
  [ ! -e "${temp_files[0]}" ]
}

@test "opencode_deploy_tui_config: errors when source missing" {
  run --separate-stderr opencode_deploy_tui_config "$SANDBOX/nope.json" "$SANDBOX/dest/tui.json"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"template not found"* ]]
}

@test "opencode_deploy_with_backup: delegates to tui config merge for compatibility" {
  src="$SANDBOX/tui.json"
  dest="$SANDBOX/dest/tui.json"
  write_tui_template "$src"

  run opencode_deploy_with_backup "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  cmp -s "$src" "$dest"
}

# ── opencode_render_config ───────────────────────────────────────────────────

@test "opencode_render_config: sets model when provided" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"

  run opencode_render_config "$src" "$dest" "github-copilot/claude-sonnet-4.5"
  [ "$status" -eq 0 ]

  run jq -r '.model' "$dest"
  [ "$output" = "github-copilot/claude-sonnet-4.5" ]
}

@test "opencode_render_config: deletes model when blank (skip path)" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"

  run opencode_render_config "$src" "$dest" ""
  [ "$status" -eq 0 ]

  # Key must be ABSENT, not just empty — opencode reads "absent" as
  # "use my default" but reads "" as "user explicitly chose empty",
  # which would fail.
  run jq 'has("model")' "$dest"
  [ "$output" = "false" ]
}

@test "opencode_render_config: deletes model when 3rd arg omitted entirely" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"

  run opencode_render_config "$src" "$dest"
  [ "$status" -eq 0 ]
  run jq 'has("model")' "$dest"
  [ "$output" = "false" ]
}

@test "opencode_render_config: preserves the rest of the template" {
  # Spot-check that we didn't accidentally strip MCPs or the plugin
  # array while doing the model field surgery.
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"

  run opencode_render_config "$src" "$dest" "x/y"
  [ "$status" -eq 0 ]

  run jq -r '.mcp | keys | sort | join(",")' "$dest"
  [ "$output" = "chrome-devtools,context7,exa" ]

  run jq -r '.plugin | length' "$dest"
  [ "$output" = "2" ]
}

@test "opencode_render_config: rendered opencode config contains no TUI plugin" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"

  run opencode_render_config "$src" "$dest" "x/y"
  [ "$status" -eq 0 ]

  jq -e 'all(.plugin[]; ((if type == "array" then .[0] else . end) | contains("opencode-tui") | not))' "$dest"
}

@test "opencode_render_config: errors when template missing" {
  run opencode_render_config "$SANDBOX/nope.json" "$SANDBOX/out.json" ""
  [ "$status" -ne 0 ]
}

@test "opencode_render_config: overwrites existing config" {
  # We've documented that opencode.jsonc is bootstrap-managed. Verify it
  # actually overwrites — silent skipping would be much worse than
  # known-overwrite.
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"
  echo '{"old":true}' >"$dest"

  run opencode_render_config "$src" "$dest" "x/y"
  [ "$status" -eq 0 ]
  run jq 'has("old")' "$dest"
  [ "$output" = "false" ]
  run jq -r '.model' "$dest"
  [ "$output" = "x/y" ]
}

@test "opencode_render_config: backs up existing config before overwrite" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"
  echo '{"user_tweak":true}' >"$dest"

  run opencode_render_config "$src" "$dest" "x/y"
  [ "$status" -eq 0 ]

  backups=("$SANDBOX"/opencode.jsonc.bak.*.*)
  [ "${#backups[@]}" -eq 1 ]
  [ -f "${backups[0]}" ]
  run cat "${backups[0]}"
  [ "$output" = '{"user_tweak":true}' ]
}

@test "opencode_render_config: migrates legacy opencode.json to single live opencode.jsonc" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  config_dir="$SANDBOX/config"
  dest="$config_dir/opencode.jsonc"
  mkdir -p "$config_dir"
  echo '{"model":"legacy/model","user_tweak":true}' >"$config_dir/opencode.json"

  run opencode_render_config "$src" "$dest" "legacy/model"
  [ "$status" -eq 0 ]

  [ -f "$dest" ]
  [ ! -e "$config_dir/opencode.json" ]
  backups=("$config_dir"/opencode.json.bak.*.*)
  [ "${#backups[@]}" -eq 1 ]
  jq -e '.user_tweak == true' "${backups[0]}"
  [ "$(find "$config_dir" -maxdepth 1 \( -name 'opencode.json' -o -name 'opencode.jsonc' \) -type f | wc -l | tr -d ' ')" = "1" ]
}

@test "opencode_render_config: backs up existing opencode.jsonc before writing new live file" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  config_dir="$SANDBOX/config-jsonc"
  dest="$config_dir/opencode.jsonc"
  mkdir -p "$config_dir"
  echo '{"model":"old/jsonc"}' >"$dest"

  run opencode_render_config "$src" "$dest" "new/model"
  [ "$status" -eq 0 ]

  [ "$(jq -r '.model' "$dest")" = "new/model" ]
  backups=("$config_dir"/opencode.jsonc.bak.*.*)
  [ "${#backups[@]}" -eq 1 ]
  [ "$(jq -r '.model' "${backups[0]}")" = "old/jsonc" ]
}

@test "opencode_render_config: both legacy live files are backed up before single opencode.jsonc remains" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  config_dir="$SANDBOX/config-both"
  dest="$config_dir/opencode.jsonc"
  mkdir -p "$config_dir"
  echo '{"model":"old/json"}' >"$config_dir/opencode.json"
  echo '{"$schema":"schema-only"}' >"$dest"

  run opencode_render_config "$src" "$dest" "old/json"
  [ "$status" -eq 0 ]

  [ ! -e "$config_dir/opencode.json" ]
  [ -f "$dest" ]
  json_backups=("$config_dir"/opencode.json.bak.*.*)
  jsonc_backups=("$config_dir"/opencode.jsonc.bak.*.*)
  [ "${#json_backups[@]}" -eq 1 ]
  [ "${#jsonc_backups[@]}" -eq 1 ]
  [ "$(find "$config_dir" -maxdepth 1 \( -name 'opencode.json' -o -name 'opencode.jsonc' \) -type f | wc -l | tr -d ' ')" = "1" ]
}

@test "opencode_render_config: jq failure leaves existing live file byte-identical" {
  src="$SANDBOX/bad-template.jsonc"
  config_dir="$SANDBOX/config-jq-fail"
  dest="$config_dir/opencode.jsonc"
  mkdir -p "$config_dir"
  printf '{"model":"keep","spacing": [1, 2, 3]}\n' >"$dest"
  before="$SANDBOX/before.jsonc"
  cp "$dest" "$before"
  printf '{ invalid json\n' >"$src"

  run opencode_render_config "$src" "$dest" "new/model"
  [ "$status" -ne 0 ]
  cmp "$before" "$dest"
  backups=("$config_dir"/opencode.jsonc.bak.*.*)
  [[ ${#backups[@]} -eq 0 || ! -e "${backups[0]}" ]]
}

@test "opencode_render_config: backup mv failure returns nonzero and leaves live file untouched" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  config_dir="$SANDBOX/config-mv-fail"
  dest="$config_dir/opencode.jsonc"
  mkdir -p "$config_dir"
  echo '{"model":"keep"}' >"$dest"
  before="$SANDBOX/before-mv.jsonc"
  cp "$dest" "$before"
  real_mv="$(command -v mv)"
  mock_dir="$SANDBOX/mock-bin"
  mkdir -p "$mock_dir"
  cat >"$mock_dir/mv" <<EOF
#!/usr/bin/env bash
case "\${2:-}" in
  *.bak.*) exit 42 ;;
esac
exec "$real_mv" "\$@"
EOF
  chmod +x "$mock_dir/mv"
  old_path="$PATH"
  PATH="$mock_dir:$PATH"

  run opencode_render_config "$src" "$dest" "new/model"
  PATH="$old_path"

  [ "$status" -ne 0 ]
  cmp "$before" "$dest"
  [ "$(jq -r '.model' "$dest")" = "keep" ]
}

@test "opencode_backup_stale_configs: restores first live file when second backup move fails" {
  config_dir="$SANDBOX/config-partial-mv-fail"
  mkdir -p "$config_dir"
  printf '{"model":"json-first"}\n' >"$config_dir/opencode.json"
  printf '{"model":"jsonc-second"}\n' >"$config_dir/opencode.jsonc"
  real_mv="$(command -v mv)"
  mock_dir="$SANDBOX/mock-bin-partial-mv"
  mkdir -p "$mock_dir"
  cat >"$mock_dir/mv" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "$config_dir/opencode.jsonc" ] && [[ "\${2:-}" == *.bak.* ]]; then
  exit 42
fi
exec "$real_mv" "\$@"
EOF
  chmod +x "$mock_dir/mv"
  old_path="$PATH"
  PATH="$mock_dir:$PATH"

  run opencode_backup_stale_configs "$config_dir"
  PATH="$old_path"

  [ "$status" -ne 0 ]
  run cat "$config_dir/opencode.json"
  [ "$output" = '{"model":"json-first"}' ]
  run cat "$config_dir/opencode.jsonc"
  [ "$output" = '{"model":"jsonc-second"}' ]
  json_backups=("$config_dir"/opencode.json.bak.*.*)
  jsonc_backups=("$config_dir"/opencode.jsonc.bak.*.*)
  [ ! -e "${json_backups[0]}" ]
  [ ! -e "${jsonc_backups[0]}" ]
}

@test "opencode_backup_stale_configs: first backup mv failure is clean and leaves live file untouched" {
  config_dir="$SANDBOX/config-first-mv-fail"
  mkdir -p "$config_dir"
  printf '{"model":"json-first","legacy":true}\n' >"$config_dir/opencode.json"
  before="$SANDBOX/before-opencode.json"
  cp "$config_dir/opencode.json" "$before"
  real_mv="$(command -v mv)"
  mock_dir="$SANDBOX/mock-bin-first-mv"
  mkdir -p "$mock_dir"
  cat >"$mock_dir/mv" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "$config_dir/opencode.json" ] && [[ "\${2:-}" == *.bak.* ]]; then
  exit 42
fi
exec "$real_mv" "\$@"
EOF
  chmod +x "$mock_dir/mv"

  PATH="$mock_dir:$PATH" run /bin/bash -c 'set -euo pipefail; export BOOTSTRAP_DIR="$1"; source "$BOOTSTRAP_DIR/lib/opencode.sh"; opencode_backup_stale_configs "$2"' bash "$BOOTSTRAP_DIR" "$config_dir"

  [ "$status" -ne 0 ]
  [[ "$output" == *"opencode_backup_stale_configs: failed to backup: $config_dir/opencode.json"* ]]
  [[ "$output" != *"unbound variable"* ]]
  cmp "$before" "$config_dir/opencode.json"
  backups=("$config_dir"/opencode.json.bak.*.*)
  [ ! -e "${backups[0]}" ]
}

@test "opencode_read_model_value: reads model from opencode.json when opencode.jsonc is absent" {
  config_dir="$SANDBOX/config-json-only-model-read"
  mkdir -p "$config_dir"
  printf '{"model":"json-only/model"}\n' >"$config_dir/opencode.json"

  run opencode_read_model_value "$config_dir"

  [ "$status" -eq 0 ]
  [ "$output" = "json-only/model" ]
  [ ! -e "$config_dir/opencode.jsonc" ]
}

@test "opencode_read_model_value: falls back to opencode.json when opencode.jsonc lacks model" {
  config_dir="$SANDBOX/config-jsonc-schema-only-model-read"
  mkdir -p "$config_dir"
  printf '{"$schema":"https://opencode.ai/config.json"}\n' >"$config_dir/opencode.jsonc"
  printf '{"model":"json-fallback/model"}\n' >"$config_dir/opencode.json"

  run opencode_read_model_value "$config_dir"

  [ "$status" -eq 0 ]
  [ "$output" = "json-fallback/model" ]
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

@test "decide: opencode -> opencode-go / opencode-go/kimi-k2.6" {
  _decide yes opencode
  [ "$PROVIDER" = "opencode-go" ]
  [ "$MODEL" = "opencode-go/kimi-k2.6" ]

  _decide no opencode
  [ "$PROVIDER" = "opencode-go" ]
  [ "$MODEL" = "opencode-go/kimi-k2.6" ]
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

# ── opencode_render_config workspace substitution ────────────────────────────

@test "opencode_render_config: substitutes workspace from AI_BOOTSTRAP_WORKSPACE" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"
  export AI_BOOTSTRAP_WORKSPACE="/custom/path"

  run opencode_render_config "$src" "$dest" "x/y"
  unset AI_BOOTSTRAP_WORKSPACE
  [ "$status" -eq 0 ]

  run grep -q "/custom/path/scripts/agent/" "$dest"
  [ "$status" -eq 0 ]
  run grep -q '\$AI_BOOTSTRAP_WORKSPACE' "$dest"
  [ "$status" -ne 0 ]
}

@test "opencode_render_config: substitutes literal config dir for handoff redaction helper" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  config_dir="$SANDBOX/config/opencode"
  dest="$config_dir/opencode.jsonc"
  export AI_BOOTSTRAP_WORKSPACE="/custom/workspace"

  run opencode_render_config "$src" "$dest" "x/y"
  unset AI_BOOTSTRAP_WORKSPACE
  [ "$status" -eq 0 ]

  literal_key="$config_dir/skill/handoff/redact-secrets.sh *"
  run jq -r --arg key "$literal_key" '.permission.bash[$key]' "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "allow" ]
  run grep -q '\$OPENCODE_CONFIG_DIR' "$dest"
  [ "$status" -ne 0 ]
}

@test "opencode_render_config: reads workspace from state file when env unset" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"
  home="$SANDBOX/home-state"
  mkdir -p "$home/.config/ai-bootstrap"
  cat >"$home/.config/ai-bootstrap/state.sh" <<'EOF'
export AI_BOOTSTRAP_WORKSPACE='/state/workspace'
EOF
  old_home="$HOME"
  export HOME="$home"
  unset AI_BOOTSTRAP_WORKSPACE

  run opencode_render_config "$src" "$dest" "x/y"
  export HOME="$old_home"
  [ "$status" -eq 0 ]

  run grep -q "/state/workspace/scripts/agent/" "$dest"
  [ "$status" -eq 0 ]
}

@test "opencode_render_config: falls back to HOME code workspace when env and state missing" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"
  home="$SANDBOX/home-default"
  mkdir -p "$home"
  old_home="$HOME"
  export HOME="$home"
  unset AI_BOOTSTRAP_WORKSPACE

  run opencode_render_config "$src" "$dest" "x/y"
  export HOME="$old_home"
  [ "$status" -eq 0 ]

  run grep -q "$home/code/scripts/agent/" "$dest"
  [ "$status" -eq 0 ]
}

@test "opencode_render_config: strips trailing slash from workspace" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"
  export AI_BOOTSTRAP_WORKSPACE="/foo/bar/"

  run opencode_render_config "$src" "$dest" "x/y"
  unset AI_BOOTSTRAP_WORKSPACE
  [ "$status" -eq 0 ]

  run grep -q "/foo/bar/scripts/agent/" "$dest"
  [ "$status" -eq 0 ]
  run grep -q "/foo/bar//scripts/" "$dest"
  [ "$status" -ne 0 ]
}

@test "opencode_render_config: rendered output is valid JSON after substitution" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"
  export AI_BOOTSTRAP_WORKSPACE="/json/workspace"

  run opencode_render_config "$src" "$dest" "x/y"
  unset AI_BOOTSTRAP_WORKSPACE
  [ "$status" -eq 0 ]

  run jq -e 'type == "object"' "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "opencode_render_config: model set and delete still work after substitution" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest_with_model="$SANDBOX/opencode-with-model.jsonc"
  dest_without_model="$SANDBOX/opencode-without-model.jsonc"
  export AI_BOOTSTRAP_WORKSPACE="/model/workspace"

  run opencode_render_config "$src" "$dest_with_model" "github-copilot/claude-sonnet-4.5"
  [ "$status" -eq 0 ]
  run jq -r '.model' "$dest_with_model"
  [ "$output" = "github-copilot/claude-sonnet-4.5" ]
  run grep -q "/model/workspace/scripts/agent/" "$dest_with_model"
  [ "$status" -eq 0 ]

  run opencode_render_config "$src" "$dest_without_model" ""
  unset AI_BOOTSTRAP_WORKSPACE
  [ "$status" -eq 0 ]
  run jq 'has("model")' "$dest_without_model"
  [ "$output" = "false" ]
  run grep -q "/model/workspace/scripts/agent/" "$dest_without_model"
  [ "$status" -eq 0 ]
}

@test "opencode_render_config: external_directory includes substituted workspace allow" {
  src="${BOOTSTRAP_DIR}/opencode/opencode.jsonc.template"
  dest="$SANDBOX/opencode.jsonc"
  export AI_BOOTSTRAP_WORKSPACE="/external/workspace"

  run opencode_render_config "$src" "$dest" "x/y"
  unset AI_BOOTSTRAP_WORKSPACE
  [ "$status" -eq 0 ]

  run jq -e '.permission.external_directory["*"] == "ask" and .permission.external_directory["/external/workspace/*"] == "allow"' "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}
