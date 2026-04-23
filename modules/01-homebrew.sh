#!/bin/bash
# Homebrew installer and updater.
# This module is sourced by bootstrap.sh (not executed standalone).

HOMEBREW_NAME="Homebrew"
HOMEBREW_KEY="homebrew"

if command_exists brew; then
  log_info "Updating $HOMEBREW_NAME..."
  if ui_spin "Running brew update..." brew update; then
    log_installed "$HOMEBREW_NAME updated"
    RESULTS_INSTALLED+=("$HOMEBREW_KEY")
  else
    log_error "Failed to update $HOMEBREW_NAME"
    RESULTS_FAILED+=("$HOMEBREW_KEY")
  fi
else
  log_info "Installing $HOMEBREW_NAME..."
  if ui_spin "Installing Homebrew..." /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    log_installed "$HOMEBREW_NAME"
    RESULTS_INSTALLED+=("$HOMEBREW_KEY")
  else
    log_error "Failed to install $HOMEBREW_NAME"
    RESULTS_FAILED+=("$HOMEBREW_KEY")
    return 1
  fi
fi

# Ensure brew is available in this shell session.
if [ -x "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
