#!/bin/bash
# Optional extras.
# This module is sourced by bootstrap.sh (not executed standalone).

if is_selected "playwright"; then
  if command_exists node; then
    ui_spin "Installing Playwright (npm)..." npm install -g playwright
    log_installed "playwright"
    log_info "Playwright needs one more step before it can control browsers. After this installer finishes, open a terminal and run:  npx playwright install"
  else
    log_error "Playwright needs Node.js first. Run this installer again with Node.js selected, then run: npx playwright install"
    RESULTS_FAILED+=("playwright")
  fi
fi

if is_selected "shfmt"; then
  install_brew_formula "shfmt"
fi

if is_selected "ffmpeg"; then
  install_brew_formula "ffmpeg"
fi

if is_selected "imagemagick"; then
  install_brew_formula "imagemagick"
fi
