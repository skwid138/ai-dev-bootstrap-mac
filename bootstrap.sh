#!/bin/bash
set -euo pipefail

# ── Locate project root ──────────────────────────────────────────────
BOOTSTRAP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export BOOTSTRAP_DIR

# ── Help ──────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
AI Dev Bootstrap for Mac

Usage:
  ./bootstrap.sh          Run the interactive installer
  ./bootstrap.sh --help   Show this help message

Sets up a Mac for vibe-coding with OpenCode. Safe to run multiple times.
https://github.com/skwid138/ai-dev-bootstrap-mac
EOF
  exit 0
fi

# ── Source libraries ──────────────────────────────────────────────────
source "${BOOTSTRAP_DIR}/lib/ui.sh"
source "${BOOTSTRAP_DIR}/lib/checks.sh"
source "${BOOTSTRAP_DIR}/config/packages.sh"
source "${BOOTSTRAP_DIR}/config/tiers.sh"
source "${BOOTSTRAP_DIR}/lib/common.sh"

# ── Pre-flight ────────────────────────────────────────────────────────
run_preflight

# ── Phase 0: Bootstrap prerequisites (plain UI — no Gum yet) ─────────
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

# ── Welcome ───────────────────────────────────────────────────────────
ui_header "🚀 AI Dev Bootstrap for Mac"
echo ""
log_info "This tool sets up your Mac for building apps and automations"
log_info "with AI-powered coding tools like OpenCode."
echo ""

# ── Tier selection ────────────────────────────────────────────────────
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

echo ""
log_info "Next steps:"
log_info "  1. Open a new terminal window (or run: source ~/.zshrc)"
log_info "  2. Try running: opencode"
log_info "  3. Start building something! 🎉"
echo ""
