#!/usr/bin/env bats
# Tests for lib/brewfile.sh.
#
# We mock `brew` via a sandbox dir on PATH so we never touch the user's real
# brew state during tests. Same mocking pattern used elsewhere in this repo.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/brewfile.sh
  source "${BOOTSTRAP_DIR}/lib/brewfile.sh"

  SANDBOX="$(mktemp -d)"
  MOCK_LOG="$SANDBOX/mock.log"
  : >"$MOCK_LOG"
  export MOCK_LOG

  ORIG_PATH="$PATH"
}

teardown() {
  export PATH="$ORIG_PATH"
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# Drop a mock `brew` that logs its argv and (for `bundle dump`) writes a
# fake Brewfile to whatever --file=... path was passed. Exits 0 by default;
# pass "fail" as $1 to make `bundle dump` return non-zero.
_mock_brew() {
  local mode="${1:-ok}"
  cat >"$SANDBOX/brew" <<EOF
#!/usr/bin/env bash
echo "brew \$*" >>"\$MOCK_LOG"
if [[ "\$1" == "bundle" && "\$2" == "dump" ]]; then
  if [[ "$mode" == "fail" ]]; then
    exit 1
  fi
  # Find the --file=PATH arg and write a fake Brewfile there.
  for arg in "\$@"; do
    case "\$arg" in
      --file=*)
        path="\${arg#--file=}"
        cat >"\$path" <<'BREWFILE'
tap "homebrew/core"
brew "git"
cask "ghostty"
BREWFILE
        ;;
    esac
  done
fi
exit 0
EOF
  chmod +x "$SANDBOX/brew"
  export PATH="$SANDBOX:$ORIG_PATH"
}

# Drop a mock environment with NO brew on PATH at all.
_mock_no_brew() {
  # Empty dir on PATH first so `command -v brew` fails. We have to scrub
  # the rest of PATH too in case a real brew is installed.
  export PATH="$SANDBOX:/usr/bin:/bin"
}

@test "brewfile_dump: writes Brewfile to dest path" {
  _mock_brew
  dest="$SANDBOX/.config/ai-bootstrap/Brewfile"

  run brewfile_dump "$dest"
  [ "$status" -eq 0 ]
  [ "$output" = "wrote $dest" ]
  [ -f "$dest" ]
  grep -q "ghostty" "$dest"
}

@test "brewfile_dump: invokes brew bundle dump with --force --describe --file=" {
  _mock_brew
  dest="$SANDBOX/Brewfile"

  run brewfile_dump "$dest"
  [ "$status" -eq 0 ]
  grep -q "brew bundle dump --force --describe --file=$dest" "$MOCK_LOG"
}

@test "brewfile_dump: creates parent directory if missing" {
  _mock_brew
  dest="$SANDBOX/never/existed/Brewfile"

  run brewfile_dump "$dest"
  [ "$status" -eq 0 ]
  [ -f "$dest" ]
}

@test "brewfile_dump: returns 1 when brew is not on PATH" {
  _mock_no_brew

  run brewfile_dump "$SANDBOX/Brewfile"
  [ "$status" -eq 1 ]
  [[ "$output" == *"brew not on PATH"* ]]
}

@test "brewfile_dump: returns 2 when brew bundle dump fails" {
  _mock_brew fail

  run brewfile_dump "$SANDBOX/Brewfile"
  [ "$status" -eq 2 ]
  [[ "$output" == *"brew bundle dump failed"* ]]
}

@test "brewfile_dump: overwrites an existing Brewfile (--force)" {
  _mock_brew
  dest="$SANDBOX/Brewfile"
  echo "stale-content" >"$dest"

  run brewfile_dump "$dest"
  [ "$status" -eq 0 ]
  # Mock writes new content; stale-content must be gone.
  run grep -q "stale-content" "$dest"
  [ "$status" -ne 0 ]
}
