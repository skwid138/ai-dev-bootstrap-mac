#!/bin/bash
# Git configuration helpers.
#
# Factor the "set sensible git defaults for a new user" logic out of
# modules/04-git.sh so it can be unit-tested. Each function operates
# on the *global* git config (--global) which is what a fresh user
# expects, but tests redirect via $HOME/.gitconfig sandboxing.
#
# Why these defaults (locked in 2026-04-30):
#   init.defaultBranch=main   — modern best practice; matches GitHub default
#   pull.rebase=false         — merge-on-pull is safer for non-techy users;
#                                rebase requires understanding rewrites
#   core.editor               — picked dynamically: code --wait > nano > vim
#                                (vim only if user explicitly has it; nano
#                                ships pre-installed on macOS and is
#                                navigable by anyone)
#
# Why "only set if unset":
#   A returning user (or someone who installed git separately) may have
#   intentionally configured these. We never stomp existing config.
#   Same overwrite-protect philosophy as the rest of the bootstrap.

# ── git_get_global ──────────────────────────────────────────────────────────
# Wrapper around `git config --global --get`. Echoes the value, exits 0
# if found, exits 1 if not set. Quiet — never prints to stderr.
git_get_global() {
  local key="$1"
  git config --global --get "$key" 2>/dev/null
}

# ── git_is_set_global ───────────────────────────────────────────────────────
# Returns 0 if the key has a non-empty global value, 1 otherwise.
git_is_set_global() {
  local key="$1"
  local value
  value=$(git_get_global "$key")
  [ -n "$value" ]
}

# ── git_set_default_if_unset ────────────────────────────────────────────────
# Idempotent: sets a global git config key only if it isn't already
# set. Returns 0 always (skipping is success), non-zero only if the
# `git config` write itself fails.
#
# Echoes one of:
#   "set"      — was unset, we set it
#   "kept"     — already set (to anything, possibly different value)
#
# The caller decides how to surface that to the user.
git_set_default_if_unset() {
  local key="$1"
  local value="$2"

  if git_is_set_global "$key"; then
    echo "kept"
    return 0
  fi

  if git config --global "$key" "$value"; then
    echo "set"
    return 0
  fi

  echo "git_set_default_if_unset: failed to set $key=$value" >&2
  return 1
}

# ── git_choose_editor ───────────────────────────────────────────────────────
# Pick the best available editor for git's `core.editor`. Order:
#   1. VS Code (`code --wait`) — best UX, full features, the editor we
#      installed via brew cask vscode in the essential tier.
#   2. nano — pre-installed on macOS, navigable by absolute beginners
#      (Ctrl-X to exit is on-screen).
#   3. Empty string — no preference; git will fall back to its default
#      ($EDITOR or vi). We don't force vi onto a non-techy user.
#
# Echoes the chosen value (possibly empty). Always returns 0.
git_choose_editor() {
  if command -v code >/dev/null 2>&1; then
    echo "code --wait"
    return 0
  fi

  if command -v nano >/dev/null 2>&1; then
    echo "nano"
    return 0
  fi

  echo ""
  return 0
}
