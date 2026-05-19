#!/usr/bin/env bats
# Tests for modules/01-homebrew.sh.

bats_require_minimum_version 1.5.0

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env

  SANDBOX="${BATS_TEST_TMPDIR}/homebrew"
  mkdir -p "$SANDBOX/bin"
  MOCK_LOG="$SANDBOX/mock.log"
  : >"$MOCK_LOG"
  export MOCK_LOG
}

teardown() {
  teardown_test_env
}

@test "homebrew module: curl download failure aborts install" {
  cat >"$SANDBOX/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >>"$MOCK_LOG"
exit 22
EOF
  chmod +x "$SANDBOX/bin/curl"

  run env \
    "PATH=$SANDBOX/bin:/usr/bin:/bin" \
    "BOOTSTRAP_DIR=$BOOTSTRAP_DIR" \
    bash -c 'source "$BOOTSTRAP_DIR/lib/ui.sh"; source "$BOOTSTRAP_DIR/lib/common.sh"; source "$BOOTSTRAP_DIR/modules/01-homebrew.sh"'

  [ "$status" -eq 1 ]
  [[ "$output" == *"Failed to download Homebrew installer"* ]]
  run grep -F "curl -fsSL" "$MOCK_LOG"
  [ "$status" -eq 0 ]
}
