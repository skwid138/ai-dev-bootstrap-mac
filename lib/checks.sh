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

check_disk_space() {
  local available_kb
  local available_gb

  available_kb=$(df -Pk / | awk 'NR==2 {print $4}')
  available_gb=$((available_kb / 1024 / 1024))

  if [ "$available_gb" -lt 10 ]; then
    ui_warn "Less than 10GB free disk space detected (~${available_gb}GB)."
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
  check_disk_space || true
}
