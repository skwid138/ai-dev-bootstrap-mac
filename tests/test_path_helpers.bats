#!/usr/bin/env bats
# Tests for dotfiles/lib/path_helpers.zsh — _path_prepend with promotion
# semantics. Sourced and executed by zsh (not bash); we shell out to
# `zsh -c` for each assertion to keep the test process isolated from
# helper state and to exercise the helper in its real shell dialect.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  HELPER="${BOOTSTRAP_DIR}/dotfiles/lib/path_helpers.zsh"

  # Sandbox PATH-eligible dirs. _path_prepend skips non-existent paths,
  # so the tests need real directories on disk.
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX/brew/bin" "$SANDBOX/brew/sbin" "$SANDBOX/extra/bin"
  export SANDBOX
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# Run a zsh snippet with the helper sourced. PATH is set explicitly per
# test; we never inherit the developer's PATH.
zsh_with_helper() {
  local initial_path="$1"
  local snippet="$2"
  zsh -c "
    source '${HELPER}'
    PATH='${initial_path}'
    ${snippet}
  "
}

@test "_path_prepend: missing dir on disk -> silent no-op, PATH unchanged" {
  run zsh_with_helper "/usr/bin:/bin" '
    _path_prepend "/this/path/does/not/exist"
    print -r -- "$PATH"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "/usr/bin:/bin" ]
}

@test "_path_prepend: empty arg -> silent no-op" {
  run zsh_with_helper "/usr/bin:/bin" '
    _path_prepend ""
    print -r -- "$PATH"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "/usr/bin:/bin" ]
}

@test "_path_prepend: dir absent from PATH -> prepended" {
  run zsh_with_helper "/usr/bin:/bin" "
    _path_prepend '${SANDBOX}/brew/bin'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${SANDBOX}/brew/bin:/usr/bin:/bin" ]
}

@test "_path_prepend: dir already at front -> no-op (PATH unchanged byte-for-byte)" {
  run zsh_with_helper "${SANDBOX}/brew/bin:/usr/bin:/bin" "
    _path_prepend '${SANDBOX}/brew/bin'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${SANDBOX}/brew/bin:/usr/bin:/bin" ]
}

@test "_path_prepend: dir present mid-PATH -> promoted to front (path_helper recovery)" {
  # This is the exact scenario macOS path_helper produces:
  # /opt/homebrew/bin gets demoted below /usr/bin between .zshenv and .zprofile.
  run zsh_with_helper "/usr/bin:/bin:${SANDBOX}/brew/bin:/sbin" "
    _path_prepend '${SANDBOX}/brew/bin'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${SANDBOX}/brew/bin:/usr/bin:/bin:/sbin" ]
}

@test "_path_prepend: dir present at end of PATH -> promoted to front" {
  run zsh_with_helper "/usr/bin:/bin:${SANDBOX}/brew/bin" "
    _path_prepend '${SANDBOX}/brew/bin'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${SANDBOX}/brew/bin:/usr/bin:/bin" ]
}

@test "_path_prepend: called twice with same dir -> no duplicate entries" {
  run zsh_with_helper "/usr/bin:/bin" "
    _path_prepend '${SANDBOX}/brew/bin'
    _path_prepend '${SANDBOX}/brew/bin'
    # Count occurrences in PATH.
    local n=\${#\${(s.:.)PATH}}
    print -r -- \"\$PATH | count=\$(echo \"\$PATH\" | tr ':' '\n' | grep -c \"^${SANDBOX}/brew/bin\$\")\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"count=1"* ]]
  [[ "$output" == "${SANDBOX}/brew/bin:/usr/bin:/bin"* ]]
}

@test "_path_prepend: preserves order of unrelated entries during promotion" {
  run zsh_with_helper "/a:/b:${SANDBOX}/brew/bin:/c:/d" "
    _path_prepend '${SANDBOX}/brew/bin'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${SANDBOX}/brew/bin:/a:/b:/c:/d" ]
}

@test "_path_prepend: promotes correctly when dir is at second position" {
  run zsh_with_helper "/usr/bin:${SANDBOX}/brew/bin:/bin" "
    _path_prepend '${SANDBOX}/brew/bin'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${SANDBOX}/brew/bin:/usr/bin:/bin" ]
}

@test "_path_prepend: works in non-interactive subshell" {
  # Already exercised by every other test (zsh -c is non-interactive),
  # but explicit assertion for the contract.
  run zsh -c "
    [[ -o interactive ]] && exit 99
    source '${HELPER}'
    PATH='/usr/bin'
    _path_prepend '${SANDBOX}/brew/bin'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${SANDBOX}/brew/bin:/usr/bin" ]
}

@test "_path_prepend: nounset-safe — works under setopt nounset with PATH set" {
  # rev-4 G1 contract. Sentinels and PATH reads must use ${var:-} form
  # so the helper is callable from set -u contexts (test harnesses,
  # future module integrations).
  run zsh -c "
    setopt nounset
    source '${HELPER}'
    PATH='/usr/bin'
    _path_prepend '${SANDBOX}/brew/bin'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "${SANDBOX}/brew/bin:/usr/bin" ]
}

@test "_path_prepend: nounset-safe — does not error when called with empty string under nounset" {
  run zsh -c "
    setopt nounset
    source '${HELPER}'
    PATH='/usr/bin'
    _path_prepend ''
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "/usr/bin" ]
}

@test "path_helpers.zsh: sentinel-guarded against double-source" {
  # Re-sourcing should not redefine the helper or error.
  run zsh -c "
    source '${HELPER}'
    source '${HELPER}'
    [[ -n \"\${_AI_BOOTSTRAP_PATH_HELPERS_LOADED:-}\" ]] || exit 1
    typeset -f _path_prepend >/dev/null || exit 2
    print 'OK'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "path_helpers.zsh: silent on stdout AND stderr when sourced" {
  # Env-tier silence contract — see init_env.zsh header.
  run zsh -c "
    source '${HELPER}'
  "
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
