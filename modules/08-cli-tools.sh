#!/bin/bash
# CLI tools installer.
# This module is sourced by bootstrap.sh (not executed standalone).

install_if_selected() {
  local key="$1"
  local formula="$2"
  local selected=false

  for pkg in "${SELECTED_PACKAGES[@]}"; do
    if [ "$pkg" = "$key" ]; then
      selected=true
      break
    fi
  done

  if $selected; then
    install_brew_formula "$formula"
  fi
}

install_if_selected "ripgrep" "ripgrep"
install_if_selected "jq" "jq"
install_if_selected "fd" "fd"
install_if_selected "tmux" "tmux"
install_if_selected "btop" "btop"

install_if_selected "direnv" "direnv"
# direnv hook is handled by dotfiles/paths.sh
