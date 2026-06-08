#!/bin/bash
# Pre-flight validation checks.

# shellcheck source=lib/ui.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ui.sh"

check_macos() {
  local version
  local major

  version=$(sw_vers -productVersion)
  major=${version%%.*}

  if [ "$major" -lt 15 ]; then
    ui_error "macOS 15 (Sequoia) or newer is required. Detected: $version"
    return 1
  fi

  return 0
}

check_architecture() {
  local arch
  arch=$(uname -m)

  if [ "$arch" = "arm64" ]; then
    ARCH="arm64"
  else
    ARCH="x86_64"
  fi

  export ARCH
  return 0
}

# Disk space is intentionally advisory. Preflight runs before tier selection
# (bootstrap.sh:474 before :516-564) and before Homebrew install (module 01 at
# :493-496), so the actual size requirement is unknown here and any threshold is
# a guess. Blocking has little extra "cannot cause harm" value because safe
# re-runs fix partial state and Homebrew resumes, while a flat hard-block could
# falsely stop a small-tier user and leave them stuck. See
# docs/adr/0001-disk-space-preflight-is-advisory.md for the full decision.
warn_disk_space() {
  local available_kb available_gb

  available_kb="$(df -Pk / 2>/dev/null | awk 'NR==2 {print $4}' || true)"
  case "$available_kb" in
    "" | *[!0-9]*) available_kb=0 ;;
  esac
  available_gb=$((available_kb / 1024 / 1024))

  if [ "$available_gb" -lt 10 ]; then
    ui_warn "You have about ${available_gb}GB of free space. Installing everything may need a bit more than that. Setup will continue — but if you're low, freeing up some space first can help things go smoothly."
  fi

  return 0
}

check_not_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    ui_error "Do not run this installer as root."
    return 1
  fi

  return 0
}

run_preflight() {
  check_not_root || exit 1
  check_macos || exit 1
  check_architecture || exit 1
  warn_disk_space
}
