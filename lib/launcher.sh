#!/bin/bash
# Vibe Code launcher install helpers.
#
# Two responsibilities, factored out of modules/03-terminal.sh so each is
# independently testable with bats:
#
#   launcher_install   — build the .app and place it in ~/Applications/.
#   launcher_uninstall — remove the .app from ~/Applications/.
#
# Design choices (see ANALYSIS_AND_PLAN.md §E for full reasoning):
#
#   * Always rebuild on bootstrap re-run. The .app is small (~150 KB) and
#     building is fast (~50 ms). Skipping a rebuild risks the user running
#     a stale launcher after we ship launch.sh changes — way worse than
#     repeating 50 ms of work.
#
#   * Install to ~/Applications/, not /Applications/. Avoids needing sudo
#     during bootstrap. Spotlight, LaunchPad, and Finder all index it the
#     same way as the system Applications folder.
#
#   * No "skipped" path. Unlike ghostty/AGENTS.md, the launcher bundle
#     contains zero user-editable content (the `launch` binary is a copy
#     of our launch.sh; users edit Terminal.app or System Settings if
#     they want different behavior, not the .app contents). Rebuilding is
#     always safe.

# ── launcher_install ────────────────────────────────────────────────────────
# Args:
#   $1: build_script — absolute path to launcher/build.sh
#   $2: dest_dir     — directory to install the .app into (typically
#                      "$HOME/Applications")
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
  local bundle="$dest_dir/Vibe Code.app"

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
