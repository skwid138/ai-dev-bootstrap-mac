#!/bin/bash
# lib/paths_check.sh — staleness check + refresh helpers for the baked
# Homebrew prefix in the installed shell config.
#
# Why this lives in its own lib:
#
#   `bootstrap.sh --check-paths` is a fast-path that runs without sourcing
#   the rest of the installer. Putting the logic in its own lib makes it
#   (a) unit-testable in isolation (no need to fake all of bootstrap's
#   environment), and (b) cheap to load — bootstrap.sh sources it
#   alongside the other libs before the launcher-only / check-paths /
#   refresh-paths fast-paths fire.
#
# Contract (rev-7 §3.8 — rev-7 narrowed scope to root prefix only).
#
#   The installed `~/.config/ai-bootstrap/shell/env/paths.zsh` has exactly
#   ONE substituted value: the Homebrew root prefix (resolved at install
#   time via `brew --prefix`). All Homebrew formulas registered today are
#   either auto-symlinked into $BREW_PREFIX/bin (root prefix covers them)
#   or runtime-managed by mise (irrelevant to brew --prefix). There are
#   no per-formula bakes to iterate.
#
#   So `paths_check_run` does ONE thing: extract the baked prefix from
#   the installed paths.zsh, re-resolve `brew --prefix` (no formula),
#   compare. Three exit codes:
#
#     0 = fresh:  baked prefix == current `brew --prefix`
#     1 = stale:  baked != current (e.g. user moved between
#                 /opt/homebrew (Apple Silicon) and /usr/local (Intel),
#                 or installed a custom HOMEBREW_PREFIX)
#     2 = error:  brew not on PATH, install dir missing, or paths.zsh
#                 unparseable (likely tampered)
#
# Stdout (always — single line):
#
#   "fresh"
#   "stale: baked=<X> current=<Y>"
#   "error: <reason>"
#
# Stderr (only on stale or error):
#
#   Human-readable explanation. Designed for an agent to parse the stdout
#   line and surface stderr to the user when needed.

# ── Constants ─────────────────────────────────────────────────────────────

# Path to the installed env-tier paths.zsh. Override via
# AI_BOOTSTRAP_INSTALLED_PATHS_ZSH for tests.
paths_check_installed_file() {
  echo "${AI_BOOTSTRAP_INSTALLED_PATHS_ZSH:-$HOME/.config/ai-bootstrap/shell/env/paths.zsh}"
}

# ── paths_check_extract_baked_prefix ─────────────────────────────────────
# Read the installed paths.zsh and extract the baked Homebrew prefix.
#
# Strategy: grep for the `_path_prepend "<prefix>/bin"` line and strip
# the trailing `/bin"` to recover the prefix. We use the bin line (not
# sbin) because `bin` is the LAST `_path_prepend` call by design (see
# dotfiles/env/paths.zsh comment) and is unambiguous.
#
# Returns 0 with the prefix on stdout if found, 1 otherwise.
paths_check_extract_baked_prefix() {
  local file="$1"
  local line

  if [ ! -f "$file" ]; then
    return 1
  fi

  # Match: _path_prepend "<anything>/bin"
  # Capture: <anything>
  line=$(grep -E '^_path_prepend "[^"]+/bin"' "$file" | tail -1)
  if [ -z "$line" ]; then
    return 1
  fi

  # Strip prefix `_path_prepend "` and suffix `/bin"`.
  # Using parameter expansion to avoid sed dialect issues.
  line="${line#_path_prepend \"}"
  line="${line%/bin\"}"

  if [ -z "$line" ]; then
    return 1
  fi

  echo "$line"
  return 0
}

# ── paths_check_run ───────────────────────────────────────────────────────
# Main entry. Prints one-line status to stdout, optional explanation to
# stderr, returns 0/1/2.
paths_check_run() {
  local installed_file
  installed_file="$(paths_check_installed_file)"

  # Error: install dir / file missing.
  if [ ! -f "$installed_file" ]; then
    echo "error: installed paths.zsh not found at $installed_file"
    echo "Run bootstrap.sh first to create the shell config." >&2
    return 2
  fi

  # Error: brew not on PATH.
  if ! command -v brew >/dev/null 2>&1; then
    echo "error: brew not found on PATH"
    echo "Homebrew must be installed and on PATH to check the baked prefix." >&2
    return 2
  fi

  # Error: baked prefix unparseable (file tampered, or substitution
  # never ran).
  local baked
  if ! baked="$(paths_check_extract_baked_prefix "$installed_file")"; then
    echo "error: could not extract baked prefix from $installed_file"
    echo "The file may be tampered with or the __BREW_PREFIX__ substitution never ran." >&2
    return 2
  fi

  # Error: `brew --prefix` failed.
  local current
  if ! current="$(brew --prefix 2>/dev/null)"; then
    echo "error: brew --prefix failed"
    echo "Try running 'brew doctor' to diagnose the Homebrew install." >&2
    return 2
  fi

  # Compare.
  if [ "$baked" = "$current" ]; then
    echo "fresh"
    return 0
  fi

  echo "stale: baked=$baked current=$current"
  echo "Homebrew prefix has changed since install. Run 'bootstrap.sh --refresh-paths' to update." >&2
  return 1
}
