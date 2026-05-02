# rc/zsh_plugins.zsh — interactive-tier zplug + Spaceship prompt
#
# Loaded by init_rc.zsh from ~/.zshrc. Conditionally copied by
# modules/10-shell-config.sh only when zplug is selected.
#
# Contract:
#   - Defensive: if zplug binary is missing (e.g. user `brew uninstall zplug`
#     and didn't re-run bootstrap), return cleanly without error.
#   - Interactive-only — plugins, prompt, syntax highlighting are pointless
#     in non-interactive shells.

# Defensive guard (§4 contracts table): if zplug formula is uninstalled,
# return cleanly. Don't error; the user may simply not have zplug.
command -v zplug >/dev/null 2>&1 || return 0

# Source zplug's init.zsh from the brew-installed location.
if [[ -f "/opt/homebrew/opt/zplug/init.zsh" ]]; then
  source "/opt/homebrew/opt/zplug/init.zsh"
elif [[ -f "/usr/local/opt/zplug/init.zsh" ]]; then
  source "/usr/local/opt/zplug/init.zsh"
else
  return 0
fi

# Define plugins.
zplug "spaceship-prompt/spaceship-prompt", use:spaceship.zsh, from:github, as:theme
zplug "zsh-users/zsh-syntax-highlighting", defer:2
zplug "zsh-users/zsh-autosuggestions"

# Auto-install missing plugins.
if ! zplug check; then
  zplug install
fi

# Load plugins.
zplug load

# Spaceship prompt configuration (simplified).
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
