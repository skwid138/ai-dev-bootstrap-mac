#!/bin/bash
# OpenCode install + multi-provider API key configuration.
# This module is sourced by bootstrap.sh (not executed standalone).

# ── Install OpenCode ──────────────────────────────────────────────────
log_info "Setting up OpenCode..."

# Add the tap if not already present.
if ! brew tap | grep -q "anomalyco/tap"; then
  ui_spin "Adding OpenCode tap..." brew tap anomalyco/tap
fi

install_brew_formula "anomalyco/tap/opencode"

# ── Provider configuration ────────────────────────────────────────────
echo ""
ui_header "🔑 Configure AI Providers for OpenCode"
echo ""
log_info "OpenCode uses AI models to help you write code."
log_info "You need at least one provider. You can add more later."
echo ""

OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
ensure_dir "$OPENCODE_CONFIG_DIR"

configure_providers=true
while $configure_providers; do
  echo ""
  PROVIDER=$(ui_choose \
    "GitHub Copilot (free tier available — recommended for beginners)" \
    "Anthropic Claude (best coding model — paid)" \
    "OpenAI GPT (paid)" \
    "Done — skip or finish adding providers")

  case "$PROVIDER" in
    *Copilot*)
      echo ""
      log_info "GitHub Copilot uses your GitHub account."
      log_info "A free tier is available for individual use."
      echo ""

      if command_exists gh; then
        if ! gh auth status >/dev/null 2>&1; then
          log_info "You need to log in to GitHub first."
          log_info "A browser window will open for authentication."
          echo ""
          if ui_confirm "Log in to GitHub now?"; then
            gh auth login
          fi
        else
          log_skip "Already authenticated with GitHub"
        fi
      else
        log_warn "GitHub CLI (gh) is not installed. Install it first to use Copilot."
      fi

      log_installed "GitHub Copilot configured (uses gh auth)"
      ;;

    *Anthropic*)
      echo ""
      log_info "Anthropic Claude is excellent for coding tasks."
      echo ""
      log_info "To get an API key:"
      log_info "  1. Go to https://console.anthropic.com/"
      log_info "  2. Sign up or log in"
      log_info "  3. Go to Settings → API Keys"
      log_info "  4. Click 'Create Key' and copy it"
      echo ""

      if ui_confirm "Do you have an Anthropic API key ready?"; then
        ANTHROPIC_KEY=$(ui_input_secret "Enter your Anthropic API key:")
        if [ -n "$ANTHROPIC_KEY" ]; then
          append_line_if_missing "export ANTHROPIC_API_KEY=\"${ANTHROPIC_KEY}\"" \
            "$HOME/.config/ai-bootstrap/shell/vars.sh"
          log_installed "Anthropic API key saved"
        fi
      else
        log_info "No problem — you can add it later by editing:"
        log_info "  ~/.config/ai-bootstrap/shell/vars.sh"
      fi
      ;;

    *OpenAI*)
      echo ""
      log_info "OpenAI GPT models are widely used for coding."
      echo ""
      log_info "To get an API key:"
      log_info "  1. Go to https://platform.openai.com/"
      log_info "  2. Sign up or log in"
      log_info "  3. Go to API Keys in the sidebar"
      log_info "  4. Click 'Create new secret key' and copy it"
      echo ""

      if ui_confirm "Do you have an OpenAI API key ready?"; then
        OPENAI_KEY=$(ui_input_secret "Enter your OpenAI API key:")
        if [ -n "$OPENAI_KEY" ]; then
          append_line_if_missing "export OPENAI_API_KEY=\"${OPENAI_KEY}\"" \
            "$HOME/.config/ai-bootstrap/shell/vars.sh"
          log_installed "OpenAI API key saved"
        fi
      else
        log_info "No problem — you can add it later by editing:"
        log_info "  ~/.config/ai-bootstrap/shell/vars.sh"
      fi
      ;;

    *Done*)
      configure_providers=false
      ;;
  esac
done

# ── Write basic OpenCode config if none exists ────────────────────────
if [ ! -f "$OPENCODE_CONFIG_DIR/opencode.json" ]; then
  cat >"$OPENCODE_CONFIG_DIR/opencode.json" <<'OCEOF'
{
  "$schema": "https://opencode.ai/config.json"
}
OCEOF
  log_installed "Created ~/.config/opencode/opencode.json"
else
  log_skip "opencode.json already exists"
fi
