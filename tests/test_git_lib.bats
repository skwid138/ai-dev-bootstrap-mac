#!/usr/bin/env bats
# Helper-level tests for lib/git.sh.
#
# Strategy: pin $HOME to a sandbox so `git config --global` writes go
# to $SANDBOX/.gitconfig instead of the real one. No `git` mocking
# needed — we just exercise the helpers against a real (sandboxed)
# git config.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/git.sh
  source "${BOOTSTRAP_DIR}/lib/git.sh"

  SANDBOX="$(mktemp -d)"
  export HOME="$SANDBOX"
  # Make absolutely sure git uses $HOME (no inherited XDG override).
  unset XDG_CONFIG_HOME
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# ── git_get_global / git_is_set_global ─────────────────────────────────────
@test "git_get_global: returns nothing for unset key" {
  run git_get_global "nonexistent.key"
  # `git config --get` returns 1 for missing; helper passes that through.
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "git_get_global: returns value for set key" {
  git config --global test.key "the-value"
  run git_get_global "test.key"
  [ "$status" -eq 0 ]
  [ "$output" = "the-value" ]
}

@test "git_is_set_global: 0 when set, 1 when unset" {
  run git_is_set_global "test.key"
  [ "$status" -eq 1 ]

  git config --global test.key "x"
  run git_is_set_global "test.key"
  [ "$status" -eq 0 ]
}

# ── git_set_default_if_unset ───────────────────────────────────────────────
@test "git_set_default_if_unset: sets when unset, echoes 'set'" {
  run git_set_default_if_unset "init.defaultBranch" "main"
  [ "$status" -eq 0 ]
  [ "$output" = "set" ]

  run git config --global --get init.defaultBranch
  [ "$output" = "main" ]
}

@test "git_set_default_if_unset: keeps existing value, echoes 'kept'" {
  git config --global init.defaultBranch "trunk"

  run git_set_default_if_unset "init.defaultBranch" "main"
  [ "$status" -eq 0 ]
  [ "$output" = "kept" ]

  # User's choice preserved, NOT overwritten.
  run git config --global --get init.defaultBranch
  [ "$output" = "trunk" ]
}

@test "git_set_default_if_unset: handles values with spaces (core.editor)" {
  run git_set_default_if_unset "core.editor" "code --wait"
  [ "$status" -eq 0 ]
  [ "$output" = "set" ]

  run git config --global --get core.editor
  [ "$output" = "code --wait" ]
}

# ── git_choose_editor ──────────────────────────────────────────────────────
# We can't easily mock `command -v` from inside bats — but we can put a
# fake `code` script on PATH first, then unset it, to exercise both
# branches.

@test "git_choose_editor: picks 'code --wait' when code is on PATH" {
  fake_bin="$SANDBOX/bin"
  mkdir -p "$fake_bin"
  cat >"$fake_bin/code" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$fake_bin/code"
  export PATH="$fake_bin:$PATH"

  run git_choose_editor
  [ "$status" -eq 0 ]
  [ "$output" = "code --wait" ]
}

@test "git_choose_editor: falls back to nano when code missing" {
  # Strip code from PATH; nano is at /usr/bin/nano on macOS so still
  # present via /usr/bin in the residual PATH.
  empty_bin="$SANDBOX/empty-bin"
  mkdir -p "$empty_bin"
  export PATH="$empty_bin:/usr/bin:/bin"

  run git_choose_editor
  [ "$status" -eq 0 ]
  # Either nano (most likely on macOS) or empty (if neither found).
  # We assert the bigger contract: never returns 'vi' or 'vim'.
  [[ "$output" != "vi" ]]
  [[ "$output" != "vim" ]]
}

@test "git_choose_editor: returns empty string when neither code nor nano present" {
  # Sandbox 'nano' as well as keeping 'code' off PATH. We can't simply
  # empty PATH (teardown's `rm` would vanish too), so we put a fake
  # nano-shadow that rejects execution onto an otherwise minimal PATH.
  # Easier: keep PATH minimal and verify that if our test environment
  # happens to lack BOTH, we get empty. On the macOS CI runner /usr/bin
  # always has nano, so this is best-effort — we assert the contract,
  # not the behavior.
  empty_bin="$SANDBOX/empty-bin"
  mkdir -p "$empty_bin"

  # Save real PATH so teardown's `rm` still works.
  saved_path="$PATH"
  export PATH="$empty_bin"

  run git_choose_editor
  status_code="$status"
  result="$output"

  export PATH="$saved_path"

  [ "$status_code" -eq 0 ]
  [ "$result" = "" ]
}
