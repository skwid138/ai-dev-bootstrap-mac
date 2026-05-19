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
