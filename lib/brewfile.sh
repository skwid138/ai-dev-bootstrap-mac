#!/bin/bash
# Brewfile generation: at the end of a successful bootstrap run, dump the
# user's current brew state to ~/.config/ai-bootstrap/Brewfile so they have
# a portable, reproducible record they can carry to a new Mac and replay
# with `brew bundle --file=...`.
#
# Why dump the user's full brew state (not just what bootstrap touched):
#
#   1. Reproducibility is the value prop. A non-techy user setting up a new
#      Mac wants "everything I had before" — not "everything bootstrap
#      installed for me a year ago." Anything they brewed by hand still
#      counts.
#
#   2. `brew bundle dump` is the canonical, brew-blessed way to do this.
#      It walks the actual brew state (formulae, casks, taps, mas) and
#      emits guaranteed-valid Brewfile syntax. We don't have to maintain
#      a manual mapping from our RESULTS_* arrays (which mix brew, mise,
#      uv, npx, curl, softwareupdate — most of which aren't Brewfile-able
#      anyway).
#
#   3. The user can opt in to a stricter "bootstrap-only" Brewfile later
#      if they want; we can't easily go the other direction (rebuild a
#      full Brewfile from RESULTS_* would re-introduce the mapping
#      problem).
#
# Trade-off: the Brewfile contains stuff bootstrap didn't install (e.g.
# the user's manually-brewed `htop`). Documented in a header comment we
# write alongside the file via brew bundle's --describe flag.

# ── brewfile_dump ───────────────────────────────────────────────────────────
# Args:
#   $1: dest_file  — absolute path for the Brewfile (e.g.
#                    "$HOME/.config/ai-bootstrap/Brewfile")
#
# Stdout: "wrote <path>" on success, nothing on early-exit / failure.
# Returns:
#   0  on success.
#   1  if brew is not on PATH (caller decided whether that's fatal).
#   2  if the dump command itself failed.
brewfile_dump() {
  local dest_file="$1"

  if ! command -v brew >/dev/null 2>&1; then
    echo "brewfile_dump: brew not on PATH; skipping" >&2
    return 1
  fi

  local dest_dir
  dest_dir=$(dirname "$dest_file")
  if ! mkdir -p "$dest_dir"; then
    echo "brewfile_dump: failed to create $dest_dir" >&2
    return 2
  fi

  # --force: overwrite an existing Brewfile (it's bootstrap-managed).
  # --describe: emit a comment for each formula/cask describing it, so a
  #   future user can read the file and understand what each line is.
  # We deliberately do NOT pass --no-restart, --taps=false, etc. — defaults
  # produce the most portable Brewfile.
  if ! brew bundle dump --force --describe --file="$dest_file" >/dev/null 2>&1; then
    echo "brewfile_dump: brew bundle dump failed" >&2
    return 2
  fi

  echo "wrote $dest_file"
  return 0
}
