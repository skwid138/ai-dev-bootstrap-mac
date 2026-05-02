# init_profile.zsh — profile-tier barrel (login shells)
#
# Sourced from ~/.zprofile. Runs once per login shell, between
# ~/.zshenv and ~/.zshrc. Login shells include: ssh, GUI re-login,
# `zsh -l`, `login -flp ... zsh`, and the Vibe Code launcher's
# planned `zsh -l -i -c` invocation.
#
# Contract:
#   - First action: re-source init_env.zsh to undo macOS path_helper
#     demotion. /etc/zprofile runs path_helper between .zshenv and
#     .zprofile, rebuilding PATH with /usr/bin first and demoting
#     /opt/homebrew/bin. Without this re-source, command -v bash
#     resolves to /bin/bash 3.2 instead of Homebrew bash. See §3.6
#     of the plan and personal-plan commit e734716.
#   - Profile-tier tool activation (mise) lives in profile/tool_hooks.zsh.
#   - Sentinel-guarded against double-source.

[[ -n "${_AI_BOOTSTRAP_INIT_PROFILE_LOADED:-}" ]] && return
_AI_BOOTSTRAP_INIT_PROFILE_LOADED=1

_AI_BOOTSTRAP_SHELL_DIR="${HOME}/.config/ai-bootstrap/shell"

# 1. Recover from path_helper: re-source env-tier (idempotent thanks to
#    the load-once sentinel — but we WANT to re-run paths.zsh to call
#    _path_prepend, which has promotion semantics. So clear the env-tier
#    sentinel first, re-source the barrel, then move on.
unset _AI_BOOTSTRAP_INIT_ENV_LOADED
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/init_env.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/init_env.zsh"

# 2. Profile-tier tool hooks (mise). Conditionally installed by the module.
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/profile/tool_hooks.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/profile/tool_hooks.zsh"

# 3. Optional login/*.zsh files (none ship today; reserved for future use).
if [[ -d "${_AI_BOOTSTRAP_SHELL_DIR}/login" ]]; then
  for _f in "${_AI_BOOTSTRAP_SHELL_DIR}"/login/*.zsh(.N); do
    source "$_f"
  done
  unset _f
fi

return 0
