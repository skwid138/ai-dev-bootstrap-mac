# init_env.zsh — env-tier barrel
#
# Sourced from ~/.zshenv. Runs in EVERY shell zsh starts: login,
# non-login, interactive, non-interactive, scripts, subshells.
#
# Contract:
#   - MUST be silent on stdout AND stderr.
#   - MUST NOT call mise activate, direnv hook, or anything that takes >5ms.
#   - MUST NOT print warnings, version checks, or staleness nags.
#   - Sentinel-guarded against double-source.
#
# Why this matters: subshells launched by the Vibe Code launcher, by
# opencode tool calls, and by GUI integrations inherit this PATH. Output
# here pollutes script stdout (e.g. `zsh -c 'echo $X' | tool` breaks).

[[ -n "${_AI_BOOTSTRAP_INIT_ENV_LOADED:-}" ]] && return
_AI_BOOTSTRAP_INIT_ENV_LOADED=1

_AI_BOOTSTRAP_SHELL_DIR="${HOME}/.config/ai-bootstrap/shell"

# lib first — defines _path_prepend used by env/paths.zsh.
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/lib/path_helpers.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/lib/path_helpers.zsh"

# env-tier files.
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/env/vars.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/env/vars.zsh"
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/env/paths.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/env/paths.zsh"

return 0
