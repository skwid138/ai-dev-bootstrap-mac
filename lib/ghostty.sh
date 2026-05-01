#!/bin/bash
# Ghostty configuration helpers.
#
# Two responsibilities, factored out of modules/03-terminal.sh so each
# is independently testable with bats and has a clear contract:
#
#   ghostty_deploy_config — install ghostty/config.template into
#                            ~/.config/ghostty/config IFF the destination
#                            doesn't exist. Same overwrite-protect model
#                            as opencode_deploy_agents_md: a returning
#                            user keeps their tweaks; a fresh install
#                            gets sane defaults.
#
# Why overwrite-protect (not "always overwrite"):
#   The ghostty config is the user's primary visual experience — theme,
#   font, padding. Even non-techy users will tweak it. Stomping it on
#   every bootstrap re-run breaks trust. AGENTS.md uses the same model
#   for the same reason; we're consistent.
#
# Trade-off: returning users won't pick up changes we make to the
# template. Acceptable because:
#   1. Ghostty config rarely needs bootstrap-driven updates (it's
#      personal preference, not security-critical).
#   2. The template comment tells users where to find current options
#      (`ghostty +list-themes` etc.) — they're not blocked from
#      discovering newer features.
#
# If we ever DO need to ship a config-breaking change, the right path
# is: rename the file (config -> config.bak) with a log_warn explaining
# what happened. We don't have that need today.

# ── ghostty_deploy_config ───────────────────────────────────────────────────
# Args:
#   $1: src  — absolute path to ghostty/config.template
#   $2: dest — absolute path to ~/.config/ghostty/config
#
# Stdout: one of "installed" | "skipped"
# Returns:
#   0  on success (whether installed or skipped)
#   1  if src is missing or copy fails
ghostty_deploy_config() {
  local src="$1"
  local dest="$2"

  if [ ! -f "$src" ]; then
    echo "ghostty_deploy_config: source not found: $src" >&2
    return 1
  fi

  if [ -e "$dest" ]; then
    echo "skipped"
    return 0
  fi

  local dest_dir
  dest_dir=$(dirname "$dest")
  if ! mkdir -p "$dest_dir"; then
    echo "ghostty_deploy_config: failed to create $dest_dir" >&2
    return 1
  fi

  if ! cp "$src" "$dest"; then
    echo "ghostty_deploy_config: failed to copy $src -> $dest" >&2
    return 1
  fi

  echo "installed"
  return 0
}
