#!/bin/bash
# Terminal emulator: install ghostty + its companion font, then deploy
# our curated default config (overwrite-protected).
#
# This module is sourced by bootstrap.sh (not executed standalone).
#
# Why install the Nerd Font alongside ghostty:
#   The default config references JetBrainsMono Nerd Font. If it's
#   missing, ghostty silently falls back to a system font — which works
#   but loses the icon glyphs that some TUIs use. Shipping the font
#   makes the default config "just work" out of the box. Cost is ~10MB
#   download.

# shellcheck source=lib/ghostty.sh
source "${BOOTSTRAP_DIR}/lib/ghostty.sh"
# shellcheck source=lib/launcher.sh
source "${BOOTSTRAP_DIR}/lib/launcher.sh"

install_brew_cask "ghostty"
install_brew_cask "font-jetbrains-mono-nerd-font"

GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
ensure_dir "$GHOSTTY_CONFIG_DIR"

ghostty_result=$(ghostty_deploy_config \
  "${BOOTSTRAP_DIR}/ghostty/config.template" \
  "$GHOSTTY_CONFIG_DIR/config")

case "$ghostty_result" in
  installed) log_installed "Ghostty config installed" ;;
  skipped) log_skip "Ghostty config already exists (preserving your edits)" ;;
  *) log_error "Ghostty config deployment returned unexpected: $ghostty_result" ;;
esac

# Build & install the one-click "Vibe Code" launcher. Prefers /Applications
# (where users actually look first) and falls back to ~/Applications on
# corp-managed Macs / non-admin accounts where /Applications is read-only.
# Always rebuilt on bootstrap re-run so users pick up any launch.sh fixes
# we ship; the .app contains no user-editable content (toggles live in
# env vars, not the script body).
LAUNCHER_DEST=$(launcher_resolve_dest)
launcher_result=$(launcher_install \
  "${BOOTSTRAP_DIR}/launcher/build.sh" \
  "$LAUNCHER_DEST")

case "$launcher_result" in
  installed)
    log_installed "Vibe Code.app installed to $LAUNCHER_DEST"
    # Friendly heads-up if we landed in ~/Applications instead of the
    # standard /Applications. This only happens on locked-down Macs;
    # the message tells the user where to find it without requiring
    # them to know about ~/Applications as a separate folder.
    if [ "$LAUNCHER_DEST" = "$HOME/Applications" ]; then
      log_info "Note: /Applications is read-only on this Mac, so we"
      log_info "installed to ~/Applications instead. Spotlight, LaunchPad,"
      log_info "and Finder will all find it there."
    fi
    ;;
  *) log_error "Vibe Code launcher install returned unexpected: $launcher_result" ;;
esac
