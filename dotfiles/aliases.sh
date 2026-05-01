#!/bin/bash
# Beginner-friendly aliases.

alias ll="ls -la"
alias la="ls -A"
alias ..="cd .."
alias ...="cd ../.."
alias gs="git status"
alias gp="git pull"
alias c="code ."
alias oc="opencode"

# Workspace shortcut. Sources the bootstrap state file (written by
# bootstrap.sh) so the alias adapts if the user re-runs bootstrap with
# a different workspace path. If state.sh is missing or doesn't define
# AI_BOOTSTRAP_WORKSPACE, the alias becomes a no-op rather than an
# error — preserves the user's prompt and lets them notice.
if [ -f "$HOME/.config/ai-bootstrap/state.sh" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.config/ai-bootstrap/state.sh"
fi

if [ -n "${AI_BOOTSTRAP_WORKSPACE:-}" ]; then
  alias cdc='cd "$AI_BOOTSTRAP_WORKSPACE"'
fi
