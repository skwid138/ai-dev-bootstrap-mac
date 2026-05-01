#!/usr/bin/env bats
# Helper-level tests for lib/workspace.sh.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/workspace.sh
  source "${BOOTSTRAP_DIR}/lib/workspace.sh"

  SANDBOX="$(mktemp -d)"
  # Pin HOME for tests that touch $HOME so we don't pollute the real one.
  export HOME="$SANDBOX"
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# ── workspace_default_path ─────────────────────────────────────────────────
@test "workspace_default_path: returns \$HOME/code" {
  run workspace_default_path
  [ "$status" -eq 0 ]
  [ "$output" = "$SANDBOX/code" ]
}

# ── workspace_expand_path ──────────────────────────────────────────────────
@test "workspace_expand_path: ~/foo -> \$HOME/foo" {
  # We INTENTIONALLY pass the literal '~/projects' string — the whole
  # point of this helper is to expand it for us. Shellcheck's SC2088
  # warning doesn't apply (it warns when you expect bash to expand a
  # quoted tilde, which we explicitly don't).
  # shellcheck disable=SC2088
  run workspace_expand_path "~/projects"
  [ "$status" -eq 0 ]
  [ "$output" = "$SANDBOX/projects" ]
}

@test "workspace_expand_path: bare ~ -> \$HOME" {
  # shellcheck disable=SC2088
  run workspace_expand_path "~"
  [ "$status" -eq 0 ]
  [ "$output" = "$SANDBOX" ]
}

@test "workspace_expand_path: absolute path -> unchanged" {
  run workspace_expand_path "/Users/someone/code"
  [ "$status" -eq 0 ]
  [ "$output" = "/Users/someone/code" ]
}

@test "workspace_expand_path: relative path -> unchanged (caller decides)" {
  run workspace_expand_path "projects"
  [ "$status" -eq 0 ]
  [ "$output" = "projects" ]
}

@test "workspace_expand_path: does not eval shell (security)" {
  # If we ever switch to eval, this input would print "PWNED". With the
  # current string-op approach the literal stays a literal.
  run workspace_expand_path '$(echo PWNED)'
  [ "$status" -eq 0 ]
  [ "$output" = '$(echo PWNED)' ]
}

# ── workspace_validate_path ────────────────────────────────────────────────
@test "workspace_validate_path: accepts a normal absolute path" {
  run workspace_validate_path "/Users/me/code"
  [ "$status" -eq 0 ]
}

@test "workspace_validate_path: rejects empty string" {
  run workspace_validate_path ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty"* ]]
}

@test "workspace_validate_path: rejects relative path" {
  run workspace_validate_path "code"
  [ "$status" -eq 1 ]
  [[ "$output" == *"absolute"* ]]
}

@test "workspace_validate_path: rejects path with spaces" {
  # Lots of CLI tooling breaks subtly on spaces (and a non-techy user
  # picking 'My Projects' would find their workflow weird later).
  run workspace_validate_path "/Users/me/My Projects"
  [ "$status" -eq 1 ]
  [[ "$output" == *"spaces"* ]]
}

@test "workspace_validate_path: rejects /" {
  run workspace_validate_path "/"
  [ "$status" -eq 1 ]
}

@test "workspace_validate_path: rejects bare \$HOME" {
  run workspace_validate_path "$HOME"
  [ "$status" -eq 1 ]
}

# ── workspace_ensure_dir ───────────────────────────────────────────────────
@test "workspace_ensure_dir: creates dir when missing" {
  target="$SANDBOX/code"
  [ ! -d "$target" ]

  run workspace_ensure_dir "$target"
  [ "$status" -eq 0 ]
  [ -d "$target" ]
}

@test "workspace_ensure_dir: idempotent when dir already exists" {
  target="$SANDBOX/code"
  mkdir -p "$target"
  echo "user content" >"$target/keep.txt"

  run workspace_ensure_dir "$target"
  [ "$status" -eq 0 ]
  [ -f "$target/keep.txt" ]
}

@test "workspace_ensure_dir: creates nested path" {
  target="$SANDBOX/deeply/nested/never/existed"
  run workspace_ensure_dir "$target"
  [ "$status" -eq 0 ]
  [ -d "$target" ]
}

# ── workspace_write_state + workspace_read_state ───────────────────────────
@test "workspace_write_state: writes a sourceable state file" {
  state_file="$SANDBOX/.config/ai-bootstrap/state.sh"
  run workspace_write_state "$state_file" "$SANDBOX/code"
  [ "$status" -eq 0 ]
  [ -f "$state_file" ]

  # Verify it's actually sourceable + sets the right var.
  ws=$(
    # shellcheck disable=SC1090
    source "$state_file"
    echo "$AI_BOOTSTRAP_WORKSPACE"
  )
  [ "$ws" = "$SANDBOX/code" ]
}

@test "workspace_write_state: creates parent directory" {
  state_file="$SANDBOX/never/before/state.sh"
  run workspace_write_state "$state_file" "$SANDBOX/code"
  [ "$status" -eq 0 ]
  [ -f "$state_file" ]
}

@test "workspace_write_state: overwrites existing state file" {
  state_file="$SANDBOX/state.sh"
  workspace_write_state "$state_file" "$SANDBOX/code-old"
  workspace_write_state "$state_file" "$SANDBOX/code-new"

  ws=$(
    # shellcheck disable=SC1090
    source "$state_file"
    echo "$AI_BOOTSTRAP_WORKSPACE"
  )
  [ "$ws" = "$SANDBOX/code-new" ]
}

@test "workspace_read_state: returns 1 when state file missing" {
  run workspace_read_state "$SANDBOX/no-such-file.sh"
  [ "$status" -eq 1 ]
}

@test "workspace_read_state: round-trips a written state file" {
  state_file="$SANDBOX/state.sh"
  workspace_write_state "$state_file" "$SANDBOX/code"

  run workspace_read_state "$state_file"
  [ "$status" -eq 0 ]
  [ "$output" = "$SANDBOX/code" ]
}

@test "workspace_read_state: does not leak vars to caller" {
  # Verify we run the source in a subshell — caller's env stays clean.
  state_file="$SANDBOX/state.sh"
  workspace_write_state "$state_file" "$SANDBOX/code"

  unset AI_BOOTSTRAP_WORKSPACE
  workspace_read_state "$state_file" >/dev/null
  [ -z "${AI_BOOTSTRAP_WORKSPACE:-}" ]
}
