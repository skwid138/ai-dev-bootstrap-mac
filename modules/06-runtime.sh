#!/bin/bash
# Runtime setup (mise + Node.js).
# This module is sourced by bootstrap.sh (not executed standalone).

install_brew_formula "mise"

# Activate mise for current session (shell config in dotfiles/paths.sh handles future sessions).
if command_exists mise; then
  eval "$(mise activate bash)"
fi

# Install Node.js LTS if selected.
install_node=false
for pkg in "${SELECTED_PACKAGES[@]}"; do
  if [ "$pkg" = "node_lts" ]; then
    install_node=true
    break
  fi
done

if $install_node; then
  if command_exists mise; then
    if ui_spin "Installing Node.js LTS..." mise install node@lts; then
      if mise use --global node@lts >/dev/null 2>&1; then
        log_installed "node@lts"
        RESULTS_INSTALLED+=("node@lts")
      else
        log_error "Node.js installed, but we could not make it the default. Open a new terminal and run: mise use --global node@lts"
        RESULTS_FAILED+=("node@lts")
      fi
    else
      log_error "Could not install Node.js LTS. Check the mise message above, then run this installer again."
      RESULTS_FAILED+=("node@lts")
    fi
  else
    log_error "mise is not available, so Node.js cannot be installed yet. Run this installer again and keep the Essential runtime tools selected."
    RESULTS_FAILED+=("node@lts")
  fi
fi
