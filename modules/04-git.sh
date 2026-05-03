#!/bin/bash
# Git and GitHub CLI setup + sensible global defaults.
# This module is sourced by bootstrap.sh (not executed standalone).

# shellcheck source=lib/git.sh
source "${BOOTSTRAP_DIR}/lib/git.sh"

install_brew_formula "git"
install_brew_formula "gh"

# ── GitHub CLI auth ─────────────────────────────────────────────────────────
if command_exists gh; then
  if ! gh auth status >/dev/null 2>&1; then
    if [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
      # `gh auth login` blocks on a device-code flow that needs a human.
      # In headless mode (notably the GHA e2e-launcher workflow) we skip
      # it — auth is the user's job to complete on first interactive run.
      log_skip "gh auth (non-interactive: skipped device-code login)"
    else
      log_info "GitHub CLI is not authenticated yet."
      log_info "Starting GitHub authentication..."
      gh auth login
    fi
  else
    log_skip "gh already authenticated"
  fi
fi

# ── Sensible global git defaults ────────────────────────────────────────────
# Each is set only if currently unset, so we never overwrite a returning
# user's deliberate config. The git_set_default_if_unset helper echoes
# 'set' or 'kept' so we can give clear log output.
log_info "Configuring git defaults..."

# Default branch name for `git init`.
case "$(git_set_default_if_unset init.defaultBranch main)" in
  set) log_installed "git: init.defaultBranch=main" ;;
  kept) log_skip "git: init.defaultBranch already set" ;;
esac

# Merge (not rebase) on pull — safer for non-techy users.
case "$(git_set_default_if_unset pull.rebase false)" in
  set) log_installed "git: pull.rebase=false" ;;
  kept) log_skip "git: pull.rebase already set" ;;
esac

# Editor: VS Code if installed, else nano, else leave unset.
git_editor_choice=$(git_choose_editor)
if [ -n "$git_editor_choice" ]; then
  case "$(git_set_default_if_unset core.editor "$git_editor_choice")" in
    set) log_installed "git: core.editor='$git_editor_choice'" ;;
    kept) log_skip "git: core.editor already set" ;;
  esac
fi

# user.name and user.email — prompt only if both are unset. We don't
# prompt if just one is missing because the user may be in an unusual
# state (e.g. one set via $GIT_AUTHOR_NAME) and we shouldn't pester them.
# Skipped entirely in non-interactive mode: the headless caller (CI,
# the GHA e2e-launcher workflow) has no human to answer the prompt.
if [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
  log_skip "git: user.name/user.email (non-interactive: skipped prompt)"
elif ! git_is_set_global user.name && ! git_is_set_global user.email; then
  echo ""
  log_info "Git needs a name and email to attach to your commits."
  log_info "(These appear in commit history and are visible on GitHub.)"
  echo ""

  git_user_name=$(ui_input "Your name (e.g. Alex Smith):")
  git_user_email=$(ui_input "Your email (matching your GitHub account):")

  if [ -n "$git_user_name" ]; then
    if git config --global user.name "$git_user_name"; then
      log_installed "git: user.name set"
    else
      log_error "Failed to set git user.name"
    fi
  fi

  if [ -n "$git_user_email" ]; then
    if git config --global user.email "$git_user_email"; then
      log_installed "git: user.email set"
    else
      log_error "Failed to set git user.email"
    fi
  fi
else
  log_skip "git: user.name/user.email already configured"
fi
