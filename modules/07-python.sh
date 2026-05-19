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
        log_error "Python installed, but we could not make it the default. Open a new terminal and run: mise use --global python@latest"
        RESULTS_FAILED+=("python@latest")
      fi
    else
      log_error "Could not install Python. Check the mise message above, then run this installer again."
      RESULTS_FAILED+=("python@latest")
    fi
  else
    log_error "mise is not available, so Python cannot be installed yet. Run this installer again and keep the Essential runtime tools selected."
    RESULTS_FAILED+=("python@latest")
  fi
fi
