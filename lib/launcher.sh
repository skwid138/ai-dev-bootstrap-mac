#!/bin/bash
# Just Vibes launcher install helpers.
#
# Three responsibilities, factored out of modules/03-terminal.sh so each is
# independently testable with bats:
#
#   launcher_resolve_dest — pick install dir: /Applications or ~/Applications.
#   launcher_install      — build the .app and place it in the dest dir.
#   launcher_uninstall    — remove the .app from a given dir.
#
# Design choices (see ANALYSIS_AND_PLAN.md §E for full reasoning):
#
#   * Always rebuild on bootstrap re-run. The .app is small (~150 KB) and
#     building is fast (~50 ms). Skipping a rebuild risks the user running
#     a stale launcher after we ship launch.sh changes — way worse than
#     repeating 50 ms of work.
#
#   * Prefer /Applications, fall back to ~/Applications. Most users *can*
#     write to /Applications without sudo (it's group-writable for `admin`,
#     and admin is the default for the Mac account that ran bootstrap).
#     /Applications is what users actually expect: it shows up first in
#     Spotlight, works for non-admin family members on shared machines,
#     and matches every other Mac app's install location. We only fall
#     back to ~/Applications on machines where /Applications is read-only
#     (corp-managed Macs, non-admin user accounts).
#
#   * No "skipped" path. Unlike ghostty/AGENTS.md, the launcher bundle
#     contains zero user-editable content. Rebuilding is always safe.

# ── launcher_resolve_dest ───────────────────────────────────────────────────
# Pick the install directory for Just Vibes.app. Prefers /Applications if
# writable (most users on standard Macs); falls back to ~/Applications
# otherwise.
#
# Args: none.
# Stdout: absolute path to install dir.
# Returns: 0 always.
#
# Override via JUST_VIBES_DEST_DIR_OVERRIDE for tests (the resolution is
# what we want to test, but real $HOME/Applications and /Applications
# can't be safely written to from CI/test sandboxes).
launcher_resolve_dest() {
  if [ -n "${JUST_VIBES_DEST_DIR_OVERRIDE:-}" ]; then
    echo "$JUST_VIBES_DEST_DIR_OVERRIDE"
    return 0
  fi

  if [ -w "/Applications" ]; then
    echo "/Applications"
  else
    echo "$HOME/Applications"
  fi
  return 0
}

# ── launcher_install ────────────────────────────────────────────────────────
# Args:
#   $1: build_script — absolute path to launcher/build.sh
#   $2: dest_dir     — directory to install the .app into (use
#                      launcher_resolve_dest to pick a sensible default)
#
# Stdout: "installed"
# Returns:
#   0  on success
#   1  if build_script is missing or the build fails
launcher_install() {
  local build_script="$1"
  local dest_dir="$2"

  if [ ! -x "$build_script" ]; then
    echo "launcher_install: build script not found or not executable: $build_script" >&2
    return 1
  fi

  if ! mkdir -p "$dest_dir"; then
    echo "launcher_install: failed to create $dest_dir" >&2
    return 1
  fi

  if ! "$build_script" "$dest_dir" >/dev/null; then
    echo "launcher_install: build failed" >&2
    return 1
  fi

  echo "installed"
  return 0
}

# ── launcher_uninstall ──────────────────────────────────────────────────────
# Args:
#   $1: dest_dir — directory the .app was installed into
#
# Stdout: "removed" if a bundle was deleted, "absent" if nothing was there.
# Returns:
#   0  on success (whether removed or absent)
#   1  if rm fails
launcher_uninstall() {
  local dest_dir="$1"
  local bundle="$dest_dir/Just Vibes.app"

  if [ ! -d "$bundle" ]; then
    echo "absent"
    return 0
  fi

  if ! rm -rf "$bundle"; then
    echo "launcher_uninstall: failed to remove $bundle" >&2
    return 1
  fi

  echo "removed"
  return 0
}
