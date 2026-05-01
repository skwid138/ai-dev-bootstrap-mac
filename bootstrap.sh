#!/bin/bash
set -euo pipefail

# ── Locate project root ──────────────────────────────────────────────
BOOTSTRAP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export BOOTSTRAP_DIR

# ── Source libraries ──────────────────────────────────────────────────
source "${BOOTSTRAP_DIR}/lib/ui.sh"
source "${BOOTSTRAP_DIR}/lib/checks.sh"
source "${BOOTSTRAP_DIR}/config/packages.sh"
source "${BOOTSTRAP_DIR}/config/tiers.sh"
source "${BOOTSTRAP_DIR}/lib/common.sh"
source "${BOOTSTRAP_DIR}/lib/workspace.sh"
source "${BOOTSTRAP_DIR}/lib/state.sh"
source "${BOOTSTRAP_DIR}/lib/brewfile.sh"
source "${BOOTSTRAP_DIR}/lib/args.sh"
source "${BOOTSTRAP_DIR}/lib/plan.sh"
source "${BOOTSTRAP_DIR}/lib/launcher.sh"

# ── Parse flags ───────────────────────────────────────────────────────
# args_parse exports BOOTSTRAP_DRY_RUN, BOOTSTRAP_NONINTERACTIVE, and
# BOOTSTRAP_LAUNCHER_ONLY. Returns 1 for --help, 2 for unknown flag.
if ! args_parse "$@"; then
  rc=$?
  args_print_help
  if [ "$rc" = "1" ]; then
    exit 0
  fi
  exit 2
fi

# ── Launcher-only fast path ───────────────────────────────────────────
# Skip preflight, Phase 0, tier selection, workspace prompt, and all
# modules. Just rebuild ~/Applications/Vibe Code.app and exit. Useful
# when:
#   * The user accidentally deleted their launcher and wants it back.
#   * A dev is iterating on launcher/launch.sh and wants a fast rebuild
#     without re-running everything.
#   * Manually testing the .app bundle in isolation.
#
# Workspace resolution: read from existing state.sh if present (so the
# rebuilt launcher points at the same workspace as the user's previous
# bootstrap), else fall back to ~/code. The launcher script itself
# re-reads state.sh at click-time, so this is mostly belt-and-suspenders.
if [ -n "${BOOTSTRAP_LAUNCHER_ONLY:-}" ]; then
  build_script="${BOOTSTRAP_DIR}/launcher/build.sh"
  dest_dir=$(launcher_resolve_dest)
  app_path="$dest_dir/Vibe Code.app"

  if [ -n "${BOOTSTRAP_DRY_RUN:-}" ]; then
    echo ""
    echo "========================================"
    echo "  📋 Dry-run plan (launcher only)"
    echo "========================================"
    echo ""
    echo "  Would (re)build: $app_path"
    echo "  From:            $build_script"
    echo ""
    echo "  Nothing has been changed yet. Run without --dry-run to rebuild."
    echo ""
    exit 0
  fi

  log_info "Launcher-only mode: rebuilding $app_path"
  if launcher_install "$build_script" "$dest_dir" >/dev/null; then
    log_installed "Vibe Code.app rebuilt at $app_path"
    # Friendly heads-up if we landed in ~/Applications instead of the
    # standard /Applications. This only happens on locked-down Macs;
    # the message tells the user where to find it without requiring
    # them to know about ~/Applications as a separate folder.
    if [ "$dest_dir" = "$HOME/Applications" ]; then
      log_info "Note: /Applications is read-only on this Mac, so we"
      log_info "installed to ~/Applications instead. Spotlight, LaunchPad,"
      log_info "and Finder will all find it there."
    fi
    log_info "Open it from Spotlight, LaunchPad, or Finder."
    exit 0
  else
    log_error "Launcher rebuild failed"
    exit 1
  fi
fi

# ── Pre-flight ────────────────────────────────────────────────────────
# Skipped in dry-run: pre-flight does environment checks (macOS version,
# disk space) that are fine to run, but it also writes nothing — keeping
# everything before the plan-render side-effect-free is simpler than
# auditing each pre-flight check.
if [ -z "${BOOTSTRAP_DRY_RUN:-}" ]; then
  run_preflight
fi

# ── Phase 0: Bootstrap prerequisites (plain UI — no Gum yet) ─────────
# Skipped in dry-run. These modules install xcode-clt, brew, and gum,
# which are real side effects.
if [ -z "${BOOTSTRAP_DRY_RUN:-}" ]; then
  echo ""
  echo "========================================"
  echo "  AI Dev Bootstrap for Mac"
  echo "  Setting up prerequisites..."
  echo "========================================"
  echo ""

  # Xcode CLT
  if [ -f "${BOOTSTRAP_DIR}/modules/00-xcode-clt.sh" ]; then
    source "${BOOTSTRAP_DIR}/modules/00-xcode-clt.sh"
  fi

  # Homebrew
  if [ -f "${BOOTSTRAP_DIR}/modules/01-homebrew.sh" ]; then
    source "${BOOTSTRAP_DIR}/modules/01-homebrew.sh"
  fi

  # Gum
  if [ -f "${BOOTSTRAP_DIR}/modules/02-gum.sh" ]; then
    source "${BOOTSTRAP_DIR}/modules/02-gum.sh"
  fi

  # Re-detect Gum now that it should be installed.
  if command -v gum >/dev/null 2>&1; then
    HAS_GUM=true
  fi
fi

# ── Welcome ───────────────────────────────────────────────────────────
ui_header "🚀 AI Dev Bootstrap for Mac"
echo ""
log_info "This tool sets up your Mac for building apps and automations"
log_info "with AI-powered coding tools like OpenCode."
echo ""

# ── Tier selection ────────────────────────────────────────────────────
if [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
  # Non-interactive mode: default to recommended. Loud log so the user
  # is never surprised about what got installed in CI / unattended runs.
  SELECTED_TIER="recommended"
  log_info "Non-interactive: using default tier '$SELECTED_TIER'"
else
  log_info "Choose an install tier:"
  echo ""

  TIER=$(ui_choose \
    "🟢 Essential — $(get_tier_description essential)" \
    "🔵 Recommended — $(get_tier_description recommended)" \
    "🟣 Complete — $(get_tier_description complete)" \
    "🔧 Custom — Pick exactly what you want")

  # Extract tier key from selection.
  case "$TIER" in
    *Essential*) SELECTED_TIER="essential" ;;
    *Recommended*) SELECTED_TIER="recommended" ;;
    *Complete*) SELECTED_TIER="complete" ;;
    *Custom*) SELECTED_TIER="custom" ;;
    *) SELECTED_TIER="essential" ;;
  esac
fi

# ── Build selected package list ───────────────────────────────────────
SELECTED_PACKAGES=()

if [ "$SELECTED_TIER" = "custom" ]; then
  # Build display labels for all packages.
  LABELS=()
  for i in "${!PACKAGES[@]}"; do
    LABELS+=("${PKG_NAMES[$i]} — ${PKG_DESCS[$i]}")
  done

  CHOSEN=$(ui_choose_multi "${LABELS[@]}")

  # Map chosen labels back to package keys.
  while IFS= read -r label; do
    [ -z "$label" ] && continue
    for i in "${!PACKAGES[@]}"; do
      if [[ "$label" == "${PKG_NAMES[$i]}"* ]]; then
        SELECTED_PACKAGES+=("${PACKAGES[$i]}")
        break
      fi
    done
  done <<<"$CHOSEN"
else
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    SELECTED_PACKAGES+=("$pkg")
  done <<<"$(get_tier_packages "$SELECTED_TIER")"
fi

# ── Workspace anchor ─────────────────────────────────────────────────
# Where the user keeps their code projects. Asked once, persisted to
# ~/.config/ai-bootstrap/state.sh, referenced by aliases (cdc), the
# .app launcher (Phase E), and any future module that needs it.
WORKSPACE_DEFAULT=$(workspace_default_path)
WORKSPACE_PATH=""

if [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
  # Non-interactive: skip the prompt entirely, default to ~/code with a
  # loud log so the user knows what was assumed.
  WORKSPACE_PATH="$WORKSPACE_DEFAULT"
  log_info "Non-interactive: using default workspace '$WORKSPACE_PATH'"
else
  echo ""
  ui_header "📁 Workspace"
  echo ""
  log_info "Pick a directory to keep your code projects in. We'll create it"
  log_info "if it doesn't exist, and the 'cdc' shortcut will jump there."
  echo ""

  while [ -z "$WORKSPACE_PATH" ]; do
    user_input=$(ui_input "Workspace directory [$WORKSPACE_DEFAULT]:")

    if [ -z "$user_input" ]; then
      candidate="$WORKSPACE_DEFAULT"
    else
      candidate=$(workspace_expand_path "$user_input")
    fi

    if workspace_validate_path "$candidate"; then
      WORKSPACE_PATH="$candidate"
    else
      log_warn "Try again, or just press Enter to use $WORKSPACE_DEFAULT."
    fi
  done
fi

# ── Dry-run plan & exit ──────────────────────────────────────────────
# In dry-run mode, we have everything we need to show the plan: tier,
# workspace, and (for custom tier) the package list. Render and exit.
# Nothing has been written to disk yet — the workspace dir hasn't been
# created, state.sh hasn't been touched, no installs have run.
if [ -n "${BOOTSTRAP_DRY_RUN:-}" ]; then
  # For non-custom tiers, plan_render computes packages from tier.
  # For custom tiers in non-interactive mode there's no way to specify
  # packages on the command line yet, so the tier defaults to
  # 'recommended' and custom isn't reachable. Pass empty CSV.
  plan_render "$SELECTED_TIER" "$WORKSPACE_PATH" ""
  exit 0
fi

if workspace_ensure_dir "$WORKSPACE_PATH"; then
  log_installed "Workspace: $WORKSPACE_PATH"
else
  log_error "Failed to create workspace directory: $WORKSPACE_PATH"
fi

if workspace_write_state "$HOME/.config/ai-bootstrap/state.sh" "$WORKSPACE_PATH"; then
  log_installed "Workspace path saved to ~/.config/ai-bootstrap/state.sh"
else
  log_error "Failed to write workspace state file"
fi

export AI_BOOTSTRAP_WORKSPACE="$WORKSPACE_PATH"

# ── Run modules for selected packages ────────────────────────────────
# Map package keys to module scripts.
run_module_if_selected() {
  local module_file="$1"
  shift
  local required_packages=("$@")

  local dominated=false
  for pkg in "${required_packages[@]}"; do
    for sel in "${SELECTED_PACKAGES[@]}"; do
      if [ "$sel" = "$pkg" ]; then
        dominated=true
        break 2
      fi
    done
  done

  if $dominated && [ -f "${BOOTSTRAP_DIR}/modules/${module_file}" ]; then
    source "${BOOTSTRAP_DIR}/modules/${module_file}"
  fi
}

# Modules 00-02 already ran above. Run the rest in order.
run_module_if_selected "03-terminal.sh" "ghostty"
run_module_if_selected "04-git.sh" "git" "gh"
run_module_if_selected "05-editor.sh" "vscode"
run_module_if_selected "06-runtime.sh" "mise" "node_lts"
run_module_if_selected "07-python.sh" "uv" "python"
run_module_if_selected "08-cli-tools.sh" "ripgrep" "jq" "fd" "direnv" "tmux" "btop"
run_module_if_selected "09-opencode.sh" "opencode"
run_module_if_selected "10-shell-config.sh" "zplug" "spaceship" "zsh_syntax" "zsh_autosuggestions"
run_module_if_selected "11-local-ai.sh" "ollama" "lm_studio"
run_module_if_selected "12-containers.sh" "orbstack"
run_module_if_selected "13-extras.sh" "playwright" "shfmt" "ffmpeg" "imagemagick"

# ── Summary ───────────────────────────────────────────────────────────
echo ""
ui_header "📋 Installation Summary"
echo ""

if [ ${#RESULTS_INSTALLED[@]} -gt 0 ]; then
  log_installed "Installed (${#RESULTS_INSTALLED[@]}): ${RESULTS_INSTALLED[*]}"
fi

if [ ${#RESULTS_SKIPPED[@]} -gt 0 ]; then
  log_skip "Already installed (${#RESULTS_SKIPPED[@]}): ${RESULTS_SKIPPED[*]}"
fi

if [ ${#RESULTS_FAILED[@]} -gt 0 ]; then
  log_error "Failed (${#RESULTS_FAILED[@]}): ${RESULTS_FAILED[*]}"
fi

# ── Brewfile snapshot ────────────────────────────────────────────────
# Dump the user's full brew state to ~/.config/ai-bootstrap/Brewfile so
# they can replay this setup on a new Mac with `brew bundle`. Includes
# everything they have brewed, not just what bootstrap installed — the
# point is reproducibility of the user's machine, not auditing what we
# touched.
brewfile_path="$HOME/.config/ai-bootstrap/Brewfile"
if brewfile_dump "$brewfile_path" >/dev/null; then
  log_installed "Brewfile saved to $brewfile_path"
else
  # Non-fatal — the bootstrap still succeeded; the user just doesn't get
  # a portable record this run. Most likely cause: brew not on PATH, which
  # only happens if the homebrew module was skipped/failed.
  log_warn "Could not save Brewfile (brew not available?); skipping"
fi

# ── State snapshot ───────────────────────────────────────────────────
# Re-write state.sh with the full set of run metadata (workspace, tier,
# version, first/last-run timestamps). The early workspace_write_state
# call earlier in this script already wrote the workspace anchor; this
# call layers tier/version/timestamps on top and preserves first-run-at
# across re-runs.
state_path="$HOME/.config/ai-bootstrap/state.sh"
if state_write "$state_path" "$WORKSPACE_PATH" "$SELECTED_TIER"; then
  log_installed "State saved to $state_path"
else
  log_warn "Could not update state file at $state_path"
fi

echo ""
log_info "Next steps:"
log_info "  1. Open a new terminal window (or run: source ~/.zshrc)"
log_info "  2. Try running: opencode"
log_info "  3. Start building something! 🎉"
echo ""
