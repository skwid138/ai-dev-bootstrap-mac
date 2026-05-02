# paths.zsh — env-tier PATH setup
#
# Loaded by init_env.zsh from ~/.zshenv. Also re-sourced by init_profile.zsh
# to recover from macOS path_helper demotion (§3.6).
#
# Contract:
#   - MUST be silent on stdout AND stderr.
#   - MUST use _path_prepend (idempotent + promotion-aware).
#   - MUST NOT call mise activate, direnv hook, or anything that takes >5ms.
#
# Install-time substitution:
#   The literal __BREW_PREFIX__ below is replaced by modules/10-shell-config.sh
#   with the resolved `brew --prefix` value (e.g. /opt/homebrew on Apple Silicon,
#   /usr/local on Intel) when the file is copied to the install dir.

# Homebrew bin: promote to front of PATH (handles path_helper demotion).
_path_prepend "__BREW_PREFIX__/bin"
_path_prepend "__BREW_PREFIX__/sbin"
