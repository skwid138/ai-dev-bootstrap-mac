# vars.zsh — env-tier environment variables
#
# Loaded by init_env.zsh from ~/.zshenv. Runs in EVERY shell (login,
# interactive, non-interactive, scripts). Keep minimal and silent.
#
# Contract:
#   - MUST be silent on stdout AND stderr.
#   - Only env-eligible vars (EDITOR, LANG, etc.). No PATH (see paths.zsh).
#   - No tool activation, no command substitution beyond trivial.

# Default editor.
export EDITOR="code"

# Locale.
export LANG="en_US.UTF-8"

# API keys (optional). The opencode module can append these.
# export OPENAI_API_KEY=""
# export ANTHROPIC_API_KEY=""
# export GITHUB_TOKEN=""
