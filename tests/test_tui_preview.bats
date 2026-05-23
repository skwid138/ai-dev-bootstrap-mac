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
  mkdir -p "$target/scripts/lib" "$target/opencode/plugins"
  cp "$SCRIPT" "$target/scripts/tui-preview.sh"
  cp "$COMMON" "$target/scripts/lib/common.sh"
  chmod +x "$target/scripts/tui-preview.sh"
}

write_opencode_stub() {
  local stub_dir="$1"
  local log_file="$2"
  mkdir -p "$stub_dir"
  cat >"$stub_dir/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${OPENCODE_STUB_LOG:?}"

{
  printf 'pwd=%s\n' "$PWD"
  test -d .opencode/plugins
  test -f .opencode/plugins/alpha.tsx
  test -f .opencode/plugins/beta.tsx
  test -f .opencode/tui.json
  jq -e '.theme == "flamingo-ember"' .opencode/tui.json >/dev/null
  jq -e '.plugin == [["./plugins/alpha.tsx", {}], ["./plugins/beta.tsx", {}]]' .opencode/tui.json >/dev/null
  printf 'ok\n'
} >"$OPENCODE_STUB_LOG"
EOF
  chmod +x "$stub_dir/opencode"
  export OPENCODE_STUB_LOG="$log_file"
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
  [[ "$output" == *"isolated temporary directory"* ]]
}

@test "tui-preview: fails gracefully when no plugins exist" {
  preview_repo="$TMP_DIR/preview-empty"
  stub_dir="$TMP_DIR/stubs-empty"
  copy_preview_repo "$preview_repo"
  write_opencode_stub "$stub_dir" "$TMP_DIR/unused.log"

  PATH="$stub_dir:$PATH" run "$preview_repo/scripts/tui-preview.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no TSX plugins found in $preview_repo/opencode/plugins"* ]]
}

@test "tui-preview: fails gracefully when opencode is not on PATH" {
  preview_repo="$TMP_DIR/preview-missing-opencode"
  clean_path="$TMP_DIR/path-without-opencode"
  copy_preview_repo "$preview_repo"

  cat >"$preview_repo/opencode/plugins/alpha.tsx" <<'EOF'
export default { id: "alpha" }
EOF

  mkdir -p "$clean_path"
  ln -s "$(command -v dirname)" "$clean_path/dirname"

  PATH="$clean_path" run "$(command -v bash)" "$preview_repo/scripts/tui-preview.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing dependency: 'opencode' is required but not found."* ]]
}

@test "tui-preview: creates isolated temp OpenCode plugin structure" {
  preview_repo="$TMP_DIR/preview-with-plugins"
  stub_dir="$TMP_DIR/stubs-with-plugins"
  stub_log="$TMP_DIR/opencode-stub.log"
  copy_preview_repo "$preview_repo"
  write_opencode_stub "$stub_dir" "$stub_log"

  cat >"$preview_repo/opencode/plugins/alpha.tsx" <<'EOF'
export default { id: "alpha" }
EOF
  cat >"$preview_repo/opencode/plugins/beta.tsx" <<'EOF'
export default { id: "beta" }
EOF

  PATH="$stub_dir:$PATH" run "$preview_repo/scripts/tui-preview.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Starting OpenCode TUI preview in isolated temp directory"* ]]

  [ -f "$stub_log" ]
  run grep -F "ok" "$stub_log"
  [ "$status" -eq 0 ]
  run grep -E '^pwd=.*/opencode-tui-preview\.' "$stub_log"
  [ "$status" -eq 0 ]
}
