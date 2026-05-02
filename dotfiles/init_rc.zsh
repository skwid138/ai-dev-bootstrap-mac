# init_rc.zsh — interactive-tier barrel
#
# Sourced from ~/.zshrc. Runs once per interactive shell (and only in
# interactive shells — non-interactive zsh does not source ~/.zshrc).
#
# Contract:
#   - Order: zsh_config → zsh_plugins → tool_hooks → aliases → compinit.
#   - Each sub-file is existence-gated; missing files are silent no-ops.
#   - Sentinel-guarded against double-source.
#   - compinit runs once per day per host (cache file ttl).

[[ -n "${_AI_BOOTSTRAP_INIT_RC_LOADED:-}" ]] && return
_AI_BOOTSTRAP_INIT_RC_LOADED=1

_AI_BOOTSTRAP_SHELL_DIR="${HOME}/.config/ai-bootstrap/shell"

# 1. Zsh config: history, completion styles, options.
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/rc/zsh_config.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/rc/zsh_config.zsh"

# 2. Plugins (zplug + Spaceship). Conditionally installed.
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/rc/zsh_plugins.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/rc/zsh_plugins.zsh"

# 3. Tool hooks (mise re-activate + direnv hook). Conditionally installed.
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/rc/tool_hooks.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/rc/tool_hooks.zsh"

# 4. Aliases.
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/rc/aliases.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/rc/aliases.zsh"

# 5. compinit with daily cache. Saves 15-50ms on warm shells.
#    Single-fire via _COMPINIT_DONE sentinel (shared with other barrel chains
#    on the dev machine — first-source wins, second is no-op).
if [[ -z "${_COMPINIT_DONE:-}" ]]; then
  _COMPINIT_DONE=1
  autoload -Uz compinit
  # -C: skip the security check + dump-rebuild if the dump is fresh today.
  compinit -C
fi

return 0
