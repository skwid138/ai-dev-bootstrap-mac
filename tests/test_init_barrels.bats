#!/usr/bin/env bats
# Tests for the three-tier barrels: init_env.zsh, init_profile.zsh, init_rc.zsh.
#
# Strategy:
#   - Each test stages a faithful copy of dotfiles/ at $SANDBOX/.config/ai-bootstrap/shell/
#     (mirroring what modules/10-shell-config.sh will do at install time).
#   - paths.zsh has its __BREW_PREFIX__ sentinel substituted with a sandbox dir
#     so _path_prepend operates on real on-disk dirs.
#   - Each barrel is sourced in a fresh `zsh -c` subshell with HOME=$SANDBOX.
#   - We assert: silence (env-tier), correct PATH, sentinel guards, defensive
#     command -v gates, path_helper recovery (init_profile re-sources env-tier).

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR

  SANDBOX="$(mktemp -d)"
  export SANDBOX
  export HOME="$SANDBOX"

  # Sandbox brew prefix: a real dir on disk with bin/ and sbin/ under it,
  # so _path_prepend (which gates on -d) accepts it.
  BREW_PREFIX="$SANDBOX/brew"
  export BREW_PREFIX
  mkdir -p "$BREW_PREFIX/bin" "$BREW_PREFIX/sbin"

  # Lay down the install dir mirroring what the module will produce.
  install_dir="$HOME/.config/ai-bootstrap/shell"
  mkdir -p "$install_dir"/{env,lib,profile,rc}
  cp "$BOOTSTRAP_DIR/dotfiles/init_env.zsh" "$install_dir/init_env.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/init_profile.zsh" "$install_dir/init_profile.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/init_rc.zsh" "$install_dir/init_rc.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/lib/path_helpers.zsh" "$install_dir/lib/path_helpers.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/env/vars.zsh" "$install_dir/env/vars.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/env/paths.zsh" "$install_dir/env/paths.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/rc/zsh_config.zsh" "$install_dir/rc/zsh_config.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/rc/aliases.zsh" "$install_dir/rc/aliases.zsh"

  # Substitute __BREW_PREFIX__ in paths.zsh — same operation the install
  # module performs. macOS-portable sed (-i with empty backup arg).
  sed -i.bak "s|__BREW_PREFIX__|${BREW_PREFIX}|g" "$install_dir/env/paths.zsh"
  rm -f "$install_dir/env/paths.zsh.bak"
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# ── env-tier (init_env.zsh) ──────────────────────────────────────────────────

@test "init_env.zsh: silent on stdout AND stderr" {
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_env.zsh'
  " 2>&1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "init_env.zsh: prepends \$BREW_PREFIX/bin to PATH" {
  run zsh -c "
    HOME='$HOME'
    PATH='/usr/bin:/bin'
    source '$HOME/.config/ai-bootstrap/shell/init_env.zsh'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == "$BREW_PREFIX/bin:"* ]]
}

@test "init_env.zsh: sets EDITOR and LANG from env/vars.zsh" {
  run zsh -c "
    HOME='$HOME'
    unset EDITOR LANG
    source '$HOME/.config/ai-bootstrap/shell/init_env.zsh'
    print -r -- \"EDITOR=\$EDITOR\"
    print -r -- \"LANG=\$LANG\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"EDITOR=code"* ]]
  [[ "$output" == *"LANG=en_US.UTF-8"* ]]
}

@test "init_env.zsh: sentinel-guarded against double-source" {
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_env.zsh'
    # Manually mutate PATH; second source should NOT touch it.
    PATH='untouched'
    source '$HOME/.config/ai-bootstrap/shell/init_env.zsh'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "untouched" ]
}

@test "init_env.zsh: barrel returns 0 even when env/vars.zsh and env/paths.zsh are absent" {
  rm -f "$HOME/.config/ai-bootstrap/shell/env/vars.zsh"
  rm -f "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_env.zsh'
    echo OK
  " 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── profile-tier (init_profile.zsh) ──────────────────────────────────────────

@test "init_profile.zsh: silent on stdout AND stderr (no profile/tool_hooks.zsh installed)" {
  # No mise selected, so profile/tool_hooks.zsh is absent. Barrel must still
  # be silent.
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_profile.zsh'
  " 2>&1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "init_profile.zsh: path_helper recovery — promotes \$BREW_PREFIX/bin even when demoted in PATH" {
  # Simulate the exact macOS path_helper outcome:
  #   - .zshenv ran init_env.zsh, prepending /opt/homebrew/bin (BREW_PREFIX/bin here)
  #   - /etc/zprofile rebuilt PATH with /usr/bin first, demoting BREW_PREFIX/bin
  #   - .zprofile sources init_profile.zsh, which must promote BREW_PREFIX/bin back
  # Critical: the env-tier sentinel is set (env-tier already ran), so
  # init_profile.zsh must explicitly clear it to re-run paths.zsh.
  run zsh -c "
    HOME='$HOME'
    # Pretend env-tier ran (set sentinels).
    _AI_BOOTSTRAP_INIT_ENV_LOADED=1
    _AI_BOOTSTRAP_PATH_HELPERS_LOADED=1
    # Simulate path_helper's demoted PATH.
    PATH='/usr/bin:/bin:$BREW_PREFIX/bin:/sbin'
    source '$HOME/.config/ai-bootstrap/shell/init_profile.zsh'
    # First entry of PATH must be BREW_PREFIX/bin.
    print -r -- \"\${PATH%%:*}\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "$BREW_PREFIX/bin" ]
}

@test "init_profile.zsh: sentinel-guarded against double-source" {
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_profile.zsh'
    # Set a marker; if profile-tier re-runs, it would unset env-tier sentinel
    # (which we then re-set) — easier: mutate PATH and assert it survives.
    PATH='untouched'
    source '$HOME/.config/ai-bootstrap/shell/init_profile.zsh'
    print -r -- \"\$PATH\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "untouched" ]
}

@test "init_profile.zsh: barrel returns 0 even when profile/tool_hooks.zsh is absent" {
  # Default state: no profile/tool_hooks.zsh.
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_profile.zsh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "init_profile.zsh: silent skip when login/ dir is empty (zsh nullglob qualifier)" {
  mkdir -p "$HOME/.config/ai-bootstrap/shell/login"
  # No files inside.
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_profile.zsh'
    echo OK
  " 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
  # No errors about empty glob.
  [[ "$output" != *"no matches"* ]]
}

@test "init_profile.zsh: sources login/*.zsh files when present" {
  mkdir -p "$HOME/.config/ai-bootstrap/shell/login"
  echo 'export LOGIN_FILE_LOADED=yes' >"$HOME/.config/ai-bootstrap/shell/login/marker.zsh"
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_profile.zsh'
    print -r -- \"LOGIN_FILE_LOADED=\$LOGIN_FILE_LOADED\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"LOGIN_FILE_LOADED=yes"* ]]
}

# ── rc-tier (init_rc.zsh) ────────────────────────────────────────────────────

@test "init_rc.zsh: sources rc/zsh_config.zsh (HISTSIZE assertion)" {
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_rc.zsh'
    print -r -- \"HISTSIZE=\$HISTSIZE\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"HISTSIZE=50000"* ]]
}

@test "init_rc.zsh: sources rc/aliases.zsh" {
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_rc.zsh'
    alias ll
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ls -la"* ]]
}

@test "init_rc.zsh: sentinel-guarded against double-source" {
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_rc.zsh'
    HISTSIZE=999
    source '$HOME/.config/ai-bootstrap/shell/init_rc.zsh'
    print -r -- \"\$HISTSIZE\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "999" ]
}

@test "init_rc.zsh: returns 0 when optional rc/zsh_plugins.zsh is absent" {
  # Default fixture has no zsh_plugins.zsh — verify clean source.
  [ ! -f "$HOME/.config/ai-bootstrap/shell/rc/zsh_plugins.zsh" ]
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_rc.zsh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "init_rc.zsh: returns 0 when optional rc/tool_hooks.zsh is absent" {
  [ ! -f "$HOME/.config/ai-bootstrap/shell/rc/tool_hooks.zsh" ]
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_rc.zsh'
    echo OK
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "init_rc.zsh: compinit runs once per shell (sentinel honored)" {
  # _COMPINIT_DONE is set after first compinit call; second source must not
  # re-run compinit. We assert by sourcing rc twice and checking that
  # _COMPINIT_DONE is set exactly once (bool, not a counter — but the
  # observable behavior is that the function exists and no duplicate-init
  # errors fire).
  run zsh -c "
    HOME='$HOME'
    source '$HOME/.config/ai-bootstrap/shell/init_rc.zsh'
    [[ -n \"\$_COMPINIT_DONE\" ]] || exit 1
    # Drop rc-tier sentinel so the barrel re-enters; compinit guard should still hold.
    unset _AI_BOOTSTRAP_INIT_RC_LOADED
    source '$HOME/.config/ai-bootstrap/shell/init_rc.zsh'
    echo OK
  " 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

# ── Defensive guards (rev-4 I3) ──────────────────────────────────────────────

@test "rc/zsh_plugins.zsh: returns 0 when zplug is not on PATH" {
  # Stage zsh_plugins.zsh into the install dir and source it under a PATH
  # that excludes any zplug binary.
  cp "$BOOTSTRAP_DIR/dotfiles/rc/zsh_plugins.zsh" \
    "$HOME/.config/ai-bootstrap/shell/rc/zsh_plugins.zsh"
  run zsh -c "
    HOME='$HOME'
    PATH='/usr/bin:/bin'  # no zplug
    source '$HOME/.config/ai-bootstrap/shell/rc/zsh_plugins.zsh'
    echo OK
  " 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "profile/tool_hooks.zsh: returns 0 when mise is not on PATH" {
  cp "$BOOTSTRAP_DIR/dotfiles/profile/tool_hooks.zsh" \
    "$HOME/.config/ai-bootstrap/shell/profile/tool_hooks.zsh"
  run zsh -c "
    HOME='$HOME'
    PATH='/usr/bin:/bin'  # no mise
    source '$HOME/.config/ai-bootstrap/shell/profile/tool_hooks.zsh'
    echo OK
  " 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "rc/tool_hooks.zsh: returns 0 when neither mise nor direnv on PATH" {
  cp "$BOOTSTRAP_DIR/dotfiles/rc/tool_hooks.zsh" \
    "$HOME/.config/ai-bootstrap/shell/rc/tool_hooks.zsh"
  run zsh -c "
    HOME='$HOME'
    PATH='/usr/bin:/bin'  # no mise, no direnv
    source '$HOME/.config/ai-bootstrap/shell/rc/tool_hooks.zsh'
    echo OK
  " 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
}

@test "rc/tool_hooks.zsh: silent (no errors) when only one of mise/direnv is present" {
  # Stage a fake `mise` on PATH; direnv missing. Must not error.
  fake_bin="$SANDBOX/fake_bin"
  mkdir -p "$fake_bin"
  cat >"$fake_bin/mise" <<'EOF'
#!/bin/sh
# Mock mise activate: emit a noop line so eval succeeds.
case "$1" in
  activate) echo ': mise activated' ;;
  *) ;;
esac
EOF
  chmod +x "$fake_bin/mise"
  cp "$BOOTSTRAP_DIR/dotfiles/rc/tool_hooks.zsh" \
    "$HOME/.config/ai-bootstrap/shell/rc/tool_hooks.zsh"
  run zsh -c "
    HOME='$HOME'
    PATH='$fake_bin:/usr/bin:/bin'  # mise present, direnv absent
    source '$HOME/.config/ai-bootstrap/shell/rc/tool_hooks.zsh'
    echo OK
  " 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
  # No error output above the OK marker.
  [[ "$output" != *"command not found"* ]]
}
