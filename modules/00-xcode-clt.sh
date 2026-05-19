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

XCODE_CLT_TIMEOUT_SECONDS="${XCODE_CLT_TIMEOUT_SECONDS:-900}"
XCODE_CLT_POLL_SECONDS="${XCODE_CLT_POLL_SECONDS:-20}"
XCODE_CLT_WAIT_STARTED_SECONDS=$SECONDS

log_info "Waiting for $XCODE_CLT_NAME installation to complete..."
log_info "Look for the install popup and approve it if macOS prompts you."
until xcode-select -p >/dev/null 2>&1; do
  if [ $((SECONDS - XCODE_CLT_WAIT_STARTED_SECONDS)) -ge "$XCODE_CLT_TIMEOUT_SECONDS" ]; then
    log_error "$XCODE_CLT_NAME install timed out after ${XCODE_CLT_TIMEOUT_SECONDS}s"
    RESULTS_FAILED+=("$XCODE_CLT_KEY")
    return 1
  fi
  sleep "$XCODE_CLT_POLL_SECONDS"
done

log_installed "$XCODE_CLT_NAME"
RESULTS_INSTALLED+=("$XCODE_CLT_KEY")
