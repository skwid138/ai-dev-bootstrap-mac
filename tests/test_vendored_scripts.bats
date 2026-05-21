#!/usr/bin/env bats
# Tests for vendored daemon helper scripts used by the Tailscale add-on.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT
}

vendored_scripts() {
  printf '%s\n' \
    "$REPO_ROOT/scripts/lib/keychain.sh" \
    "$REPO_ROOT/scripts/lib/opencode-daemon.sh" \
    "$REPO_ROOT/scripts/personal/opencode-web.sh" \
    "$REPO_ROOT/scripts/personal/opencode-attach.sh" \
    "$REPO_ROOT/scripts/personal/opensession.sh"
}

@test "vendored daemon scripts: expected files exist" {
  [ -f "$REPO_ROOT/scripts/lib/keychain.sh" ]
  [ -f "$REPO_ROOT/scripts/lib/opencode-daemon.sh" ]
  [ -f "$REPO_ROOT/scripts/personal/opencode-web.sh" ]
  [ -f "$REPO_ROOT/scripts/personal/opencode-attach.sh" ]
  [ -f "$REPO_ROOT/scripts/personal/opensession.sh" ]
}

@test "vendored daemon scripts: personal scripts are executable" {
  [ -x "$REPO_ROOT/scripts/personal/opencode-web.sh" ]
  [ -x "$REPO_ROOT/scripts/personal/opencode-attach.sh" ]
  [ -x "$REPO_ROOT/scripts/personal/opensession.sh" ]
}

@test "vendored daemon scripts: personal keychain fallback path is removed" {
  ! grep -Fq '_keychain_self="$HOME/code/scripts' "$REPO_ROOT/scripts/lib/keychain.sh"
}

@test "vendored daemon scripts: personal daemon fallback path is removed" {
  ! grep -Fq '_opencode_daemon_self="$HOME/code/scripts' "$REPO_ROOT/scripts/lib/opencode-daemon.sh"
}

@test "vendored daemon scripts: provenance records source commit" {
  [ -f "$REPO_ROOT/scripts/.provenance" ]
  grep -Fq "SOURCE_COMMIT=946d49a7c8090eb092ddf7fcdefaa3baa815a830" "$REPO_ROOT/scripts/.provenance"
}

@test "vendored daemon scripts: shell syntax is valid" {
  while IFS= read -r script; do
    run bash -n "$script"
    [ "$status" -eq 0 ]
  done < <(vendored_scripts)
}
