#!/bin/bash
# JustVibes launcher install helpers.
#
# Three responsibilities, factored out of modules/03-terminal.sh so each is
# independently testable with bats:
#
#   launcher_resolve_dest — pick install dir: /Applications or ~/Applications.
#   launcher_install      — build the .app and place it in the dest dir.
#   launcher_cleanup_legacy — remove old "Just Vibes.app" bundles we own.
#   launcher_uninstall      — remove the .app from a given dir.
#
# Design choices (see ANALYSIS_AND_PLAN.md §E for full reasoning):
#
#   * Rebuild only when needed. The launcher source is checksummed, and the
#     saved checksum is compared on bootstrap re-run so unchanged bundles are
#     left in place while launch.sh changes still trigger a safe rebuild.
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
#   * A checksum match is safe to skip. Unlike ghostty/AGENTS.md, the launcher
#     bundle contains zero user-editable content; checksum drift triggers the
#     rebuild path instead of preserving a stale bundle.

launcher_checksum_file() {
  echo "$HOME/.config/ai-bootstrap/launcher-checksum"
}

launcher_checksum_compute() {
  local root="${BOOTSTRAP_DIR:-$(pwd)}"

  (
    cd "$root" || exit 1
    find launcher/ -type f -not -name '.DS_Store' | sort | xargs shasum | shasum | awk '{print $1}'
  )
}

launcher_needs_rebuild() {
  local dest_dir app_path checksum_file current_checksum saved_checksum

  dest_dir=$(launcher_resolve_dest)
  app_path="$dest_dir/JustVibes.app"
  checksum_file=$(launcher_checksum_file)

  [ -d "$app_path" ] || return 0
  [ -f "$checksum_file" ] || return 0

  current_checksum=$(launcher_checksum_compute) || return 0
  saved_checksum=$(cat "$checksum_file" 2>/dev/null || true)

  [ "$current_checksum" != "$saved_checksum" ]
}

launcher_checksum_save() {
  local checksum_file checksum_dir

  checksum_file=$(launcher_checksum_file)
  checksum_dir=$(dirname "$checksum_file")
  mkdir -p "$checksum_dir" || return 1
  launcher_checksum_compute >"$checksum_file"
}

# ── launcher_resolve_dest ───────────────────────────────────────────────────
# Pick the install directory for JustVibes.app. Prefers /Applications if
# writable (most users on standard Macs); falls back to ~/Applications
# otherwise.
#
# Args: none.
# Stdout: absolute path to install dir.
# Returns: 0 always.
#
# Override via JUSTVIBES_DEST_DIR_OVERRIDE for tests (the resolution is
# what we want to test, but real $HOME/Applications and /Applications
# can't be safely written to from CI/test sandboxes).
launcher_resolve_dest() {
  if [ -n "${JUSTVIBES_DEST_DIR_OVERRIDE:-}" ]; then
    echo "$JUSTVIBES_DEST_DIR_OVERRIDE"
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
  local app_path="$dest_dir/JustVibes.app"

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

  if [ ! -r "$app_path/Contents/Info.plist" ]; then
    echo "launcher_install: built app is missing readable Info.plist: $app_path" >&2
    return 1
  fi

  launcher_cleanup_legacy "$dest_dir"

  if ! launcher_checksum_save; then
    echo "launcher_install: failed to save launcher checksum" >&2
    return 1
  fi

  echo "installed"
  return 0
}

launcher_build() {
  local dest_dir
  dest_dir=$(launcher_resolve_dest)
  launcher_install "${BOOTSTRAP_DIR}/launcher/build.sh" "$dest_dir"
}

# ── launcher_cleanup_legacy ────────────────────────────────────────────────
# Remove the pre-rename "Just Vibes.app" bundle after JustVibes.app has been
# installed or verified. The ownership guard ensures we only delete bundles
# with this bootstrap's CFBundleIdentifier.
#
# Args:
#   $1: dest_dir — resolved destination directory containing JustVibes.app
#
# Returns: 0 always; cleanup and LaunchServices registration are best-effort.
launcher_cleanup_legacy() {
  local dest_dir="$1"
  local -a search_dirs unique_dirs
  local d seen_dir duplicate dir old_app old_id new_app lsregister

  search_dirs=("$dest_dir")
  if [ -z "${JUSTVIBES_DEST_DIR_OVERRIDE:-}" ]; then
    [ "$dest_dir" != "$HOME/Applications" ] && search_dirs+=("$HOME/Applications")
    [ "$dest_dir" != "/Applications" ] && search_dirs+=("/Applications")
  fi

  unique_dirs=()
  for d in "${search_dirs[@]}"; do
    duplicate=0
    if [ "${#unique_dirs[@]}" -gt 0 ]; then
      for seen_dir in "${unique_dirs[@]}"; do
        if [ "$seen_dir" = "$d" ]; then
          duplicate=1
          break
        fi
      done
    fi
    [ "$duplicate" -eq 1 ] && continue
    unique_dirs+=("$d")
  done

  for dir in "${unique_dirs[@]}"; do
    old_app="$dir/Just Vibes.app"
    [ -d "$old_app" ] || continue

    old_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$old_app/Contents/Info.plist" 2>/dev/null) || continue
    [ "$old_id" = "dev.aibootstrap.justvibes" ] || continue

    if [ -z "${JUSTVIBES_DEST_DIR_OVERRIDE:-}" ]; then
      lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
      "$lsregister" -u "$old_app" 2>/dev/null || true
    fi

    if ! rm -rf "$old_app" 2>/dev/null; then
      if declare -F log_warn >/dev/null 2>&1; then
        log_warn "Could not remove legacy app: $old_app"
      else
        echo "launcher_cleanup_legacy: could not remove legacy app: $old_app" >&2
      fi
    fi
  done

  if [ -z "${JUSTVIBES_DEST_DIR_OVERRIDE:-}" ]; then
    new_app="$dest_dir/JustVibes.app"
    lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
    "$lsregister" "$new_app" 2>/dev/null || true
  fi

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
  local bundle="$dest_dir/JustVibes.app"

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
