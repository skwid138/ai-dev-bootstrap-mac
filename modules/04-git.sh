#!/bin/bash
# Git and GitHub CLI setup.
# This module is sourced by bootstrap.sh (not executed standalone).

install_brew_formula "git"
install_brew_formula "gh"

# Ensure GitHub CLI is authenticated.
if command_exists gh; then
  if ! gh auth status >/dev/null 2>&1; then
    log_info "GitHub CLI is not authenticated yet."
    log_info "Starting GitHub authentication..."
    gh auth login
  else
    log_skip "gh already authenticated"
  fi
fi
