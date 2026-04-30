#!/bin/bash
# Shared helpers used by all modules.

# Detect bootstrap directory from this script location.
BOOTSTRAP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Source UI helpers for spinners and styled messages.
# shellcheck source=lib/ui.sh
source "${BOOTSTRAP_DIR}/lib/ui.sh"

# Results tracking arrays.
RESULTS_INSTALLED=()
RESULTS_SKIPPED=()
RESULTS_FAILED=()

# Basic colored logging with emoji prefixes.
COLOR_RESET="\033[0m"
COLOR_INFO="\033[36m"
COLOR_WARN="\033[33m"
COLOR_ERROR="\033[31m"
COLOR_SKIP="\033[35m"
COLOR_SUCCESS="\033[32m"

log_info() {
  echo -e "${COLOR_INFO}ℹ️  $*${COLOR_RESET}"
}

log_warn() {
  echo -e "${COLOR_WARN}⚠️  $*${COLOR_RESET}"
}

log_error() {
  echo -e "${COLOR_ERROR}❌ $*${COLOR_RESET}"
}

log_skip() {
  echo -e "${COLOR_SKIP}⏭️  $*${COLOR_RESET}"
}

log_installed() {
  echo -e "${COLOR_SUCCESS}✅ $*${COLOR_RESET}"
}

# Check if a package key is in the SELECTED_PACKAGES array.
is_selected() {
  local key="$1"
  local pkg
  for pkg in "${SELECTED_PACKAGES[@]}"; do
    if [ "$pkg" = "$key" ]; then
      return 0
    fi
  done
  return 1
}

# Check if a command exists.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Ensure a directory exists.
ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

# Append a line to a file if it does not already exist.
append_line_if_missing() {
  local line="$1"
  local file="$2"

  ensure_dir "$(dirname "$file")"
  touch "$file"

  if ! grep -Fq "$line" "$file"; then
    echo "$line" >>"$file"
  fi
}

# Install a brew formula if missing.
install_brew_formula() {
  local formula="$1"

  if brew list "$formula" >/dev/null 2>&1; then
    log_skip "$formula"
    RESULTS_SKIPPED+=("$formula")
    return 0
  fi

  if ui_spin "Installing $formula..." brew install "$formula"; then
    log_installed "$formula"
    RESULTS_INSTALLED+=("$formula")
    return 0
  fi

  log_error "Failed to install $formula"
  RESULTS_FAILED+=("$formula")
  return 1
}

# Install a brew cask if missing.
install_brew_cask() {
  local cask="$1"

  if brew list --cask "$cask" >/dev/null 2>&1; then
    log_skip "$cask"
    RESULTS_SKIPPED+=("$cask")
    return 0
  fi

  if ui_spin "Installing $cask..." brew install --cask "$cask"; then
    log_installed "$cask"
    RESULTS_INSTALLED+=("$cask")
    return 0
  fi

  log_error "Failed to install $cask"
  RESULTS_FAILED+=("$cask")
  return 1
}

# Install a mise runtime if missing.
install_mise_runtime() {
  local runtime="$1"

  if ! command_exists mise; then
    log_error "mise is not installed"
    RESULTS_FAILED+=("$runtime")
    return 1
  fi

  if mise list "$runtime" >/dev/null 2>&1; then
    log_skip "$runtime"
    RESULTS_SKIPPED+=("$runtime")
    return 0
  fi

  if ui_spin "Installing $runtime..." mise install "$runtime"; then
    log_installed "$runtime"
    RESULTS_INSTALLED+=("$runtime")
    return 0
  fi

  log_error "Failed to install $runtime"
  RESULTS_FAILED+=("$runtime")
  return 1
}
