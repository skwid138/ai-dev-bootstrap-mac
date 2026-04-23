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
        log_error "Failed to set node@lts globally"
        RESULTS_FAILED+=("node@lts")
      fi
    else
      log_error "Failed to install node@lts"
      RESULTS_FAILED+=("node@lts")
    fi
  else
    log_error "mise is not available to install node@lts"
    RESULTS_FAILED+=("node@lts")
  fi
fi
