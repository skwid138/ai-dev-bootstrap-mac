#!/usr/bin/env bats
# Tests for scripts/tui-preview.sh.

bats_require_minimum_version 1.5.0

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env

  SCRIPT="${BOOTSTRAP_DIR}/scripts/tui-preview.sh"
  COMMON="${BOOTSTRAP_DIR}/scripts/lib/common.sh"
  export SCRIPT COMMON
}

teardown() {
  teardown_test_env
}

copy_preview_repo() {
  local target="$1"
  mkdir -p "$target/scripts/lib" "$target/opencode"
  cp "$SCRIPT" "$target/scripts/tui-preview.sh"
  cp "$COMMON" "$target/scripts/lib/common.sh"
  cp "${BOOTSTRAP_DIR}/opencode/tui.json.template" "$target/opencode/tui.json.template"
  chmod +x "$target/scripts/tui-preview.sh"
}

write_opencode_stub() {
  local stub_dir="$1"
  local log_file="$2"
  local expected_plugin_spec="${3:-@skwid138/opencode-tui@1.1.1}"
  local expected_logo_rows="${4:-6}"
  mkdir -p "$stub_dir"
  cat >"$stub_dir/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${OPENCODE_STUB_LOG:?}"
: "${OPENCODE_STUB_EXPECTED_PLUGIN_SPEC:?}"
: "${OPENCODE_STUB_EXPECTED_LOGO_ROWS:?}"

{
  printf 'pwd=%s\n' "$PWD"
  test -f .opencode/tui.json
  jq -e '.theme == "flamingo-ember"' .opencode/tui.json >/dev/null
  jq --arg expected "$OPENCODE_STUB_EXPECTED_PLUGIN_SPEC" -e '.plugin as $p | ($p | length) == 1 and $p[0][0] == $expected' .opencode/tui.json >/dev/null
  if [ "$OPENCODE_STUB_EXPECTED_LOGO_ROWS" -gt 0 ]; then
    jq --argjson expected_rows "$OPENCODE_STUB_EXPECTED_LOGO_ROWS" -e '(.plugin[0][1].logo.rows | length) == $expected_rows' .opencode/tui.json >/dev/null
  else
    jq -e '.plugin[0][1] == {}' .opencode/tui.json >/dev/null
  fi
  printf 'logo_rows=%s\n' "$(jq -r '(.plugin[0][1].logo.rows // []) | length' .opencode/tui.json)"
  printf 'ok\n'
} >"$OPENCODE_STUB_LOG"
EOF
  chmod +x "$stub_dir/opencode"
  export OPENCODE_STUB_LOG="$log_file"
  export OPENCODE_STUB_EXPECTED_PLUGIN_SPEC="$expected_plugin_spec"
  export OPENCODE_STUB_EXPECTED_LOGO_ROWS="$expected_logo_rows"
}

@test "tui-preview: script exists, is executable, and passes bash syntax check" {
  [ -x "$SCRIPT" ]
  bash -n "$SCRIPT"
}

@test "tui-preview: passes shellcheck" {
  command -v shellcheck >/dev/null 2>&1 || skip "shellcheck not installed"

  run shellcheck "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "tui-preview: common dependency is sourceable" {
  run bash -c "source '$COMMON'; type die_usage >/dev/null; type require_cmd >/dev/null; type info >/dev/null"
  [ "$status" -eq 0 ]
}

@test "tui-preview: --help exits 0 and prints usage" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: tui-preview.sh"* ]]
  [[ "$output" == *"--local [path]"* ]]
  [[ "$output" == *"isolated temporary directory"* ]]
  [[ "$output" == *"@skwid138/opencode-tui"* ]]
}

@test "tui-preview: fails gracefully when opencode is not on PATH" {
  preview_repo="$TMP_DIR/preview-missing-opencode"
  clean_path="$TMP_DIR/path-without-opencode"
  copy_preview_repo "$preview_repo"

  mkdir -p "$clean_path"
  ln -s "$(command -v dirname)" "$clean_path/dirname"

  PATH="$clean_path" run "$(command -v bash)" "$preview_repo/scripts/tui-preview.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing dependency: 'opencode' is required but not found."* ]]
}

@test "tui-preview: creates isolated temp OpenCode config with npm plugin reference" {
  preview_repo="$TMP_DIR/preview-with-npm-plugin"
  stub_dir="$TMP_DIR/stubs-with-npm-plugin"
  stub_log="$TMP_DIR/opencode-stub.log"
  copy_preview_repo "$preview_repo"
  write_opencode_stub "$stub_dir" "$stub_log"

  PATH="$stub_dir:$PATH" run "$preview_repo/scripts/tui-preview.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Starting OpenCode TUI preview with @skwid138/opencode-tui@1.1.1 in isolated temp directory"* ]]

  [ -f "$stub_log" ]
  run grep -F "ok" "$stub_log"
  [ "$status" -eq 0 ]
  run grep -F "logo_rows=6" "$stub_log"
  [ "$status" -eq 0 ]
  run grep -E '^pwd=.*/opencode-tui-preview\.' "$stub_log"
  [ "$status" -eq 0 ]
}

@test "--local with absolute path uses that path" {
  preview_repo="$TMP_DIR/preview-with-absolute-local"
  stub_dir="$TMP_DIR/stubs-with-absolute-local"
  stub_log="$TMP_DIR/opencode-stub.log"
  local_plugin="$TMP_DIR/local-tui.js"
  copy_preview_repo "$preview_repo"
  printf '%s\n' '// fake local plugin' >"$local_plugin"
  write_opencode_stub "$stub_dir" "$stub_log" "$local_plugin"

  PATH="$stub_dir:$PATH" run "$preview_repo/scripts/tui-preview.sh" --local "$local_plugin"

  [ "$status" -eq 0 ]
  [ -f "$stub_log" ]
  run grep -F "ok" "$stub_log"
  [ "$status" -eq 0 ]
  run grep -F "logo_rows=6" "$stub_log"
  [ "$status" -eq 0 ]
}

@test "--local with relative path resolves to absolute" {
  preview_repo="$TMP_DIR/preview-with-relative-local"
  stub_dir="$TMP_DIR/stubs-with-relative-local"
  stub_log="$TMP_DIR/opencode-stub.log"
  copy_preview_repo "$preview_repo"
  mkdir -p "$preview_repo/subdir"
  printf '%s\n' '// fake local plugin' >"$preview_repo/subdir/fake.js"
  write_opencode_stub "$stub_dir" "$stub_log" "$preview_repo/subdir/fake.js"

  cd "$preview_repo"
  PATH="$stub_dir:$PATH" run "$preview_repo/scripts/tui-preview.sh" --local ./subdir/fake.js

  [ "$status" -eq 0 ]
  [ -f "$stub_log" ]
  run grep -F "ok" "$stub_log"
  [ "$status" -eq 0 ]
}

@test "tui-preview: malformed shipped template falls back to empty plugin config" {
  preview_repo="$TMP_DIR/preview-with-malformed-template"
  stub_dir="$TMP_DIR/stubs-with-malformed-template"
  stub_log="$TMP_DIR/opencode-stub.log"
  copy_preview_repo "$preview_repo"
  printf '%s\n' '{ bad json' >"$preview_repo/opencode/tui.json.template"
  write_opencode_stub "$stub_dir" "$stub_log" "@skwid138/opencode-tui@1.1.1" 0

  PATH="$stub_dir:$PATH" run "$preview_repo/scripts/tui-preview.sh"

  [ "$status" -eq 0 ]
  [ -f "$stub_log" ]
  run grep -F "logo_rows=0" "$stub_log"
  [ "$status" -eq 0 ]
  run grep -F "ok" "$stub_log"
  [ "$status" -eq 0 ]
}

@test "--local with nonexistent file fails" {
  preview_repo="$TMP_DIR/preview-with-missing-local"
  copy_preview_repo "$preview_repo"

  run "$preview_repo/scripts/tui-preview.sh" --local "$TMP_DIR/no-such-file.js"

  [ "$status" -ne 0 ]
  [[ "$output" == *"not found or not readable"* ]]
}

@test "--local with nonexistent parent directory fails" {
  preview_repo="$TMP_DIR/preview-with-missing-local-parent"
  copy_preview_repo "$preview_repo"

  cd "$preview_repo"
  run "$preview_repo/scripts/tui-preview.sh" --local ./no-such-dir/file.js

  [ "$status" -ne 0 ]
  [[ "$output" == *"Cannot resolve path"* ]]
}

@test "--local without arg uses default path (missing)" {
  preview_repo="$TMP_DIR/preview-with-default-local"
  copy_preview_repo "$preview_repo"

  HOME="$TMP_DIR/home-without-default-local" run "$preview_repo/scripts/tui-preview.sh" --local

  [ "$status" -ne 0 ]
  [[ "$output" == *"not found or not readable"* ]]
}

@test "--local with unreadable file fails" {
  [ "$(id -u)" -ne 0 ] || skip "root can read chmod 000 files"

  preview_repo="$TMP_DIR/preview-with-unreadable-local"
  local_plugin="$TMP_DIR/unreadable-tui.js"
  copy_preview_repo "$preview_repo"
  printf '%s\n' '// fake local plugin' >"$local_plugin"
  chmod 000 "$local_plugin"

  run "$preview_repo/scripts/tui-preview.sh" --local "$local_plugin"

  [ "$status" -ne 0 ]
  [[ "$output" == *"not found or not readable"* ]]
}
