#!/bin/bash
# Xcode Command Line Tools installer.
# This module is sourced by bootstrap.sh (not executed standalone).

XCODE_CLT_NAME="Xcode Command Line Tools"
XCODE_CLT_KEY="xcode-clt"

if xcode-select -p >/dev/null 2>&1; then
  log_skip "$XCODE_CLT_NAME"
  RESULTS_SKIPPED+=("$XCODE_CLT_KEY")
  return 0
fi

log_info "Installing $XCODE_CLT_NAME..."

# Trigger the installer (may exit non-zero if already running).
xcode-select --install >/dev/null 2>&1 || true

log_info "Waiting for $XCODE_CLT_NAME installation to complete..."
until xcode-select -p >/dev/null 2>&1; do
  sleep 20
done

log_installed "$XCODE_CLT_NAME"
RESULTS_INSTALLED+=("$XCODE_CLT_KEY")
