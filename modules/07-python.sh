#!/bin/bash
# Python setup (uv + Python via mise).
# This module is sourced by bootstrap.sh (not executed standalone).

install_brew_formula "uv"

# Install Python via mise if selected.
install_python=false
for pkg in "${SELECTED_PACKAGES[@]}"; do
  if [ "$pkg" = "python" ]; then
    install_python=true
    break
  fi
done

if $install_python; then
  if command_exists mise; then
    if ui_spin "Installing Python (latest)..." mise install python@latest; then
      if mise use --global python@latest >/dev/null 2>&1; then
        log_installed "python@latest"
        RESULTS_INSTALLED+=("python@latest")
      else
        log_error "Failed to set python@latest globally"
        RESULTS_FAILED+=("python@latest")
      fi
    else
      log_error "Failed to install python@latest"
      RESULTS_FAILED+=("python@latest")
    fi
  else
    log_error "mise is not available to install python@latest"
    RESULTS_FAILED+=("python@latest")
  fi
fi
