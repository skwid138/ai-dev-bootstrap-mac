#!/usr/bin/env bats
# Tests for bootstrap.sh --list-modules and --module fast paths.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT

  SANDBOX="${BATS_TEST_TMPDIR}/module-flag"
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"
}

make_fixture() {
  FIXTURE="$SANDBOX/repo"
  mkdir -p "$FIXTURE"

  cp "$REPO_ROOT/bootstrap.sh" "$FIXTURE/bootstrap.sh"
  chmod +x "$FIXTURE/bootstrap.sh"
  cp -R "$REPO_ROOT/lib" "$FIXTURE/lib"
  mkdir -p "$FIXTURE/config" "$FIXTURE/modules"

  cat >"$FIXTURE/lib/checks.sh" <<'EOF'
#!/bin/bash
run_preflight() { echo "preflight ran"; }
EOF

  cat >"$FIXTURE/config/packages.sh" <<'EOF'
#!/bin/bash
PACKAGES=()
PKG_NAMES=()
PKG_TYPES=()
PKG_IDS=()
PKG_TIERS=()
PKG_DESCS=()
EOF

  cat >"$FIXTURE/config/tiers.sh" <<'EOF'
#!/bin/bash
get_tier_packages() {
  case "$1" in
    essential | recommended | complete) echo "git" ;;
  esac
}
get_tier_description() { echo "test tier"; }
EOF

  cat >"$FIXTURE/modules/00-xcode-clt.sh" <<'EOF'
#!/bin/bash
echo "xcode module ran"
EOF

  cat >"$FIXTURE/modules/01-homebrew.sh" <<'EOF'
#!/bin/bash
echo "homebrew module ran"
EOF

  cat >"$FIXTURE/modules/02-gum.sh" <<'EOF'
#!/bin/bash
echo "gum module ran"
EOF

  cat >"$FIXTURE/modules/04-git.sh" <<'EOF'
#!/bin/bash
echo "git module ran"
EOF

  cat >"$FIXTURE/modules/10-shell-config.sh" <<'EOF'
#!/bin/bash
echo "shell-config module ran"
EOF
}

write_state() {
  local tier="$1"
  mkdir -p "$HOME/.config/ai-bootstrap"
  cat >"$HOME/.config/ai-bootstrap/state.sh" <<EOF
#!/bin/bash
export AI_BOOTSTRAP_WORKSPACE='$HOME/code'
export AI_BOOTSTRAP_TIER='$tier'
export AI_BOOTSTRAP_VERSION='0.0.0-test'
export AI_BOOTSTRAP_FIRST_RUN_AT='2026-05-02T00:00:00Z'
export AI_BOOTSTRAP_LAST_RUN_AT='2026-05-02T00:00:00Z'
EOF
}

@test "--list-modules outputs canonical module names and exits 0" {
  run "$REPO_ROOT/bootstrap.sh" --list-modules

  [ "$status" -eq 0 ]
  expected=$'xcode-clt\nhomebrew\ngum\nbash\nterminal\ngit\neditor\nruntime\npython\ncli-tools\nopencode\nshell-config\nlocal-ai\ncontainers\nextras'
  [ "$output" = "$expected" ]
}

@test "--module shell-config runs only the shell-config module" {
  make_fixture
  write_state "essential"

  run "$FIXTURE/bootstrap.sh" --module shell-config

  [ "$status" -eq 0 ]
  [[ "$output" == *"shell-config module ran"* ]]
  [[ "$output" != *"preflight ran"* ]]
  [[ "$output" != *"xcode module ran"* ]]
  [[ "$output" != *"homebrew module ran"* ]]
  [[ "$output" != *"gum module ran"* ]]
  [[ "$output" != *"git module ran"* ]]
  [[ "$output" != *"Installation Summary"* ]]
}

@test "--module nonexistent exits 2 with a helpful message" {
  make_fixture
  write_state "essential"

  run "$FIXTURE/bootstrap.sh" --module nonexistent

  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown module: nonexistent"* ]]
  [[ "$output" == *"--list-modules"* ]]
}

@test "--module git propagates the module exit code" {
  make_fixture
  write_state "essential"
  cat >"$FIXTURE/modules/04-git.sh" <<'EOF'
#!/bin/bash
echo "git module failing"
return 7
EOF

  run "$FIXTURE/bootstrap.sh" --module git

  [ "$status" -eq 7 ]
  [[ "$output" == *"git module failing"* ]]
  [[ "$output" != *"shell-config module ran"* ]]
  [[ "$output" != *"Installation Summary"* ]]
}

@test "--module rejects custom tier with exit 2" {
  make_fixture
  write_state "custom"

  run "$FIXTURE/bootstrap.sh" --module git

  [ "$status" -eq 2 ]
  [[ "$output" == *"--module requires a standard tier"* ]]
  [[ "$output" == *"essential, recommended, or complete"* ]]
  [[ "$output" != *"git module ran"* ]]
}
