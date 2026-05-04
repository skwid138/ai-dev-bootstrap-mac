#!/bin/bash
#
# install.sh — curl-pipeable bootstrap entrypoint.
#
# Why this file exists:
#   bootstrap.sh is a multi-file orchestrator that `source`s ~11 sibling
#   library files at startup (lib/*.sh, config/*.sh, launcher/*). When
#   you pipe bootstrap.sh through curl into bash, ${BASH_SOURCE[0]} is
#   the curl FIFO (e.g. /dev/fd/63), so its dirname has no siblings —
#   every `source` call fails immediately. The curl one-liner that
#   appears in the README has therefore been broken since the project
#   went multi-file.
#
#   This file fixes that. It clones the repo to a known location and
#   then exec's bootstrap.sh from inside the working tree. From there
#   bootstrap.sh's `source` calls all resolve correctly because the
#   library files are siblings on disk.
#
# Usage:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/skwid138/ai-dev-bootstrap-mac/main/install.sh)"
#
#   With flags (note the `-s --` to pass args through bash -c into this script):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/skwid138/ai-dev-bootstrap-mac/main/install.sh)" -s -- --launcher-only
#
# Env knobs:
#   BOOTSTRAP_DIR    Override the clone location (default: ~/code/ai-dev-bootstrap-mac).
#                    Power users only; the default matches the project's workspace convention.
#   BOOTSTRAP_REPO   Override the repo URL (default: https://github.com/skwid138/ai-dev-bootstrap-mac.git).
#                    Useful for testing forks before merging.
#   BOOTSTRAP_REF    Override the branch/tag to check out (default: main).
#                    Useful for testing a feature branch before merging it.
#                    Note: must be a branch or tag name; bare commit SHAs
#                    are not supported by `git clone --branch`. To install
#                    from a specific commit, clone manually and run
#                    bootstrap.sh from the working tree.
#
# Behavior on a directory that already exists at $BOOTSTRAP_DIR:
#   * If it's a git checkout of this repo (origin URL matches): `git fetch && git checkout <ref> && git pull --ff-only`. This is the "re-run / upgrade" path.
#   * If it's a git checkout of a DIFFERENT repo: abort with a clear message; the user must move it or set BOOTSTRAP_DIR.
#   * If it exists but is not a git checkout: abort. Same reason — we won't clobber unknown content.
#
# This file MUST be self-contained (no `source`s). It is the only script
# in the repo that can be safely run via `curl | bash`.

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────
DEFAULT_REPO="https://github.com/skwid138/ai-dev-bootstrap-mac.git"
DEFAULT_DIR="${HOME}/code/ai-dev-bootstrap-mac"
DEFAULT_REF="main"

REPO="${BOOTSTRAP_REPO:-$DEFAULT_REPO}"
DIR="${BOOTSTRAP_DIR:-$DEFAULT_DIR}"
REF="${BOOTSTRAP_REF:-$DEFAULT_REF}"

# ── Tiny logging shims ────────────────────────────────────────────────
# We can't source lib/ui.sh — we don't have it yet. Inline minimal output
# in a style that matches lib/ui.sh's log_info / log_error feel.
_say()   { printf '\033[1;34m▶\033[0m %s\n' "$*"; }
_warn()  { printf '\033[1;33m⚠\033[0m %s\n' "$*" >&2; }
_die()   { printf '\033[1;31m✖\033[0m %s\n' "$*" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────
# git is the only hard dependency. Modern macOS ships git via the Xcode
# Command Line Tools, which bootstrap.sh itself installs in Phase 0 —
# but we need git BEFORE bootstrap.sh runs in order to clone the repo
# at all. Most users will already have it (it's a near-universal Xcode
# CLT artifact). If they don't, kick off the official CLT installer
# prompt and instruct them to re-run.
if ! command -v git >/dev/null 2>&1; then
  _warn "git is not installed."
  _say  "Triggering Xcode Command Line Tools install (this opens a system dialog)..."
  # `xcode-select --install` is async and idempotent. It pops a GUI
  # dialog; if CLT is already pending/installing, it returns non-zero
  # but that's not fatal for our purposes. We just need to nudge the
  # user toward installing it.
  xcode-select --install 2>/dev/null || true
  _die "Re-run this installer after the Command Line Tools install completes."
fi

# ── Clone or refresh ──────────────────────────────────────────────────
if [ -e "$DIR" ]; then
  # Something is already there. Figure out what.
  if [ -d "$DIR/.git" ]; then
    # It's a git repo. Is it OUR repo?
    existing_origin=$(git -C "$DIR" remote get-url origin 2>/dev/null || echo "")
    # Normalize comparison: GitHub accepts both .git suffix and bare URL.
    norm_existing="${existing_origin%.git}"
    norm_repo="${REPO%.git}"
    if [ "$norm_existing" = "$norm_repo" ]; then
      _say "Found existing checkout at $DIR — refreshing to ${REF}…"
      # Use --ff-only to fail loudly rather than silently merge if the
      # user has local commits ahead of origin. Don't blow away their work.
      git -C "$DIR" fetch origin --tags --prune
      git -C "$DIR" checkout "$REF"
      # Skip pull if we're on a detached HEAD (e.g. tag or SHA checkout).
      if git -C "$DIR" symbolic-ref -q HEAD >/dev/null 2>&1; then
        git -C "$DIR" pull --ff-only origin "$REF" || _die "Local commits diverge from origin/$REF in $DIR. Resolve manually (git status), then re-run."
      fi
    else
      _die "Directory $DIR is a git checkout of a DIFFERENT repository (origin: $existing_origin). Move it aside or set BOOTSTRAP_DIR=/some/other/path."
    fi
  else
    _die "Directory $DIR exists but is not a git checkout. Move it aside or set BOOTSTRAP_DIR=/some/other/path."
  fi
else
  _say "Cloning $REPO into $DIR (ref: $REF)…"
  # Make the parent (e.g. ~/code/) before cloning.
  mkdir -p "$(dirname "$DIR")"
  git clone --branch "$REF" "$REPO" "$DIR" || _die "Clone failed."
fi

# ── Hand off ──────────────────────────────────────────────────────────
# Strip a leading `--` sentinel if present. This is an artifact of the
# `bash -c "$(curl …)" -s -- --flag` curl-pipe idiom, NOT a meaningful
# flag the user passed. bootstrap.sh's args parser doesn't recognize
# `--` and would error out with "Unknown flag: --". Strip it here so
# the curl-pipe form Just Works.
#
# We only strip ONE leading `--`; a `--` deeper in the arg list is
# treated as user-provided and forwarded as-is.
if [ "${1:-}" = "--" ]; then
  shift
fi

# exec, not invoke: replace this process so the user sees bootstrap.sh's
# output unmediated and signal handling (Ctrl-C) goes to the right place.
# Pass through any args we received (--dry-run, --launcher-only, --tier=…, etc.).
_say "Handing off to bootstrap.sh…"
exec "$DIR/bootstrap.sh" "$@"
