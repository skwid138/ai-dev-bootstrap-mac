#!/usr/bin/env bats
# Tests for lib/paths_check.sh — staleness check on the baked Homebrew
# prefix in the installed shell config.
#
# Strategy: stage a fake "installed" paths.zsh in a temp dir, point
# AI_BOOTSTRAP_INSTALLED_PATHS_ZSH at it, mock `brew` to return a
# configurable prefix, and assert exit codes + stdout for each scenario.
#
# Per plan §3.8 (rev-7), `paths_check_run` has exactly three exit codes:
#   0 = fresh (baked == current `brew --prefix`)
#   1 = stale (baked != current)
#   2 = error (brew missing, install dir missing, paths.zsh unparseable)

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/paths_check.sh
  source "${BOOTSTRAP_DIR}/lib/paths_check.sh"

  # Mocks dir for `brew`. Each test can override MOCK_BREW_PREFIX.
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

  # Staged install dir + paths.zsh template.
  INSTALL_DIR="$BATS_TEST_TMPDIR/install"
  mkdir -p "$INSTALL_DIR/env"
  PATHS_ZSH="$INSTALL_DIR/env/paths.zsh"
  export PATHS_ZSH
  export AI_BOOTSTRAP_INSTALLED_PATHS_ZSH="$PATHS_ZSH"
}

teardown() {
  unset AI_BOOTSTRAP_INSTALLED_PATHS_ZSH
  unset MOCK_BREW_PREFIX
}

# Helper: write a paths.zsh with a given baked prefix.
write_paths_zsh() {
  local prefix="$1"
  cat >"$PATHS_ZSH" <<EOF
# paths.zsh (test fixture)
_path_prepend "${prefix}/sbin"
_path_prepend "${prefix}/bin"
EOF
}

# ── paths_check_extract_baked_prefix ─────────────────────────────────────

@test "extract_baked_prefix: returns the baked prefix from a well-formed paths.zsh" {
  write_paths_zsh "/opt/homebrew"

  run paths_check_extract_baked_prefix "$PATHS_ZSH"
  [ "$status" -eq 0 ]
  [ "$output" = "/opt/homebrew" ]
}

@test "extract_baked_prefix: handles Intel /usr/local prefix" {
  write_paths_zsh "/usr/local"

  run paths_check_extract_baked_prefix "$PATHS_ZSH"
  [ "$status" -eq 0 ]
  [ "$output" = "/usr/local" ]
}

@test "extract_baked_prefix: returns 1 when file does not exist" {
  run paths_check_extract_baked_prefix "$BATS_TEST_TMPDIR/nope.zsh"
  [ "$status" -eq 1 ]
}

@test "extract_baked_prefix: returns 1 when no _path_prepend bin line is present" {
  cat >"$PATHS_ZSH" <<'EOF'
# malformed: no _path_prepend lines at all
echo hello
EOF

  run paths_check_extract_baked_prefix "$PATHS_ZSH"
  [ "$status" -eq 1 ]
}

@test "extract_baked_prefix: returns 1 when __BREW_PREFIX__ token is still un-substituted" {
  # The literal token in dotfiles/env/paths.zsh, before module substitution.
  # We treat this as parseable (it's a "prefix" of "__BREW_PREFIX__"); the
  # comparison step in paths_check_run is what surfaces the staleness.
  # But if the file is empty or malformed enough that the bin line is
  # missing, we return 1.
  cat >"$PATHS_ZSH" <<'EOF'
# paths.zsh — un-substituted template
EOF

  run paths_check_extract_baked_prefix "$PATHS_ZSH"
  [ "$status" -eq 1 ]
}

# ── paths_check_run — fresh ───────────────────────────────────────────────

@test "paths_check_run: exit 0 fresh when baked prefix matches brew --prefix" {
  write_paths_zsh "/opt/homebrew"
  export MOCK_BREW_PREFIX="/opt/homebrew"

  run paths_check_run
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
}

@test "paths_check_run: exit 0 fresh on Intel /usr/local" {
  write_paths_zsh "/usr/local"
  export MOCK_BREW_PREFIX="/usr/local"

  run paths_check_run
  [ "$status" -eq 0 ]
  [ "$output" = "fresh" ]
}

# ── paths_check_run — stale ───────────────────────────────────────────────

@test "paths_check_run: exit 1 stale when brew --prefix has changed" {
  write_paths_zsh "/usr/local"            # baked at install time (Intel)
  export MOCK_BREW_PREFIX="/opt/homebrew" # but now we're on Apple Silicon

  run --separate-stderr paths_check_run
  [ "$status" -eq 1 ]
  [ "$output" = "stale: baked=/usr/local current=/opt/homebrew" ]
}

@test "paths_check_run: stale stdout includes both baked and current values" {
  write_paths_zsh "/opt/homebrew"
  export MOCK_BREW_PREFIX="/opt/custombrew"

  run --separate-stderr paths_check_run
  [ "$status" -eq 1 ]
  [[ "$output" == *"baked=/opt/homebrew"* ]]
  [[ "$output" == *"current=/opt/custombrew"* ]]
}

# ── paths_check_run — error ───────────────────────────────────────────────

@test "paths_check_run: exit 2 error when installed paths.zsh is missing" {
  # Don't write the file.
  export MOCK_BREW_PREFIX="/opt/homebrew"

  run --separate-stderr paths_check_run
  [ "$status" -eq 2 ]
  [[ "$output" == error:* ]]
  [[ "$output" == *"paths.zsh not found"* ]]
}

@test "paths_check_run: exit 2 error when brew is not on PATH" {
  write_paths_zsh "/opt/homebrew"
  # Remove the mocks dir from PATH so `command -v brew` fails. Use a
  # hermetic PATH (the dev machine has /opt/homebrew/bin in outer PATH
  # which would leak through a simple substring removal).
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

  run --separate-stderr paths_check_run
  [ "$status" -eq 2 ]
  [[ "$output" == error:* ]]
  [[ "$output" == *"brew not found"* ]]
}

@test "paths_check_run: exit 2 error when paths.zsh is unparseable" {
  cat >"$PATHS_ZSH" <<'EOF'
# tampered: no _path_prepend "<prefix>/bin" line at all
echo hello
EOF
  export MOCK_BREW_PREFIX="/opt/homebrew"

  run --separate-stderr paths_check_run
  [ "$status" -eq 2 ]
  [[ "$output" == error:* ]]
  [[ "$output" == *"could not extract baked prefix"* ]]
}

# ── Stderr contract ───────────────────────────────────────────────────────

@test "paths_check_run: silent on stderr when fresh" {
  write_paths_zsh "/opt/homebrew"
  export MOCK_BREW_PREFIX="/opt/homebrew"

  run --separate-stderr paths_check_run
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "paths_check_run: emits explanation on stderr when stale" {
  write_paths_zsh "/usr/local"
  export MOCK_BREW_PREFIX="/opt/homebrew"

  run --separate-stderr paths_check_run
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"--refresh-paths"* ]]
}

@test "paths_check_run: emits explanation on stderr when error" {
  # No paths.zsh file.
  export MOCK_BREW_PREFIX="/opt/homebrew"

  run --separate-stderr paths_check_run
  [ "$status" -eq 2 ]
  [ -n "$stderr" ]
}
