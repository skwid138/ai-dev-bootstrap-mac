# rc/tool_hooks.zsh — interactive-tier tool hooks
#
# Loaded by init_rc.zsh from ~/.zshrc. Conditionally copied by
# modules/10-shell-config.sh only when mise OR direnv is selected.
#
# Contract:
#   - direnv hook is interactive-only by design (preexec/chpwd hooks are
#     meaningless in non-interactive shells; potentially harmful in cron).
#   - mise activate is re-run here for non-login interactive shells (e.g.
#     `zsh -i` from inside an existing terminal); login interactive shells
#     already activated mise via profile/tool_hooks.zsh — re-activation is
#     idempotent. See §3.7 of the plan.
#   - Each hook is independently `command -v`-gated.

# mise: idempotent re-activation for non-login interactive shells.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# direnv: interactive-only hook registration.
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
