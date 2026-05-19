#!/usr/bin/env bats
# Tests for bootstrap.sh module failure isolation.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR

  SANDBOX="${BATS_TEST_TMPDIR}/bootstrap-module-isolation"
  FIXTURE="$SANDBOX/repo"
  mkdir -p "$FIXTURE"
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"
}

@test "bootstrap: selected module failure is recorded and later modules still run" {
  cp "$BOOTSTRAP_DIR/bootstrap.sh" "$FIXTURE/bootstrap.sh"
  chmod +x "$FIXTURE/bootstrap.sh"
  cp -R "$BOOTSTRAP_DIR/lib" "$FIXTURE/lib"
  mkdir -p "$FIXTURE/config" "$FIXTURE/modules"

  cat >"$FIXTURE/lib/checks.sh" <<'EOF'
#!/bin/bash
run_preflight() { :; }
EOF

  cat >"$FIXTURE/config/packages.sh" <<'EOF'
#!/bin/bash
PACKAGES=()
PKG_NAMES=()
PKG_TYPES=()
PKG_IDS=()
PKG_TIERS=()
PKG_DESCS=()
register_package() {
  PACKAGES+=("$1")
  PKG_NAMES+=("$2")
  PKG_TYPES+=("$3")
  PKG_IDS+=("$4")
  PKG_TIERS+=("$5")
  PKG_DESCS+=("$6")
}
register_package "git" "Git" "formula" "git" "essential" "Version control"
EOF

  cat >"$FIXTURE/config/tiers.sh" <<'EOF'
#!/bin/bash
get_tier_packages() { [ "$1" = "essential" ] && echo "git"; }
get_tier_description() { echo "test tier"; }
EOF

  for module in 00-xcode-clt.sh 01-homebrew.sh 02-gum.sh; do
    cat >"$FIXTURE/modules/$module" <<'EOF'
#!/bin/bash
return 0
EOF
  done

  cat >"$FIXTURE/modules/04-git.sh" <<'EOF'
#!/bin/bash
echo "git module failing"
return 7
EOF

  cat >"$FIXTURE/modules/10-shell-config.sh" <<'EOF'
#!/bin/bash
echo "shell config ran"
EOF

  run env AI_BOOTSTRAP_TIER=essential "$FIXTURE/bootstrap.sh" --non-interactive

  [ "$status" -eq 0 ]
  [[ "$output" == *"git module failing"* ]]
  [[ "$output" == *"shell config ran"* ]]
  [[ "$output" == *"Failed (1): 04-git.sh"* ]]
}
