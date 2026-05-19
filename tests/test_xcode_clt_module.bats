#!/usr/bin/env bats
# Tests for modules/00-xcode-clt.sh.

bats_require_minimum_version 1.5.0

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env

  SANDBOX="${BATS_TEST_TMPDIR}/xcode-clt"
  mkdir -p "$SANDBOX/bin"
}

teardown() {
  teardown_test_env
}

@test "xcode-clt module: times out instead of waiting forever" {
  cat >"$SANDBOX/bin/xcode-select" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "-p" ]; then
  exit 1
fi
if [ "$1" = "--install" ]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$SANDBOX/bin/xcode-select"

  run env \
    "PATH=$SANDBOX/bin:/usr/bin:/bin" \
    "BOOTSTRAP_DIR=$BOOTSTRAP_DIR" \
    "XCODE_CLT_TIMEOUT_SECONDS=0" \
    perl -MPOSIX=:sys_wait_h -e '$pid=fork(); if ($pid == 0) { setpgrp(0, 0); exec @ARGV; } sleep 1; kill "TERM", -$pid; waitpid($pid, 0); if (WIFSIGNALED($?)) { exit 128 + WTERMSIG($?); } exit WEXITSTATUS($?);' \
    bash -c 'source "$BOOTSTRAP_DIR/lib/ui.sh"; source "$BOOTSTRAP_DIR/lib/common.sh"; source "$BOOTSTRAP_DIR/modules/00-xcode-clt.sh"'

  [ "$status" -eq 1 ]
  [[ "$output" == *"Look for the install popup"* ]]
  [[ "$output" == *"Xcode Command Line Tools did not finish within 15 minutes"* ]]
}
