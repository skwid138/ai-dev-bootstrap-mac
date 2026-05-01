#!/usr/bin/env bats
# Helper-level tests for lib/ghostty.sh.
#
# These are pure file-IO tests with a sandboxed dest dir; no brew, no
# real ghostty. The module-level smoke (modules/03-terminal.sh) is
# covered separately by the existing CI lint/format gates and by manual
# smoke testing — we don't mock brew here because the helper has no
# CLI dependencies.

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/ghostty.sh
  source "${BOOTSTRAP_DIR}/lib/ghostty.sh"

  SANDBOX="$(mktemp -d)"
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

@test "ghostty_deploy_config: installs when destination missing" {
  src="${BOOTSTRAP_DIR}/ghostty/config.template"
  dest="$SANDBOX/.config/ghostty/config"

  run ghostty_deploy_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  [ -f "$dest" ]

  # Content matches template byte-for-byte.
  run diff -q "$src" "$dest"
  [ "$status" -eq 0 ]
}

@test "ghostty_deploy_config: skips when destination exists (overwrite-protect)" {
  # Same model as opencode_deploy_agents_md: we never stomp a file the
  # user may have edited.
  src="${BOOTSTRAP_DIR}/ghostty/config.template"
  dest="$SANDBOX/config"
  echo "user-customized content" >"$dest"

  run ghostty_deploy_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "skipped" ]

  # User content untouched.
  run cat "$dest"
  [ "$output" = "user-customized content" ]
}

@test "ghostty_deploy_config: errors when source missing" {
  run ghostty_deploy_config "$SANDBOX/does-not-exist" "$SANDBOX/dest"
  [ "$status" -eq 1 ]
  [[ "$output" == *"source not found"* ]]
}

@test "ghostty_deploy_config: creates parent directory if missing" {
  # ~/.config/ghostty/ may not exist on a fresh Mac; the helper must
  # create it rather than fail.
  src="${BOOTSTRAP_DIR}/ghostty/config.template"
  dest="$SANDBOX/deeply/nested/never/existed/config"

  run ghostty_deploy_config "$src" "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "installed" ]
  [ -f "$dest" ]
}

@test "ghostty/config.template: references the font we install" {
  # Catch drift: if someone changes the cask in modules/03-terminal.sh
  # without updating the template (or vice versa), this test trips.
  template="${BOOTSTRAP_DIR}/ghostty/config.template"
  module="${BOOTSTRAP_DIR}/modules/03-terminal.sh"

  grep -q "font-family = JetBrainsMono Nerd Font" "$template"
  grep -q "font-jetbrains-mono-nerd-font" "$module"
}

@test "ghostty/config.template: theme is set to a known ghostty default" {
  # We picked GruvboxDark because it ships with ghostty (no extra
  # download). If someone changes the default, they should at least
  # leave a 'theme = ' line so the user gets a deliberate look.
  template="${BOOTSTRAP_DIR}/ghostty/config.template"
  grep -q "^theme = " "$template"
}

@test "ghostty/config.template: contains no Wpromote/internal references" {
  # Same hygiene as the opencode assets — this template is going to
  # non-techy users; nothing personal or company-internal should leak.
  template="${BOOTSTRAP_DIR}/ghostty/config.template"
  run grep -iE "wpromote|hunter|/Users/[a-z]+|fun forrest" "$template"
  [ "$status" -ne 0 ]
}
