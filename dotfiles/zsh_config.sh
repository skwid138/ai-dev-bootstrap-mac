#!/bin/bash
# Zsh quality-of-life configuration.

# Case-insensitive completion
# m:{a-z}={A-Z} - Match lowercase to uppercase
# m:{A-Z}={a-z} - Match uppercase to lowercase
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# History settings
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
