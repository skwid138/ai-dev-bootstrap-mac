#!/bin/bash
# VS Code installer.
# This module is sourced by bootstrap.sh (not executed standalone).

install_brew_cask "visual-studio-code"

# Configure git's editor after VS Code is installed so first-run setups can
# prefer `code --wait` when available without racing the cask install.
# shellcheck source=lib/git.sh
source "${BOOTSTRAP_DIR}/lib/git.sh"

editor="$(git_choose_editor)"
if [ -n "$editor" ]; then
  case "$(git_set_default_if_unset "core.editor" "$editor")" in
    set) log_installed "git: core.editor='$editor'" ;;
    kept) log_skip "git: core.editor already set" ;;
  esac
fi
