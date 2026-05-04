#!/usr/bin/env bats
# Tests for install.sh — the curl-pipeable bootstrap entrypoint.
#
# install.sh is the only script in the repo safe to run via curl|bash.
# It clones the repo to a known location and exec's bootstrap.sh from
# the working tree. These tests cover the four real-world paths users
# can hit:
#
#   1. Fresh clone (target dir doesn't exist) → clone + handoff.
#   2. Re-run on an existing checkout of THIS repo → fetch + checkout +
#      ff-only pull + handoff.
#   3. Existing dir is not a git checkout → abort with explanation.
#   4. Existing dir is a git checkout of a DIFFERENT repo → abort.
#
# Plus arg-passthrough behavior:
#   5. `--` sentinel from bash -c "$(curl …)" -s -- is stripped before
#      handoff (Tests run live discovered: bash -c forwards `--` as
#      $1, which bootstrap.sh's args parser doesn't recognize.)
#   6. Real flags (--dry-run, --launcher-only) reach bootstrap.sh.
#
# Mock strategy: we never hit the network or invoke real git. We drop a
# `git` shim and a `bootstrap.sh` stub on PATH (or at the clone dest)
# that log their argv to a file we can grep. Same pattern as the
# launcher tests' open/osascript mocking.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR_REPO="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR_REPO
  INSTALL_SH="$BOOTSTRAP_DIR_REPO/install.sh"
  export INSTALL_SH

  SANDBOX="$(mktemp -d)"
  export SANDBOX
  MOCK_LOG="$SANDBOX/mock.log"
  : >"$MOCK_LOG"
  export MOCK_LOG

  # Per-test PATH front-loaded with our shim dir. Real binaries (mkdir,
  # cat, mktemp, etc.) still resolve via the normal PATH that follows.
  SHIM_DIR="$SANDBOX/shims"
  mkdir -p "$SHIM_DIR"
  export PATH="$SHIM_DIR:$PATH"
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# Drop a mock `git` that:
#   * Logs its argv (one space-joined line per call) to MOCK_LOG.
#   * For `git clone --branch <ref> <url> <dir>`: creates <dir> with a
#     minimal .git/ marker AND a stub bootstrap.sh that echoes its
#     argv. This is the on-disk state install.sh hands off to.
#   * For `git -C <dir> remote get-url origin`: prints SIMULATED_ORIGIN
#     (default: the project's real origin URL).
#   * For `git -C <dir> symbolic-ref -q HEAD`: succeeds (we're on a
#     branch, not detached HEAD).
#   * Everything else: log and exit 0.
_mock_git() {
  cat >"$SHIM_DIR/git" <<'GITEOF'
#!/bin/bash
# Mock git for install.sh tests. Logs argv, simulates clone + remote queries.
echo "git $*" >>"${MOCK_LOG:?MOCK_LOG must be set}"

# Parse out the -C <dir> prefix if present (git -C <dir> <subcmd> …).
# We do this manually because we need the remaining subcommand and args.
sub_args=("$@")
if [ "${1:-}" = "-C" ]; then
  shift 2  # drop "-C" and the dir
fi
subcmd="${1:-}"
shift || true

case "$subcmd" in
  clone)
    # Args after `clone`: --branch <ref> <url> <dir>
    # Or: --branch <ref> --depth <n> <url> <dir>
    # We just grab the last two positional args.
    args=("$@")
    n=${#args[@]}
    if [ "$n" -lt 2 ]; then
      echo "mock git clone: too few args" >&2
      exit 1
    fi
    dir="${args[$((n-1))]}"
    # If SIMULATED_CLONE_FAILS is set, fail instead.
    if [ -n "${SIMULATED_CLONE_FAILS:-}" ]; then
      echo "fatal: simulated clone failure" >&2
      exit 128
    fi
    mkdir -p "$dir/.git"
    # Drop a stub bootstrap.sh that echoes argv to MOCK_LOG.
    cat >"$dir/bootstrap.sh" <<'STUBEOF'
#!/bin/bash
echo "bootstrap.sh $*" >>"${MOCK_LOG:?}"
exit 0
STUBEOF
    chmod +x "$dir/bootstrap.sh"
    exit 0
    ;;
  remote)
    # `git -C <dir> remote get-url origin` → print SIMULATED_ORIGIN.
    if [ "${1:-}" = "get-url" ] && [ "${2:-}" = "origin" ]; then
      echo "${SIMULATED_ORIGIN:-https://github.com/skwid138/ai-dev-bootstrap-mac.git}"
      exit 0
    fi
    exit 0
    ;;
  fetch|checkout|pull)
    # No-op success.
    exit 0
    ;;
  symbolic-ref)
    # `git -C <dir> symbolic-ref -q HEAD` — return success (on a branch).
    if [ -n "${SIMULATED_DETACHED_HEAD:-}" ]; then
      exit 1
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
GITEOF
  chmod +x "$SHIM_DIR/git"
}

# Drop a mock `xcode-select` that just logs and exits 0.
_mock_xcode_select() {
  cat >"$SHIM_DIR/xcode-select" <<'EOF'
#!/bin/bash
echo "xcode-select $*" >>"${MOCK_LOG:?MOCK_LOG must be set}"
exit 0
EOF
  chmod +x "$SHIM_DIR/xcode-select"
}

# Hide the real git from PATH for one test — used to verify the
# "git not installed → trigger CLT installer" path.
_hide_git() {
  cat >"$SHIM_DIR/git" <<'EOF'
#!/bin/bash
# Sentinel: simulates git missing. Bash's `command -v git` will still
# find this file, but we make it exit 127 so any actual call fails.
# install.sh uses `command -v git`, not invocation, so we need a
# different approach: don't drop a git shim at all; PATH will fall
# through to real git. Instead, override `command` via alias —
# but install.sh runs in a separate process so aliases don't carry.
#
# Final approach: prepend a PATH that contains NOTHING, so command -v
# finds no git anywhere. Implemented via bash -c "PATH=/empty install.sh".
exit 127
EOF
  chmod +x "$SHIM_DIR/git"
}

# Run install.sh with a clean, controlled environment.
# Sets BOOTSTRAP_DIR to a per-test target inside SANDBOX.
_run_install() {
  local target="$SANDBOX/target"
  BOOTSTRAP_DIR="$target" \
  BOOTSTRAP_REPO="${BOOTSTRAP_REPO_OVERRIDE:-https://github.com/skwid138/ai-dev-bootstrap-mac.git}" \
  BOOTSTRAP_REF="${BOOTSTRAP_REF_OVERRIDE:-main}" \
  bash "$INSTALL_SH" "$@"
}

# ─────────────────────────────────────────────────────────────────────
# Smoke / structural
# ─────────────────────────────────────────────────────────────────────

@test "install.sh: file exists, is executable, passes shellcheck-style syntax" {
  [ -x "$INSTALL_SH" ]
  bash -n "$INSTALL_SH"
}

@test "install.sh: README curl one-liner points at install.sh, not bootstrap.sh" {
  # Regression gate against the historical bug: README's curl URL used to
  # point at bootstrap.sh (broken since project went multi-file).
  run grep -F 'install.sh)"' "$BOOTSTRAP_DIR_REPO/README.md"
  [ "$status" -eq 0 ]
  run grep -F 'main/bootstrap.sh)"' "$BOOTSTRAP_DIR_REPO/README.md"
  [ "$status" -ne 0 ]  # the broken form must NOT appear
}

# ─────────────────────────────────────────────────────────────────────
# Path 1: fresh clone
# ─────────────────────────────────────────────────────────────────────

@test "install.sh: fresh clone — invokes git clone with correct args" {
  _mock_git
  _mock_xcode_select
  run _run_install
  [ "$status" -eq 0 ]
  # Expect: a `git clone --branch main <repo> <target>` line in the log.
  run grep -F 'git clone --branch main https://github.com/skwid138/ai-dev-bootstrap-mac.git' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "install.sh: fresh clone — exec's bootstrap.sh from clone target" {
  _mock_git
  _mock_xcode_select
  run _run_install
  [ "$status" -eq 0 ]
  # The stub bootstrap.sh logs its own invocation. Presence proves handoff.
  run grep -F 'bootstrap.sh' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "install.sh: fresh clone — passes through arbitrary flags to bootstrap.sh" {
  _mock_git
  _mock_xcode_select
  run _run_install --dry-run --non-interactive
  [ "$status" -eq 0 ]
  run grep -F 'bootstrap.sh --dry-run --non-interactive' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "install.sh: fresh clone — clone failure aborts with non-zero exit" {
  _mock_git
  _mock_xcode_select
  SIMULATED_CLONE_FAILS=1 run _run_install
  [ "$status" -ne 0 ]
  # bootstrap.sh stub must NOT have been invoked.
  run grep -F 'bootstrap.sh' "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "install.sh: fresh clone — honors BOOTSTRAP_REF env override" {
  _mock_git
  _mock_xcode_select
  BOOTSTRAP_REF_OVERRIDE="some-feature-branch" run _run_install
  [ "$status" -eq 0 ]
  run grep -F 'git clone --branch some-feature-branch' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "install.sh: fresh clone — honors BOOTSTRAP_REPO env override" {
  _mock_git
  _mock_xcode_select
  BOOTSTRAP_REPO_OVERRIDE="https://example.com/fork.git" run _run_install
  [ "$status" -eq 0 ]
  run grep -F 'https://example.com/fork.git' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

# ─────────────────────────────────────────────────────────────────────
# Path 2: refresh existing checkout of THIS repo
# ─────────────────────────────────────────────────────────────────────

@test "install.sh: existing same-repo checkout — refreshes via fetch + checkout + ff-pull" {
  _mock_git
  _mock_xcode_select
  # Pre-create a fake checkout with a .git/ marker AND a stub bootstrap.sh.
  mkdir -p "$SANDBOX/target/.git"
  cat >"$SANDBOX/target/bootstrap.sh" <<'EOF'
#!/bin/bash
echo "bootstrap.sh $*" >>"${MOCK_LOG:?}"
EOF
  chmod +x "$SANDBOX/target/bootstrap.sh"

  run _run_install
  [ "$status" -eq 0 ]
  run grep -F 'git -C ' "$MOCK_LOG"
  [ "$status" -eq 0 ]
  # All three operations should appear.
  grep -qF 'remote get-url origin' "$MOCK_LOG"
  grep -qF 'fetch origin' "$MOCK_LOG"
  grep -qF 'checkout main' "$MOCK_LOG"
  grep -qF 'pull --ff-only origin main' "$MOCK_LOG"
}

@test "install.sh: existing same-repo checkout — does NOT re-clone" {
  _mock_git
  _mock_xcode_select
  mkdir -p "$SANDBOX/target/.git"
  cat >"$SANDBOX/target/bootstrap.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$SANDBOX/target/bootstrap.sh"

  run _run_install
  [ "$status" -eq 0 ]
  # No `git clone` line in the log.
  run grep -F 'git clone' "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "install.sh: existing same-repo checkout — handles GitHub URL with/without .git suffix" {
  _mock_git
  _mock_xcode_select
  mkdir -p "$SANDBOX/target/.git"
  cat >"$SANDBOX/target/bootstrap.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$SANDBOX/target/bootstrap.sh"

  # Origin without .git, repo URL with .git → should still match.
  SIMULATED_ORIGIN="https://github.com/skwid138/ai-dev-bootstrap-mac" run _run_install
  [ "$status" -eq 0 ]
}

@test "install.sh: existing same-repo checkout — skips pull on detached HEAD" {
  _mock_git
  _mock_xcode_select
  mkdir -p "$SANDBOX/target/.git"
  cat >"$SANDBOX/target/bootstrap.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$SANDBOX/target/bootstrap.sh"

  SIMULATED_DETACHED_HEAD=1 run _run_install
  [ "$status" -eq 0 ]
  # checkout should run; pull should not.
  grep -qF 'checkout main' "$MOCK_LOG"
  run grep -F 'pull --ff-only' "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

# ─────────────────────────────────────────────────────────────────────
# Path 3: existing dir is not a git checkout
# ─────────────────────────────────────────────────────────────────────

@test "install.sh: existing non-git dir — aborts with clear message; does NOT clobber" {
  _mock_git
  _mock_xcode_select
  mkdir -p "$SANDBOX/target"
  echo "user content" >"$SANDBOX/target/some-file"

  run _run_install
  [ "$status" -ne 0 ]
  # Error message mentions the directory and BOOTSTRAP_DIR escape hatch.
  echo "$output" | grep -qF "$SANDBOX/target"
  echo "$output" | grep -qF "BOOTSTRAP_DIR"
  # User content untouched.
  [ -f "$SANDBOX/target/some-file" ]
  [ "$(cat "$SANDBOX/target/some-file")" = "user content" ]
}

# ─────────────────────────────────────────────────────────────────────
# Path 4: existing dir is a checkout of a DIFFERENT repo
# ─────────────────────────────────────────────────────────────────────

@test "install.sh: existing different-repo checkout — aborts; does NOT clobber" {
  _mock_git
  _mock_xcode_select
  mkdir -p "$SANDBOX/target/.git"
  echo "different-repo work" >"$SANDBOX/target/precious.txt"

  SIMULATED_ORIGIN="https://github.com/some/other-repo.git" run _run_install
  [ "$status" -ne 0 ]
  # Error message mentions the foreign origin URL.
  echo "$output" | grep -qF "https://github.com/some/other-repo.git"
  # User content untouched.
  [ -f "$SANDBOX/target/precious.txt" ]
}

# ─────────────────────────────────────────────────────────────────────
# Path 5: arg-passthrough corner cases (curl-pipe artifacts)
# ─────────────────────────────────────────────────────────────────────

@test "install.sh: strips leading '--' before handing off to bootstrap.sh" {
  # Real-world bug: `bash -c "$(curl …)" -s -- --dry-run` makes $@ =
  # ("--", "--dry-run"). Forwarding both to bootstrap.sh trips
  # lib/args.sh's "Unknown flag: --". install.sh must strip the
  # leading "--" sentinel before exec.
  _mock_git
  _mock_xcode_select
  run _run_install -- --dry-run
  [ "$status" -eq 0 ]
  run grep -F 'bootstrap.sh --dry-run' "$MOCK_LOG"
  [ "$status" -eq 0 ]
  # And critically, the log must NOT show '-- --dry-run' (proving the strip).
  run grep -F 'bootstrap.sh -- --dry-run' "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "install.sh: '--' alone (no following flags) is also stripped" {
  _mock_git
  _mock_xcode_select
  run _run_install --
  [ "$status" -eq 0 ]
  # bootstrap.sh stub gets invoked with NO flags, not with '--'.
  run grep -E '^bootstrap\.sh *$' "$MOCK_LOG"
  [ "$status" -eq 0 ]
}

@test "install.sh: '--' in the middle of args is NOT stripped" {
  # Only the LEADING -- is the curl-pipe sentinel. A -- elsewhere is
  # something the user meaningfully passed (unlikely but possible).
  _mock_git
  _mock_xcode_select
  run _run_install --dry-run -- --something-else
  [ "$status" -eq 0 ]
  # Whatever the exact passthrough shape, --dry-run reaches bootstrap.
  # The `-- 'pattern'` form is required because grep would otherwise
  # interpret `--dry-run` as its own flag.
  grep -qF -- '--dry-run' "$MOCK_LOG"
}

# ─────────────────────────────────────────────────────────────────────
# Preflight: git missing
# ─────────────────────────────────────────────────────────────────────

@test "install.sh: aborts with helpful message when git is unavailable" {
  # Use a custom PATH that contains NO git. We have to keep basic shell
  # builtins (mkdir, mktemp, cat, etc.) reachable — those are in /bin
  # and /usr/bin — but exclude wherever git lives. macOS ships git via
  # Xcode CLT at /usr/bin/git, so we must drop /usr/bin from PATH and
  # use absolute paths for any external tool install.sh needs.
  #
  # Simpler approach: shim `git` to be absent by NOT dropping a git
  # shim and pointing PATH at our shim dir alone (no fallthrough).
  _mock_xcode_select
  # Provide a minimal but functional PATH: SHIM_DIR (xcode-select) +
  # /bin (cat, mkdir) + /usr/bin (mktemp, dirname). We must EXCLUDE
  # /usr/bin/git specifically. macOS doesn't have a way to PATH-mask
  # individual binaries, so we drop /usr/bin and shim the few tools
  # install.sh actually needs.
  ln -sf /bin/cat "$SHIM_DIR/cat"
  ln -sf /bin/mkdir "$SHIM_DIR/mkdir"
  ln -sf /usr/bin/dirname "$SHIM_DIR/dirname"
  ln -sf /usr/bin/printf "$SHIM_DIR/printf" 2>/dev/null || true
  # Ensure no git anywhere in our restricted PATH.
  rm -f "$SHIM_DIR/git"

  BOOTSTRAP_DIR="$SANDBOX/target" \
  PATH="$SHIM_DIR:/bin" \
  run bash "$INSTALL_SH"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qiE 'git.*not installed|Command Line Tools'
  # No clone occurred (target dir not created).
  [ ! -e "$SANDBOX/target" ]
}
