#!/bin/bash
# Configure modular shell dotfiles — three-tier (env / profile / rc) layout.
#
# This module is sourced by bootstrap.sh (not executed standalone). It runs
# UNCONDITIONALLY for every tier (per zsh_init_plan.md §5.1 / rev-3 C1):
# previously the module was gated on the zplug-tier package set, which meant
# Essential-tier users got no dotfiles at all and had no working PATH for
# Homebrew binaries. Per-tool conditionals now live INSIDE the module:
# zplug → rc/zsh_plugins.zsh, mise → profile/tool_hooks.zsh, mise|direnv →
# rc/tool_hooks.zsh.
#
# What this module ships:
#
#   ~/.config/ai-bootstrap/shell/
#   ├── init_env.zsh           (always)
#   ├── init_profile.zsh       (always — re-sources init_env.zsh to recover
#   │                           from macOS path_helper demotion, §3.6)
#   ├── init_rc.zsh            (always)
#   ├── env/{vars,paths}.zsh   (always; paths.zsh has __BREW_PREFIX__ baked)
#   ├── lib/path_helpers.zsh   (always; defines _path_prepend with promotion
#   │                           semantics)
#   ├── profile/tool_hooks.zsh (only if `mise` is selected)
#   └── rc/
#       ├── zsh_config.zsh     (always)
#       ├── zsh_plugins.zsh    (only if `zplug` is selected)
#       ├── tool_hooks.zsh     (only if `mise` OR `direnv` selected)
#       └── aliases.zsh        (always)
#
# Then it appends a two-line block (`# ai-bootstrap` comment + guarded
# source line) to each of ~/.zshenv, ~/.zprofile, ~/.zshrc — idempotent
# via append_line_if_missing's grep-check (lib/common.sh:75).
#
# __BREW_PREFIX__ substitution: paths.zsh ships in the repo as a template
# with the literal token `__BREW_PREFIX__`. The module resolves
# `brew --prefix` once at install time and substitutes the result into the
# installed copy. brew MUST be on PATH by the time this module runs (module
# index 10, after 01-homebrew at module index 1); a missing brew is a
# fatal error, not a fallback to /opt/homebrew (which would silently bake a
# possibly-wrong prefix). See plan §5.2 rev-6.
#
# Stale-file detection (§5.3): if the install dir contains old-layout files
# from a pre-three-tier install, or if any of ~/.zshenv/.zprofile/.zshrc
# already sources the legacy ~/.config/ai-bootstrap/shell/init.sh path, log
# a warning. NEVER auto-delete or auto-rewrite — silent rewrites of user
# files violate trust.

SHELL_CONFIG_DIR="$HOME/.config/ai-bootstrap/shell"
ensure_dir "$SHELL_CONFIG_DIR/env"
ensure_dir "$SHELL_CONFIG_DIR/lib"
ensure_dir "$SHELL_CONFIG_DIR/profile"
ensure_dir "$SHELL_CONFIG_DIR/rc"

# ── Stale-layout detection (§5.3) — read-only, warn-only ────────────────
detect_stale_shell_config() {
  local install_dir="$1"
  local home_dir="$2"
  local stale_file
  local found_stale_files=0
  local stale_files=()

  # 1. Old-layout files at install-dir root.
  for stale_file in init.sh vars.sh paths.sh zsh_config.sh zsh_plugins.sh aliases.sh; do
    if [ -f "${install_dir}/${stale_file}" ]; then
      stale_files+=("${stale_file}")
      found_stale_files=1
    fi
  done

  if [ "$found_stale_files" -eq 1 ]; then
    log_warn "Found stale legacy shell config files in ${install_dir}:"
    for stale_file in "${stale_files[@]}"; do
      log_warn "    - ${stale_file}"
    done
    log_warn "The new shell setup ignores these old files, so you can keep going."
    log_warn "If you want them cleaned up, ask OpenCode to clean up old ai-bootstrap shell files."
  fi

  # 2. Old single-barrel source line in user shell-init files.
  local rc
  for rc in "${home_dir}/.zshenv" "${home_dir}/.zprofile" "${home_dir}/.zshrc"; do
    if [ -f "$rc" ] && grep -Fq "ai-bootstrap/shell/init.sh" "$rc"; then
      log_warn "Found stale legacy source line in $rc:"
      log_warn "    [[ -f ~/.config/ai-bootstrap/shell/init.sh ]] && source ~/.config/ai-bootstrap/shell/init.sh"
      log_warn "The new install adds three replacement lines (one each for .zshenv/.zprofile/.zshrc)."
      log_warn "To remove the old line, edit $rc and delete that line manually."
    fi
  done
}

detect_stale_shell_config "$SHELL_CONFIG_DIR" "$HOME"

# ── Resolve brew prefix (hard-fail if missing — plan §5.2 rev-6) ────────
if ! command_exists brew; then
  log_error "Homebrew is not available yet, so shell setup cannot finish."
  log_error "Run this installer again; it will install Homebrew first and then finish shell setup."
  return 1
fi
brew_prefix="$(brew --prefix)"

# ── Always-installed barrels and tier files ─────────────────────────────
cp "${BOOTSTRAP_DIR}/dotfiles/init_env.zsh" "$SHELL_CONFIG_DIR/init_env.zsh"
cp "${BOOTSTRAP_DIR}/dotfiles/init_profile.zsh" "$SHELL_CONFIG_DIR/init_profile.zsh"
cp "${BOOTSTRAP_DIR}/dotfiles/init_rc.zsh" "$SHELL_CONFIG_DIR/init_rc.zsh"

cp "${BOOTSTRAP_DIR}/dotfiles/lib/path_helpers.zsh" "$SHELL_CONFIG_DIR/lib/path_helpers.zsh"
cp "${BOOTSTRAP_DIR}/dotfiles/env/vars.zsh" "$SHELL_CONFIG_DIR/env/vars.zsh"
cp "${BOOTSTRAP_DIR}/dotfiles/env/paths.zsh" "$SHELL_CONFIG_DIR/env/paths.zsh"

cp "${BOOTSTRAP_DIR}/dotfiles/rc/zsh_config.zsh" "$SHELL_CONFIG_DIR/rc/zsh_config.zsh"
cp "${BOOTSTRAP_DIR}/dotfiles/rc/aliases.zsh" "$SHELL_CONFIG_DIR/rc/aliases.zsh"
cp "${BOOTSTRAP_DIR}/dotfiles/rc/opencode-key.zsh" "$SHELL_CONFIG_DIR/rc/opencode-key.zsh"

# Bake brew prefix into installed paths.zsh. sed -i.bak for portability
# across BSD (macOS) and GNU sed; remove the .bak afterward.
sed -i.bak "s|__BREW_PREFIX__|${brew_prefix}|g" "$SHELL_CONFIG_DIR/env/paths.zsh"
rm -f "$SHELL_CONFIG_DIR/env/paths.zsh.bak"

# ── Conditional tier files (per §5.2 / §3.7) ────────────────────────────
if is_selected "mise"; then
  cp "${BOOTSTRAP_DIR}/dotfiles/profile/tool_hooks.zsh" "$SHELL_CONFIG_DIR/profile/tool_hooks.zsh"
fi

if is_selected "mise" || is_selected "direnv"; then
  cp "${BOOTSTRAP_DIR}/dotfiles/rc/tool_hooks.zsh" "$SHELL_CONFIG_DIR/rc/tool_hooks.zsh"
fi

if is_selected "zplug"; then
  install_brew_formula "zplug"
  cp "${BOOTSTRAP_DIR}/dotfiles/rc/zsh_plugins.zsh" "$SHELL_CONFIG_DIR/rc/zsh_plugins.zsh"
fi

# ── Wire into ~/.zshenv, ~/.zprofile, ~/.zshrc ──────────────────────────
# Two-line block per file: comment header + guarded source line.
# Idempotent via append_line_if_missing's grep-check.
append_line_if_missing "# ai-bootstrap" "$HOME/.zshenv"
append_line_if_missing \
  '[[ -f ~/.config/ai-bootstrap/shell/init_env.zsh ]] && source ~/.config/ai-bootstrap/shell/init_env.zsh' \
  "$HOME/.zshenv"

append_line_if_missing "# ai-bootstrap" "$HOME/.zprofile"
append_line_if_missing \
  '[[ -f ~/.config/ai-bootstrap/shell/init_profile.zsh ]] && source ~/.config/ai-bootstrap/shell/init_profile.zsh' \
  "$HOME/.zprofile"

append_line_if_missing "# ai-bootstrap" "$HOME/.zshrc"
append_line_if_missing \
  '[[ -f ~/.config/ai-bootstrap/shell/init_rc.zsh ]] && source ~/.config/ai-bootstrap/shell/init_rc.zsh' \
  "$HOME/.zshrc"
