#!/bin/bash
# Configure modular shell dotfiles.
# This module is sourced by bootstrap.sh (not executed standalone).

SHELL_CONFIG_DIR="$HOME/.config/ai-bootstrap/shell"
ensure_dir "$SHELL_CONFIG_DIR"

# Install zplug if selected.
if is_selected "zplug"; then
  install_brew_formula "zplug"
fi

# Copy base dotfiles (always).
cp "${BOOTSTRAP_DIR}/dotfiles/init.sh" "$SHELL_CONFIG_DIR/init.sh"
cp "${BOOTSTRAP_DIR}/dotfiles/vars.sh" "$SHELL_CONFIG_DIR/vars.sh"
cp "${BOOTSTRAP_DIR}/dotfiles/paths.sh" "$SHELL_CONFIG_DIR/paths.sh"
cp "${BOOTSTRAP_DIR}/dotfiles/zsh_config.sh" "$SHELL_CONFIG_DIR/zsh_config.sh"
cp "${BOOTSTRAP_DIR}/dotfiles/aliases.sh" "$SHELL_CONFIG_DIR/aliases.sh"

# Copy plugin config only when zplug is selected.
if is_selected "zplug"; then
  cp "${BOOTSTRAP_DIR}/dotfiles/zsh_plugins.sh" "$SHELL_CONFIG_DIR/zsh_plugins.sh"
fi

# Add a guarded source line to ~/.zshrc without overwriting existing content.
append_line_if_missing "[[ -f ~/.config/ai-bootstrap/shell/init.sh ]] && source ~/.config/ai-bootstrap/shell/init.sh" "$HOME/.zshrc"
