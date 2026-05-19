#!/usr/bin/env bats
# Integration tests for installer module flow decisions.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR

  SANDBOX="${BATS_TEST_TMPDIR}/install-flow"
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"
}

run_git_module_with_fake_code() {
  local module_name="$1"
  run bash -c '
    set -euo pipefail
    export BOOTSTRAP_DIR="$1"
    export HOME="$2"

    fakebin="$3"
    mkdir -p "$fakebin"
    cat >"$fakebin/code" <<EOF
#!/bin/sh
exit 0
EOF
    chmod +x "$fakebin/code"
    export PATH="$fakebin:/usr/bin:/bin:/usr/sbin:/sbin"

    source "$BOOTSTRAP_DIR/lib/common.sh"
    install_brew_formula() { :; }
    install_brew_cask() { :; }
    command_exists() {
      case "$1" in
        code) command -v code >/dev/null 2>&1 ;;
        *) return 1 ;;
      esac
    }
    export BOOTSTRAP_NONINTERACTIVE=1

    module_name="$4"
    run_module() {
      source "$BOOTSTRAP_DIR/modules/$module_name"
    }
    run_module

    if editor=$(git config --global --get core.editor); then
      printf "core.editor=%s\n" "$editor"
    else
      printf "core.editor=<unset>\n"
    fi
  ' bash "$BOOTSTRAP_DIR" "$HOME" "$SANDBOX/fakebin" "$module_name"
}

@test "module 04 git does not configure core.editor before VS Code install" {
  run_git_module_with_fake_code "04-git.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"core.editor=<unset>"* ]]
}

@test "module 05 editor configures git core.editor after VS Code install" {
  run_git_module_with_fake_code "05-editor.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"core.editor=code --wait"* ]]
}

run_local_ai_module() {
  local noninteractive="${1:-}"
  local selection="${2:-both}"
  export MOCK_LOG="$SANDBOX/local-ai.log"
  : >"$MOCK_LOG"

  run bash -c '
    set -euo pipefail
    export BOOTSTRAP_DIR="$1"
    export HOME="$2"
    export MOCK_LOG="$3"

    source "$BOOTSTRAP_DIR/lib/common.sh"
    case "$5" in
      ollama) SELECTED_PACKAGES=("ollama") ;;
      lm_studio) SELECTED_PACKAGES=("lm_studio") ;;
      *) SELECTED_PACKAGES=("ollama" "lm_studio") ;;
    esac
    install_brew_formula() { printf "formula:%s\n" "$1" >>"$MOCK_LOG"; }
    install_brew_cask() { printf "cask:%s\n" "$1" >>"$MOCK_LOG"; }
    ui_choose() {
      if [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
        printf "ui_choose called in non-interactive mode\n" >&2
        return 99
      fi

      printf "choose:%s|%s\n" "$1" "$2" >>"$MOCK_LOG"
      printf "LM Studio\n"
    }

    if [ "$4" = "noninteractive" ]; then
      export BOOTSTRAP_NONINTERACTIVE=1
      export AI_BOOTSTRAP_NONINTERACTIVE=1
    fi

    run_module() {
      source "$BOOTSTRAP_DIR/modules/11-local-ai.sh"
    }
    run_module
  ' bash "$BOOTSTRAP_DIR" "$HOME" "$MOCK_LOG" "$noninteractive" "$selection"
}

@test "module 11 local AI non-interactive installs LM Studio only without prompting" {
  run_local_ai_module "noninteractive"

  [ "$status" -eq 0 ]
  grep -q "cask:lm-studio" "$MOCK_LOG"
  run ! grep -q "formula:ollama" "$MOCK_LOG"
}

@test "module 11 local AI non-interactive installs Ollama when only Ollama is selected" {
  run_local_ai_module "noninteractive" "ollama"

  [ "$status" -eq 0 ]
  grep -q "formula:ollama" "$MOCK_LOG"
  run ! grep -q "cask:lm-studio" "$MOCK_LOG"
}

@test "module 11 local AI non-interactive installs LM Studio when only LM Studio is selected" {
  run_local_ai_module "noninteractive" "lm_studio"

  [ "$status" -eq 0 ]
  grep -q "cask:lm-studio" "$MOCK_LOG"
  run ! grep -q "formula:ollama" "$MOCK_LOG"
}

@test "module 11 local AI interactive prompt explains options and defaults to LM Studio" {
  run_local_ai_module "interactive"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Local AI tools let you run models privately on your Mac."* ]]
  [[ "$output" == *"LM Studio"*"visual app"* ]]
  [[ "$output" == *"Ollama"*"command-line"* ]]
  grep -q "choose:LM Studio|Ollama" "$MOCK_LOG"
  grep -q "cask:lm-studio" "$MOCK_LOG"
}

run_extras_module_with_playwright() {
  export MOCK_LOG="$SANDBOX/extras.log"
  : >"$MOCK_LOG"

  run bash -c '
    set -euo pipefail
    export BOOTSTRAP_DIR="$1"
    export HOME="$2"
    export MOCK_LOG="$3"

    source "$BOOTSTRAP_DIR/lib/common.sh"
    SELECTED_PACKAGES=("playwright")
    command_exists() { [ "$1" = "node" ]; }
    ui_spin() { shift; printf "spin:%s\n" "$*" >>"$MOCK_LOG"; }
    install_brew_formula() { printf "formula:%s\n" "$1" >>"$MOCK_LOG"; }

    run_module() {
      source "$BOOTSTRAP_DIR/modules/13-extras.sh"
    }
    run_module
  ' bash "$BOOTSTRAP_DIR" "$HOME" "$MOCK_LOG"
}

@test "module 13 extras tells Playwright users to install browser binaries" {
  run_extras_module_with_playwright

  [ "$status" -eq 0 ]
  grep -q "spin:npm install -g playwright" "$MOCK_LOG"
  [[ "$output" == *"Playwright needs one more step before it can control browsers"* ]]
  [[ "$output" == *"npx playwright install"* ]]
}
