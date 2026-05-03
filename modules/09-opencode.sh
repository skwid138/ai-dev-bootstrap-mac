#!/bin/bash
# OpenCode install + curated asset deployment + provider configuration.
#
# This module is sourced by bootstrap.sh (not executed standalone). It
# orchestrates four steps; the heavy lifting lives in lib/opencode.sh
# so each step is independently testable:
#
#   1. Install opencode via brew (anomalyco/tap).
#   2. Deploy curated assets (agents, skills, commands, instructions,
#      plugins, AGENTS.md) into ~/.config/opencode.
#   3. Configure a provider:
#        - If `gh auth status` succeeds AND the user agrees, set up
#          GitHub Copilot non-interactively via
#          `opencode auth login --provider github-copilot --method oauth`.
#        - Otherwise show a 5-option menu (Anthropic / OpenAI / Gemini /
#          OpenCode Zen / Skip) with a dated pricing snapshot, then drive
#          the matching `opencode auth login --provider <X>` flow.
#        - Skip writes opencode.json without a model field, so opencode
#          falls back to its built-in default. The post-install message
#          tells the user how to fix it later.
#   4. Render ~/.config/opencode/opencode.json from the template, with
#      the chosen model id baked in.
#
# Environment hooks (used by tests/test_opencode_module.bats to mock the
# CLIs and skip the interactive ui_choose):
#   OPENCODE_BOOTSTRAP_TEST=1            — non-interactive mode
#   OPENCODE_TEST_MENU_SELECTION=<id>    — preselected menu choice when
#                                           the user would normally pick
#                                           one of: copilot/anthropic/
#                                           openai/gemini/zen/skip
#   OPENCODE_TEST_USE_COPILOT=yes|no     — preanswered "use Copilot?"
#                                           question when gh is authed

# shellcheck source=lib/opencode.sh
source "${BOOTSTRAP_DIR}/lib/opencode.sh"

# ── 1. Install opencode ──────────────────────────────────────────────────────
log_info "Setting up OpenCode..."

if ! brew tap | grep -q "anomalyco/tap"; then
  ui_spin "Adding OpenCode tap..." brew tap anomalyco/tap
fi

install_brew_formula "anomalyco/tap/opencode"

# ── 2. Deploy curated assets ─────────────────────────────────────────────────
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
ensure_dir "$OPENCODE_CONFIG_DIR"

log_info "Installing curated agents, skills, commands, and instructions..."

if opencode_deploy_assets "${BOOTSTRAP_DIR}/opencode" "$OPENCODE_CONFIG_DIR"; then
  log_installed "Curated assets deployed to $OPENCODE_CONFIG_DIR"
else
  log_error "Failed to deploy curated assets"
fi

agents_md_result=$(opencode_deploy_agents_md \
  "${BOOTSTRAP_DIR}/opencode/AGENTS.md" \
  "$OPENCODE_CONFIG_DIR/AGENTS.md")

case "$agents_md_result" in
  installed) log_installed "AGENTS.md installed" ;;
  skipped) log_skip "AGENTS.md already exists (preserving your edits)" ;;
  *) log_error "AGENTS.md deployment returned unexpected: $agents_md_result" ;;
esac

# ── 3. Provider configuration ────────────────────────────────────────────────
echo ""
ui_header "🔑 AI Provider Setup"
echo ""
log_info "OpenCode needs an AI model to function."
log_info "We'll set one up now so you can start coding right away."
echo ""

opencode_provider_id=""
opencode_model_id=""
opencode_login_invoked=false

if opencode_has_github_auth; then
  log_info "You're already signed in to GitHub. We can use your free GitHub"
  log_info "Copilot tier as the AI provider — no extra setup needed."
  echo ""

  if [ "${OPENCODE_BOOTSTRAP_TEST:-0}" = "1" ]; then
    use_copilot="${OPENCODE_TEST_USE_COPILOT:-yes}"
  elif [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
    # Headless bootstrap: never trigger interactive Copilot OAuth login.
    # Provider setup is the user's job to complete on first interactive run.
    use_copilot="no"
  else
    if ui_confirm "Use GitHub Copilot for AI?"; then
      use_copilot="yes"
    else
      use_copilot="no"
    fi
  fi

  if [ "$use_copilot" = "yes" ]; then
    decide_out=$(opencode_decide_provider_path "yes" "copilot")
    opencode_provider_id=$(echo "$decide_out" | sed -n '1p')
    opencode_model_id=$(echo "$decide_out" | sed -n '2p')
  fi
fi

# If we didn't lock in Copilot above, show the provider menu.
if [ -z "$opencode_provider_id" ]; then
  echo ""
  log_info "Pick a provider for OpenCode:"
  log_info "  (Pricing snapshot: April 2026 — providers change pricing,"
  log_info "   verify on each provider's site before subscribing.)"
  echo ""

  if [ "${OPENCODE_BOOTSTRAP_TEST:-0}" = "1" ]; then
    selection_id="${OPENCODE_TEST_MENU_SELECTION:-skip}"
  elif [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
    # Headless bootstrap: skip provider setup entirely. The user
    # configures a real provider on first interactive run.
    selection_id="skip"
  else
    menu_label=$(ui_choose \
      "Anthropic Claude — Pro/Max sub from claude.ai (~\$20/mo) or API key (~\$3-15/M tokens)" \
      "OpenAI — ChatGPT Plus/Pro from openai.com (~\$20/mo) or API key (~\$2.50-15/M tokens)" \
      "Google Gemini — API key, free tier ~250 req/day on Flash" \
      "OpenCode Zen — pay-as-you-go (~\$3-15/M tokens, requires credit card)" \
      "Skip — set this up later")

    case "$menu_label" in
      *Anthropic*) selection_id="anthropic" ;;
      *OpenAI*) selection_id="openai" ;;
      *Gemini*) selection_id="gemini" ;;
      *Zen*) selection_id="zen" ;;
      *) selection_id="skip" ;;
    esac
  fi

  decide_out=$(opencode_decide_provider_path "no" "$selection_id")
  opencode_provider_id=$(echo "$decide_out" | sed -n '1p')
  opencode_model_id=$(echo "$decide_out" | sed -n '2p')
fi

# Drive the auth login if a real provider was chosen.
if [ -n "$opencode_provider_id" ] && [ "$opencode_provider_id" != "none" ]; then
  log_info "Logging in to $opencode_provider_id (this may open your browser)..."

  if [ "$opencode_provider_id" = "github-copilot" ]; then
    if opencode auth login --provider github-copilot --method oauth; then
      log_installed "GitHub Copilot authenticated"
      opencode_login_invoked=true
    else
      log_warn "GitHub Copilot login didn't complete — you can retry by"
      log_warn "running 'opencode auth login --provider github-copilot' later."
    fi
  else
    if opencode auth login --provider "$opencode_provider_id"; then
      log_installed "$opencode_provider_id authenticated"
      opencode_login_invoked=true
    else
      log_warn "$opencode_provider_id login didn't complete — you can retry"
      log_warn "by running '/connect' inside OpenCode on first launch."
    fi
  fi
fi

# ── 4. Render opencode.json ──────────────────────────────────────────────────
if opencode_render_config \
  "${BOOTSTRAP_DIR}/opencode/opencode.json.template" \
  "$OPENCODE_CONFIG_DIR/opencode.json" \
  "$opencode_model_id"; then
  if [ -n "$opencode_model_id" ]; then
    log_installed "opencode.json rendered with model: $opencode_model_id"
  else
    log_installed "opencode.json rendered (no model set — opencode default)"
  fi
else
  log_error "Failed to render opencode.json"
fi

# ── 5. Post-install help ─────────────────────────────────────────────────────
echo ""
ui_header "✅ OpenCode is ready"
echo ""
log_info "Config:        $OPENCODE_CONFIG_DIR/opencode.json"
log_info "Global rules:  $OPENCODE_CONFIG_DIR/AGENTS.md"
log_info "Launch:        type 'opencode' in any terminal"
echo ""
if [ "$opencode_provider_id" = "none" ]; then
  log_warn "You skipped provider setup. OpenCode will launch but won't have"
  log_warn "a working model. To fix this, run 'opencode' and type /connect"
  log_warn "in the TUI, then pick a provider."
elif [ "$opencode_login_invoked" != "true" ] && [ -n "$opencode_provider_id" ]; then
  log_warn "Provider login didn't finish. Run 'opencode' and type /connect"
  log_warn "in the TUI to complete it."
else
  log_info "First time? Try '/help-me' inside OpenCode to get going."
fi
echo ""
