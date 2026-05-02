#!/usr/bin/env bats
# Tests for modules/10-shell-config.sh — the shell config install module.
#
# ────────────────────────────────────────────────────────────────────────────
# PHASE 4 PENDING — ALL TESTS IN THIS FILE ARE SKIPPED.
# ────────────────────────────────────────────────────────────────────────────
#
# The module rewrite landing in Phase 4 of zsh_init_plan.md (rev. 5) replaces
# the legacy single-file copy logic with the three-tier installer described
# in §4.1. These tests describe the post-Phase-4 contracts. Running them
# against the current Phase-1 module would fail every assertion (the old
# module copies dotfiles/init.sh which no longer exists).
#
# Phase 4 implementation MUST:
#   1. Remove every `skip` line below.
#   2. Make every test pass.
#   3. Land the module rewrite + the bootstrap.sh:283 gate change in the
#      same atomic commit (per plan §9 Phase 4).
#
# Each test's body is intentionally complete — it documents the contract
# Phase 4 must satisfy, not just an aspirational placeholder. When Phase 4
# unskips, no test logic should need rewriting; only the `skip` lines come
# out.

bats_require_minimum_version 1.5.0

load "test_helper.sh"

setup() {
  setup_test_env

  # Mocks dir: brew (returns prefix), is_selected (configurable), cp (real).
  MOCKS_DIR="$BATS_TEST_TMPDIR/mocks"
  mkdir -p "$MOCKS_DIR"
  cat >"$MOCKS_DIR/brew" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --prefix) echo "${MOCK_BREW_PREFIX:-/opt/homebrew}" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$MOCKS_DIR/brew"
  export PATH="$MOCKS_DIR:$PATH"

  # Sandboxed brew prefix that actually exists (the module substitutes
  # this into paths.zsh; _path_prepend gates on -d so it must be real).
  export MOCK_BREW_PREFIX="$BATS_TEST_TMPDIR/brew"
  mkdir -p "$MOCK_BREW_PREFIX/bin" "$MOCK_BREW_PREFIX/sbin"

  # Module + repo paths.
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT
  export BOOTSTRAP_DIR="$REPO_ROOT"

  # Override HOME so the module writes into the sandbox.
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
}

teardown() {
  teardown_test_env
}

# Helper: source the module with a stub `is_selected` that returns true for
# every package (tier-coupling is asserted separately).
run_module_with_all_selected() {
  bash -c "
    set -e
    BOOTSTRAP_DIR='$REPO_ROOT'
    SELECTED_PACKAGES=(zsh zplug mise direnv zoxide eza bat fzf ripgrep)
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/modules/10-shell-config.sh'
  "
}

# ── Directory tree creation ──────────────────────────────────────────────────

@test "module creates ~/.config/ai-bootstrap/shell with env/lib/profile/rc subdirs" {
  skip "Phase 4: requires three-tier module rewrite (zsh_init_plan.md §4.1)"

  run_module_with_all_selected

  [ -d "$HOME/.config/ai-bootstrap/shell" ]
  [ -d "$HOME/.config/ai-bootstrap/shell/env" ]
  [ -d "$HOME/.config/ai-bootstrap/shell/lib" ]
  [ -d "$HOME/.config/ai-bootstrap/shell/profile" ]
  [ -d "$HOME/.config/ai-bootstrap/shell/rc" ]
}

# ── Barrel + tier file copy ──────────────────────────────────────────────────

@test "module copies all three barrels to install dir" {
  skip "Phase 4: requires three-tier module rewrite"

  run_module_with_all_selected

  [ -f "$HOME/.config/ai-bootstrap/shell/init_env.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/init_profile.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/init_rc.zsh" ]
}

@test "module copies env-tier files (vars.zsh, paths.zsh) and path_helpers.zsh" {
  skip "Phase 4: requires three-tier module rewrite"

  run_module_with_all_selected

  [ -f "$HOME/.config/ai-bootstrap/shell/env/vars.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/env/paths.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/lib/path_helpers.zsh" ]
}

@test "module copies rc-tier files (zsh_config.zsh, aliases.zsh) unconditionally" {
  skip "Phase 4: requires three-tier module rewrite"

  run_module_with_all_selected

  [ -f "$HOME/.config/ai-bootstrap/shell/rc/zsh_config.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/rc/aliases.zsh" ]
}

@test "module copies rc/zsh_plugins.zsh ONLY when zplug is selected" {
  skip "Phase 4: requires three-tier module rewrite + tier-coupling logic"

  bash -c "
    set -e
    BOOTSTRAP_DIR='$REPO_ROOT'
    SELECTED_PACKAGES=(zsh)  # no zplug
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/modules/10-shell-config.sh'
  "

  [ ! -f "$HOME/.config/ai-bootstrap/shell/rc/zsh_plugins.zsh" ]
}

@test "module copies profile/tool_hooks.zsh ONLY when mise is selected" {
  skip "Phase 4: requires three-tier module rewrite + tier-coupling logic"

  bash -c "
    set -e
    BOOTSTRAP_DIR='$REPO_ROOT'
    SELECTED_PACKAGES=(zsh)  # no mise
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/modules/10-shell-config.sh'
  "

  [ ! -f "$HOME/.config/ai-bootstrap/shell/profile/tool_hooks.zsh" ]
}

@test "module copies rc/tool_hooks.zsh when mise OR direnv selected (rc-tier hooks)" {
  skip "Phase 4: requires three-tier module rewrite + tier-coupling logic"

  bash -c "
    set -e
    BOOTSTRAP_DIR='$REPO_ROOT'
    SELECTED_PACKAGES=(zsh direnv)  # direnv but not mise
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/modules/10-shell-config.sh'
  "

  [ -f "$HOME/.config/ai-bootstrap/shell/rc/tool_hooks.zsh" ]
}

# ── __BREW_PREFIX__ substitution ─────────────────────────────────────────────

@test "module substitutes __BREW_PREFIX__ in env/paths.zsh with brew --prefix output" {
  skip "Phase 4: requires three-tier module rewrite + brew substitution"

  run_module_with_all_selected

  # No remaining sentinel after install.
  ! grep -q "__BREW_PREFIX__" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
  # Real brew prefix substituted in.
  grep -q "${MOCK_BREW_PREFIX}/bin" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
  grep -q "${MOCK_BREW_PREFIX}/sbin" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
}

@test "module fails fast with clear error when brew --prefix unavailable" {
  skip "Phase 4: requires three-tier module rewrite + brew presence check"

  # Remove brew from PATH.
  export PATH="${PATH//${MOCKS_DIR}:/}"

  run bash -c "
    set -e
    BOOTSTRAP_DIR='$REPO_ROOT'
    SELECTED_PACKAGES=(zsh)
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/modules/10-shell-config.sh'
  "

  [ "$status" -ne 0 ]
  [[ "$output" == *"brew"* ]]
}

# ── Source-line wiring in user dotfiles ──────────────────────────────────────

@test "module appends source line for init_env.zsh to ~/.zshenv" {
  skip "Phase 4: requires three-tier module rewrite + dotfile wiring"

  run_module_with_all_selected

  [ -f "$HOME/.zshenv" ]
  grep -qF "ai-bootstrap/shell/init_env.zsh" "$HOME/.zshenv"
}

@test "module appends source line for init_profile.zsh to ~/.zprofile" {
  skip "Phase 4: requires three-tier module rewrite + dotfile wiring"

  run_module_with_all_selected

  [ -f "$HOME/.zprofile" ]
  grep -qF "ai-bootstrap/shell/init_profile.zsh" "$HOME/.zprofile"
}

@test "module appends source line for init_rc.zsh to ~/.zshrc" {
  skip "Phase 4: requires three-tier module rewrite + dotfile wiring"

  run_module_with_all_selected

  [ -f "$HOME/.zshrc" ]
  grep -qF "ai-bootstrap/shell/init_rc.zsh" "$HOME/.zshrc"
}

@test "module emits a tier-tagged comment alongside each source line" {
  skip "Phase 4: requires three-tier module rewrite + dotfile wiring"

  run_module_with_all_selected

  # Comment helps users grep and helps the staleness detector identify
  # ai-bootstrap-managed source lines.
  grep -qF "# ai-bootstrap" "$HOME/.zshenv"
  grep -qF "# ai-bootstrap" "$HOME/.zprofile"
  grep -qF "# ai-bootstrap" "$HOME/.zshrc"
}

# ── Idempotency ──────────────────────────────────────────────────────────────

@test "module is idempotent: running twice does not duplicate source lines" {
  skip "Phase 4: requires three-tier module rewrite + idempotent append"

  run_module_with_all_selected
  run_module_with_all_selected

  # Each dotfile must contain the source line exactly once.
  [ "$(grep -cF "ai-bootstrap/shell/init_env.zsh" "$HOME/.zshenv")" -eq 1 ]
  [ "$(grep -cF "ai-bootstrap/shell/init_profile.zsh" "$HOME/.zprofile")" -eq 1 ]
  [ "$(grep -cF "ai-bootstrap/shell/init_rc.zsh" "$HOME/.zshrc")" -eq 1 ]
}

@test "module is idempotent: re-running does not corrupt env/paths.zsh substitution" {
  skip "Phase 4: requires three-tier module rewrite + idempotent install"

  run_module_with_all_selected
  run_module_with_all_selected

  # Sentinel must not reappear; substituted prefix must remain intact.
  ! grep -q "__BREW_PREFIX__" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
  grep -q "${MOCK_BREW_PREFIX}/bin" "$HOME/.config/ai-bootstrap/shell/env/paths.zsh"
}

@test "module preserves existing user content in ~/.zshenv when appending" {
  skip "Phase 4: requires three-tier module rewrite + non-destructive append"

  printf '# user content\nexport USER_VAR=foo\n' >"$HOME/.zshenv"

  run_module_with_all_selected

  grep -qF "USER_VAR=foo" "$HOME/.zshenv"
  grep -qF "ai-bootstrap/shell/init_env.zsh" "$HOME/.zshenv"
}

# ── Unconditional execution (§5.1 fix) ───────────────────────────────────────

@test "module runs unconditionally — not gated on zplug-tier package selection" {
  skip "Phase 4: requires bootstrap.sh:283 ungate + module unconditional"

  # Even with NO packages selected, the module must install the three-tier
  # baseline (per §5.1: 'shell config is foundational, not optional').
  bash -c "
    set -e
    BOOTSTRAP_DIR='$REPO_ROOT'
    SELECTED_PACKAGES=()
    source '$REPO_ROOT/lib/common.sh'
    source '$REPO_ROOT/modules/10-shell-config.sh'
  "

  [ -f "$HOME/.config/ai-bootstrap/shell/init_env.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/init_profile.zsh" ]
  [ -f "$HOME/.config/ai-bootstrap/shell/init_rc.zsh" ]
}

# ── Stale-layout detection (§5.3) ────────────────────────────────────────────

@test "module warns when stale legacy ~/.config/ai-bootstrap/shell/init.sh exists" {
  skip "Phase 4: requires staleness detection per zsh_init_plan.md §5.3"

  # Pre-seed the stale layout: old single-file init.sh from the pre-Phase-4
  # module.
  mkdir -p "$HOME/.config/ai-bootstrap/shell"
  echo '# stale init.sh' >"$HOME/.config/ai-bootstrap/shell/init.sh"
  echo '# stale paths.sh' >"$HOME/.config/ai-bootstrap/shell/paths.sh"

  run run_module_with_all_selected

  [ "$status" -eq 0 ]
  [[ "$output" == *"stale"* || "$output" == *"legacy"* || "$output" == *"obsolete"* ]]
  [[ "$output" == *"init.sh"* ]]
}

@test "module warns when ~/.zshrc still sources legacy init.sh path" {
  skip "Phase 4: requires staleness detection per zsh_init_plan.md §5.3"

  # Pre-seed an old-style source line in ~/.zshrc.
  printf '# legacy line\nsource ~/.config/ai-bootstrap/shell/init.sh\n' >"$HOME/.zshrc"

  run run_module_with_all_selected

  [ "$status" -eq 0 ]
  [[ "$output" == *"legacy"* || "$output" == *"stale"* || "$output" == *"obsolete"* ]]
}

@test "module does NOT auto-delete stale files (warn-only per §5.3)" {
  skip "Phase 4: requires staleness detection per zsh_init_plan.md §5.3"

  mkdir -p "$HOME/.config/ai-bootstrap/shell"
  echo '# stale' >"$HOME/.config/ai-bootstrap/shell/init.sh"

  run_module_with_all_selected

  # Stale file must still exist — module warns but never destroys.
  [ -f "$HOME/.config/ai-bootstrap/shell/init.sh" ]
}
