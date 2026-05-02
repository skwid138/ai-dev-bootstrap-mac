# rc/zsh_config.zsh — interactive-tier zsh configuration
#
# Loaded by init_rc.zsh from ~/.zshrc. History, completion styles, options.
#
# Contract:
#   - Interactive-only configuration; safe to skip in non-interactive shells.
#   - No command substitution that touches the network or filesystem heavily.

# Case-insensitive completion.
#   m:{a-z}={A-Z} — match lowercase to uppercase
#   m:{A-Z}={a-z} — match uppercase to lowercase
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# History settings.
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
