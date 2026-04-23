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
if $selected_ollama && $selected_lm_studio; then
  ui_header "🧠 Choose a local AI tool"
  echo ""
  log_info "Ollama and LM Studio are alternatives. Choose one to install."
  echo ""
  choice=$(ui_choose "Ollama" "LM Studio")
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
