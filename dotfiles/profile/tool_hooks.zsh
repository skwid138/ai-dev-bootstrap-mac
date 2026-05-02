# profile/tool_hooks.zsh — login-tier tool activation
#
# Loaded by init_profile.zsh from ~/.zprofile. Runs once per login shell.
# Conditionally copied by modules/10-shell-config.sh only when mise is selected.
#
# Contract:
#   - mise activate runs here so non-interactive login shells (zsh -l -c)
#     get mise shims on PATH. The launcher's planned `zsh -l -i -c` path
#     depends on this. See §3.7 of the plan.
#   - direnv hook does NOT run here — it's interactive-only and lives in
#     rc/tool_hooks.zsh.
#   - command -v gated: silent skip if mise is uninstalled.

# Defensive guard (§4 contracts table): if mise is not installed, return
# cleanly so this file can be sourced unconditionally without erroring.
command -v mise >/dev/null 2>&1 || return 0

eval "$(mise activate zsh)"
