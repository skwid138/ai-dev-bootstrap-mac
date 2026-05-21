#!/usr/bin/env bats
# Tests for Remote Access add-on routing and breadcrumb resume behavior.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT

  SANDBOX="${BATS_TEST_TMPDIR}/tailscale-routing"
  export HOME="$SANDBOX/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  mkdir -p "$HOME" "$XDG_CONFIG_HOME"

  unset AI_BOOTSTRAP_TIER
  unset BOOTSTRAP_DRY_RUN BOOTSTRAP_NONINTERACTIVE AI_BOOTSTRAP_NONINTERACTIVE
  unset BOOTSTRAP_MODULE_ONLY BOOTSTRAP_LIST_MODULES
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

  cat >"$FIXTURE/modules/04-git.sh" <<'EOF'
#!/bin/bash
echo "git module ran"
EOF

  cat >"$FIXTURE/modules/14-tailscale.sh" <<'EOF'
#!/bin/bash
echo "tailscale module ran"
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

@test "--module tailscale appears in --list-modules output" {
  run "$REPO_ROOT/bootstrap.sh" --list-modules

  [ "$status" -eq 0 ]
  [[ "$output" == *"tailscale"* ]]
}

@test "--module tailscale executes without state.sh because it is an add-on" {
  make_fixture

  run "$FIXTURE/bootstrap.sh" --module tailscale

  [ "$status" -eq 0 ]
  [[ "$output" == *"tailscale module ran"* ]]
  [[ "$output" != *"No state.sh found"* ]]
  [[ "$output" != *"preflight ran"* ]]
}

@test "summary detects pending tailscale breadcrumb and clears it when declined" {
  make_fixture
  MOCK_LOG="$SANDBOX/gum.log"
  export MOCK_LOG
  MOCKS_DIR="$SANDBOX/mocks"
  mkdir -p "$MOCKS_DIR"
  cat >"$MOCKS_DIR/gum" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  confirm)
    printf "confirm:%s\n" "$2" >>"$MOCK_LOG"
    exit 1
    ;;
  style)
    shift
    printf "%s\n" "${@: -1}"
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$MOCKS_DIR/gum"
  export PATH="$MOCKS_DIR:$PATH"

  source "$FIXTURE/lib/breadcrumb.sh"
  breadcrumb_write tailscale

  run "$FIXTURE/bootstrap.sh" --non-interactive

  [ "$status" -eq 0 ]
  grep -q "confirm:Continue setting up tailscale now?" "$MOCK_LOG"
  [ ! -f "$HOME/.config/ai-bootstrap/breadcrumbs/tailscale" ]
  [[ "$output" == *"Installation Summary"* ]]
}

@test "summary continues pending tailscale setup when accepted" {
  make_fixture
  MOCK_LOG="$SANDBOX/gum-accept.log"
  export MOCK_LOG
  MOCKS_DIR="$SANDBOX/mocks-accept"
  mkdir -p "$MOCKS_DIR"
  cat >"$MOCKS_DIR/gum" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  confirm)
    printf "confirm:%s\n" "$2" >>"$MOCK_LOG"
    exit 0
    ;;
  style)
    shift
    printf "%s\n" "${@: -1}"
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$MOCKS_DIR/gum"
  export PATH="$MOCKS_DIR:$PATH"

  source "$FIXTURE/lib/breadcrumb.sh"
  breadcrumb_write tailscale

  run "$FIXTURE/bootstrap.sh" --non-interactive

  [ "$status" -eq 0 ]
  grep -q "confirm:Continue setting up tailscale now?" "$MOCK_LOG"
  [[ "$output" == *"tailscale module ran"* ]]
  [ ! -f "$HOME/.config/ai-bootstrap/breadcrumbs/tailscale" ]
}

@test "summary keeps pending tailscale breadcrumb when accepted setup fails" {
  make_fixture
  cat >"$FIXTURE/modules/14-tailscale.sh" <<'EOF'
#!/bin/bash
echo "tailscale module failed"
exit 42
EOF
  MOCK_LOG="$SANDBOX/gum-fail.log"
  export MOCK_LOG
  MOCKS_DIR="$SANDBOX/mocks-fail"
  mkdir -p "$MOCKS_DIR"
  cat >"$MOCKS_DIR/gum" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  confirm)
    printf "confirm:%s\n" "$2" >>"$MOCK_LOG"
    exit 0
    ;;
  style)
    shift
    printf "%s\n" "${@: -1}"
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$MOCKS_DIR/gum"
  export PATH="$MOCKS_DIR:$PATH"

  source "$FIXTURE/lib/breadcrumb.sh"
  breadcrumb_write tailscale

  run "$FIXTURE/bootstrap.sh" --non-interactive

  [ "$status" -eq 42 ]
  grep -q "confirm:Continue setting up tailscale now?" "$MOCK_LOG"
  [[ "$output" == *"tailscale module failed"* ]]
  [ -f "$HOME/.config/ai-bootstrap/breadcrumbs/tailscale" ]
}

@test "help text documents tailscale as an add-on module example" {
  run "$REPO_ROOT/bootstrap.sh" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"tailscale"* ]]
  [[ "$output" == *"add-on"* ]]
}
