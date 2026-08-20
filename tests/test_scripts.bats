#!/usr/bin/env bats
# Tests for bundled helper scripts under scripts/.

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env

  SCRIPT="${BOOTSTRAP_DIR}/scripts/agent/opencode-deps-check.sh"
  COMMON="${BOOTSTRAP_DIR}/scripts/lib/common.sh"
  TMP_CFG="${BATS_TEST_TMPDIR}/cfg"
  mkdir -p "$TMP_CFG"
  export SCRIPT COMMON TMP_CFG
}

teardown() {
  teardown_test_env
}

write_npm_stub() {
  local stub_dir="$1"
  mkdir -p "$stub_dir"
  cat >"$stub_dir/npm" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "view" && "${3:-}" == "version" ]]; then
  case "${2:-}" in
    fake-pkg) echo "2.0.0" ;;
    another-fake-pkg) echo "3.0.0" ;;
    chrome-devtools-mcp) echo "1.7.0" ;;
    @scope/tool) echo "1.5.0" ;;
    *) echo "9.9.9" ;;
  esac
  exit 0
fi
exit 0
EOF
  chmod +x "$stub_dir/npm"
}

write_fixture_config() {
  cat >"$TMP_CFG/package.json" <<'EOF'
{
  "name": "fixture",
  "private": true,
  "dependencies": {
    "fake-pkg": "1.0.0"
  }
}
EOF

  cat >"$TMP_CFG/opencode.jsonc" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["another-fake-pkg@2.0.0"],
  "mcp": {
    "chrome-devtools": {
      "type": "local",
      "command": ["npx", "-y", "chrome-devtools-mcp@1.7.0"]
    },
    "scope-tool": {
      "type": "local",
      "command": ["npx", "-y", "@scope/tool@latest"]
    }
  }
}
EOF
}

write_jsonc_fixture_config() {
  cat >"$TMP_CFG/opencode.jsonc" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "fake-pkg@1.0.0",
  ],
}
EOF
}

@test "scripts: opencode dependency checker exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ]
}

@test "scripts: --help exits 0 and prints usage" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: opencode-deps-check"* ]]
}

@test "scripts: --config-dir without argument exits with clear error" {
  run "$SCRIPT" --config-dir
  [ "$status" -eq 1 ]
  [[ "$output" == *"--config-dir requires an argument"* ]]
}

@test "scripts: --config-dir with missing dir exits with clear error" {
  run "$SCRIPT" --config-dir "$BATS_TEST_TMPDIR/no-such-dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"OpenCode config dir not found"* ]]
}

@test "scripts: --json with fixture emits dependency keys and summary" {
  write_fixture_config
  stub_dir="$BATS_TEST_TMPDIR/stubs-json"
  write_npm_stub "$stub_dir"

  PATH="$stub_dir:$PATH" run "$SCRIPT" --json --config-dir "$TMP_CFG"
  [ "$status" -eq 0 ]
  json_output="$output"

  echo "$json_output" | jq empty

  run bash -c "jq -r '.config_dir' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "$TMP_CFG" ]

  run bash -c "jq -r '.deps | length' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" -eq 4 ]

  run bash -c "jq -r '.summary.total' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "4" ]

  run bash -c "jq -r '.deps[] | select(.package == \"fake-pkg\") | .latest' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]

  run bash -c "jq -r '.deps[] | select(.package == \"@scope/tool\") | .unpinned' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "scripts: trailing-comma opencode.jsonc does not fail JSONC validation" {
  write_jsonc_fixture_config
  stub_dir="$BATS_TEST_TMPDIR/stubs-jsonc-trailing"
  write_npm_stub "$stub_dir"

  PATH="$stub_dir:$PATH" run "$SCRIPT" --json --config-dir "$TMP_CFG"
  [ "$status" -eq 0 ]
  [[ "$output" != *"not valid JSON (after JSONC strip)"* ]]

  json_output="$output"
  echo "$json_output" | jq empty
}

@test "scripts: selects opencode.jsonc when it is the only OpenCode config" {
  write_jsonc_fixture_config
  stub_dir="$BATS_TEST_TMPDIR/stubs-jsonc-only"
  write_npm_stub "$stub_dir"

  PATH="$stub_dir:$PATH" run "$SCRIPT" --json --config-dir "$TMP_CFG"
  [ "$status" -eq 0 ]
  json_output="$output"

  run bash -c "jq -r '.deps | length' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]

  run bash -c "jq -r '.deps[0].location' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "opencode.jsonc:plugin" ]
}

@test "scripts: prefers opencode.jsonc over opencode.json and reports jsonc location" {
  cat >"$TMP_CFG/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["another-fake-pkg@2.0.0"]
}
EOF

  write_jsonc_fixture_config
  stub_dir="$BATS_TEST_TMPDIR/stubs-jsonc-precedence"
  write_npm_stub "$stub_dir"

  PATH="$stub_dir:$PATH" run "$SCRIPT" --json --config-dir "$TMP_CFG"
  [ "$status" -eq 0 ]
  json_output="$output"

  run bash -c "jq -r '.deps[] | select(.package == \"fake-pkg\") | .location' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "opencode.jsonc:plugin" ]

  run bash -c "jq -r '.deps[] | select(.package == \"another-fake-pkg\") | .package' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "scripts: human output with fixture produces table" {
  write_fixture_config
  stub_dir="$BATS_TEST_TMPDIR/stubs-human"
  write_npm_stub "$stub_dir"

  PATH="$stub_dir:$PATH" run "$SCRIPT" --config-dir "$TMP_CFG"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OpenCode dependency check"* ]]
  [[ "$output" == *"PACKAGE"* ]]
  [[ "$output" == *"STATUS"* ]]
  [[ "$output" == *"fake-pkg"* ]]
  [[ "$output" == *"Summary:"* ]]
}

@test "scripts: common.sh exists and is sourceable" {
  [ -f "$COMMON" ]

  run bash -c "source '$COMMON'; type die >/dev/null; type warn >/dev/null; type require_cmd >/dev/null"
  [ "$status" -eq 0 ]
}
