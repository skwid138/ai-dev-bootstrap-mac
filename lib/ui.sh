#!/bin/bash
# Gum UI abstraction layer with plain fallbacks.

# Detect whether gum is available.
HAS_GUM=false
if command -v gum >/dev/null 2>&1; then
  HAS_GUM=true
fi

# Choose a single option.
ui_choose() {
  if $HAS_GUM; then
    gum choose "$@"
  else
    select opt in "$@"; do
      echo "$opt"
      break
    done
  fi
}

# Choose multiple options.
ui_choose_multi() {
  if $HAS_GUM; then
    gum choose --no-limit "$@"
  else
    local options=("$@")
    local selections=()
    local input
    local idx

    echo "Select one or more options (comma-separated numbers):"
    for idx in "${!options[@]}"; do
      printf "%2d) %s\n" $((idx + 1)) "${options[$idx]}"
    done
    read -r input

    IFS=',' read -r -a picks <<< "$input"
    for idx in "${picks[@]}"; do
      idx=$(echo "$idx" | tr -d ' ')
      if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le "${#options[@]}" ]; then
        selections+=("${options[$((idx - 1))]}")
      fi
    done

    printf "%s\n" "${selections[@]}"
  fi
}

# Confirm an action.
ui_confirm() {
  local prompt="$1"
  if $HAS_GUM; then
    gum confirm "$prompt"
  else
    read -r -p "$prompt (y/n) " -n 1 reply
    echo
    [[ "$reply" =~ ^[Yy]$ ]]
  fi
}

# Run a command with a spinner.
ui_spin() {
  local title="$1"
  shift
  if $HAS_GUM; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    echo "$title"
    "$@"
  fi
}

# Prompt for input.
ui_input() {
  local prompt="$1"
  if $HAS_GUM; then
    gum input --prompt "$prompt "
  else
    read -r -p "$prompt " value
    echo "$value"
  fi
}

# Prompt for secret input.
ui_input_secret() {
  local prompt="$1"
  if $HAS_GUM; then
    gum input --password --prompt "$prompt "
  else
    read -r -s -p "$prompt " value
    echo
    echo "$value"
  fi
}

# Print a banner header.
ui_header() {
  local text="$1"
  if $HAS_GUM; then
    gum style --border normal --margin "1" --padding "1" --bold "$text"
  else
    echo "========================================"
    echo "$text"
    echo "========================================"
  fi
}

# Styled messages.
ui_success() {
  local text="$1"
  if $HAS_GUM; then
    gum style --foreground 2 "✓ $text"
  else
    echo "✓ $text"
  fi
}

ui_error() {
  local text="$1"
  if $HAS_GUM; then
    gum style --foreground 1 "✗ $text"
  else
    echo "✗ $text"
  fi
}

ui_warn() {
  local text="$1"
  if $HAS_GUM; then
    gum style --foreground 3 "! $text"
  else
    echo "! $text"
  fi
}
