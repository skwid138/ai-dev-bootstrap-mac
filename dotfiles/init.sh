#!/bin/bash
# Barrel file sourced from ~/.zshrc.
# Loads individual shell config files if present.

# Determine config directory for both zsh and bash.
if [ -n "${ZSH_VERSION:-}" ]; then
  SHELL_CONFIG_DIR="${0:A:h}"
  if [ "$SHELL_CONFIG_DIR" = "." ]; then
    SHELL_CONFIG_DIR="$HOME/.config/ai-bootstrap/shell"
  fi
elif [ -n "${BASH_VERSION:-}" ]; then
  SHELL_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SHELL_CONFIG_DIR="$HOME/.config/ai-bootstrap/shell"
fi

# Core environment
[ -f "$SHELL_CONFIG_DIR/vars.sh" ] && source "$SHELL_CONFIG_DIR/vars.sh"
[ -f "$SHELL_CONFIG_DIR/paths.sh" ] && source "$SHELL_CONFIG_DIR/paths.sh"

# Shell customizations
[ -f "$SHELL_CONFIG_DIR/zsh_config.sh" ] && source "$SHELL_CONFIG_DIR/zsh_config.sh"
[ -f "$SHELL_CONFIG_DIR/zsh_plugins.sh" ] && source "$SHELL_CONFIG_DIR/zsh_plugins.sh"
[ -f "$SHELL_CONFIG_DIR/aliases.sh" ] && source "$SHELL_CONFIG_DIR/aliases.sh"
