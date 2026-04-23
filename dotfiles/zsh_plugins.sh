#!/bin/bash
# Zplug plugins and Spaceship prompt.

# Source zplug if installed.
if [ -f "/opt/homebrew/opt/zplug/init.zsh" ]; then
  source "/opt/homebrew/opt/zplug/init.zsh"
elif [ -f "/usr/local/opt/zplug/init.zsh" ]; then
  source "/usr/local/opt/zplug/init.zsh"
else
  return 0
fi

# Define plugins
zplug "spaceship-prompt/spaceship-prompt", use:spaceship.zsh, from:github, as:theme
zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-autosuggestions"

# Auto-install missing plugins
if ! zplug check; then
  zplug install
fi

# Load plugins
zplug load

# Spaceship prompt configuration (simplified)
SPACESHIP_PROMPT_ORDER=(
  dir
  git
  exec_time
  line_sep
  char
)
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_CHAR_SYMBOL="❯"
SPACESHIP_CHAR_SUFFIX=" "
