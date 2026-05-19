#!/bin/bash
# Optional local AI tooling.
# This module is sourced by bootstrap.sh (not executed standalone).

selected_ollama=false
selected_lm_studio=false

if is_selected "ollama"; then
  selected_ollama=true
fi

if is_selected "lm_studio"; then
  selected_lm_studio=true
fi

choice=""
if [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
  # In unattended runs, avoid blocking on a preference prompt and choose the
  # friendliest default for first-time users.
  if $selected_ollama || $selected_lm_studio; then
    choice="LM Studio"
  fi
elif $selected_ollama && $selected_lm_studio; then
  ui_header "🧠 Choose a local AI tool"
  echo ""
  log_info "Local AI tools let you run models privately on your Mac."
  echo ""
  log_info "• LM Studio — visual app for downloading and chatting with models (recommended)"
  log_info "• Ollama — command-line tool for running models in the terminal"
  echo ""
  log_info "Which would you prefer?"
  choice=$(ui_choose "LM Studio" "Ollama")
elif $selected_ollama; then
  choice="Ollama"
elif $selected_lm_studio; then
  choice="LM Studio"
fi

if [ "$choice" = "Ollama" ]; then
  install_brew_formula "ollama"
  log_info "To try it: ollama run llama3"
elif [ "$choice" = "LM Studio" ]; then
  install_brew_cask "lm-studio"
  log_info "LM Studio is a GUI app. Open it from Applications to download models."
fi
