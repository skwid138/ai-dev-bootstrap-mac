#!/bin/bash
# PATH additions and tool hooks.

# Homebrew path (arm64 vs x86_64)
if [ "$(uname -m)" = "arm64" ]; then
  export PATH="/opt/homebrew/bin:$PATH"
else
  export PATH="/usr/local/bin:$PATH"
fi

# mise activation (if installed)
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# direnv hook (if installed)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
