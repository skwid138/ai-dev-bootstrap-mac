#!/usr/bin/env bats
# Tests for modules/14-tailscale.sh. All network/system-facing commands are
# mocked so the add-on never touches the developer machine.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT

  SANDBOX="$BATS_TEST_TMPDIR/tailscale-module"
  export SANDBOX
  export HOME="$SANDBOX/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export USER="test-user"
  export AI_BOOTSTRAP_WORKSPACE="$SANDBOX/workspace"
  export MOCK_LOG="$SANDBOX/mock.log"
  export MOCK_PBCOPY="$SANDBOX/pbcopy.txt"
  export MOCK_DNS_NAME="my-mac.tailnet.ts.net."
  export MOCK_MAGICDNS_STATUS="MagicDNS: enabled"
  export MOCK_KEYCHAIN_PASSWORD="ExistingPassword123"

  mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$AI_BOOTSTRAP_WORKSPACE" "$SANDBOX/mocks"
  : >"$MOCK_LOG"
  : >"$MOCK_PBCOPY"

  export PATH="$SANDBOX/mocks:/usr/bin:/bin:/usr/sbin:/sbin"
  export BOOTSTRAP_DIR="$SANDBOX/bootstrap"
  make_bootstrap_fixture

  export TAILSCALE_APP_PATH="$SANDBOX/Applications/Tailscale.app"
  export TAILSCALE_APP_BIN="$TAILSCALE_APP_PATH/Contents/MacOS/tailscale"
  export TAILSCALE_WRAPPER_PATH="$SANDBOX/usr/local/bin/tailscale"
  mkdir -p "$(dirname "$TAILSCALE_APP_BIN")"
  make_tailscale_command "$TAILSCALE_APP_BIN"
  chmod +x "$TAILSCALE_APP_BIN"

  make_default_mocks
}

make_bootstrap_fixture() {
  mkdir -p \
    "$BOOTSTRAP_DIR/lib" \
    "$BOOTSTRAP_DIR/scripts/lib" \
    "$BOOTSTRAP_DIR/scripts/personal" \
    "$BOOTSTRAP_DIR/dotfiles/rc"

  cp "$REPO_ROOT/lib/breadcrumb.sh" "$BOOTSTRAP_DIR/lib/breadcrumb.sh"
  cat >"$BOOTSTRAP_DIR/bootstrap.sh" <<'EOF'
#!/usr/bin/env bash
echo "bootstrap resumed"
exit 42
EOF
  chmod +x "$BOOTSTRAP_DIR/bootstrap.sh"

  cat >"$BOOTSTRAP_DIR/scripts/lib/keychain.sh" <<'EOF'
#!/usr/bin/env bash
return 0 2>/dev/null || exit 0
EOF
  cat >"$BOOTSTRAP_DIR/scripts/lib/opencode-daemon.sh" <<'EOF'
#!/usr/bin/env bash
opencode_daemon_pid_for_port() { return 0; }
return 0 2>/dev/null || exit 0
EOF
  cat >"$BOOTSTRAP_DIR/scripts/personal/opencode-web.sh" <<'EOF'
#!/usr/bin/env bash
echo "opencode-web:$*" >>"$MOCK_LOG"
exit 0
EOF
  cat >"$BOOTSTRAP_DIR/scripts/personal/opencode-attach.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  cat >"$BOOTSTRAP_DIR/scripts/personal/opensession.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$BOOTSTRAP_DIR/scripts/personal/"*.sh

  cat >"$BOOTSTRAP_DIR/dotfiles/rc/tailscale.zsh" <<'EOF'
[[ ! -f "${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opensession.sh" ]] || alias opensession="${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opensession.sh"
[[ ! -f "${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opencode-web.sh" ]] || alias opencode-web="${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opencode-web.sh"
[[ ! -f "${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opencode-attach.sh" ]] || alias opencode-attach="${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opencode-attach.sh"
EOF
}

write_mock() {
  local name="$1"
  shift
  cat >"$SANDBOX/mocks/$name"
  chmod +x "$SANDBOX/mocks/$name"
}

make_tailscale_command() {
  local path="$1"
  cat >"$path" <<'EOF'
#!/usr/bin/env bash
printf 'tailscale:%s\n' "$*" >>"$MOCK_LOG"
case "$1" in
  status)
    if [ "${2:-}" = "--json" ]; then
      printf '{"Self":{"DNSName":"%s"}}\n' "$MOCK_DNS_NAME"
    else
      printf 'Logged in\n'
    fi
    ;;
  dns)
    printf '%s\n' "$MOCK_MAGICDNS_STATUS"
    ;;
  set)
    shift
    printf 'tailscale-set:%s\n' "$*" >>"$MOCK_LOG"
    ;;
  serve)
    if [ "${2:-}" = "status" ] || [ "${1:-}" = "serve" ] && [ "${2:-}" = "status" ]; then
      printf '{"Web":{"my-mac.tailnet.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:4096"}}}}}\n'
    else
      :
    fi
    ;;
esac
exit 0
EOF
}

make_default_mocks() {
  write_mock gum <<'EOF'
#!/usr/bin/env bash
case "$1" in
  choose)
    printf '%s\n' "${MOCK_GUM_CHOICE:-Exit}"
    ;;
  confirm)
    printf 'gum-confirm:%s\n' "$2" >>"$MOCK_LOG"
    exit "${MOCK_GUM_CONFIRM_STATUS:-0}"
    ;;
  input)
    printf 'gum-input:%s\n' "$*" >>"$MOCK_LOG"
    counter_file="$SANDBOX/gum-input-count"
    count=0
    [ -f "$counter_file" ] && count="$(cat "$counter_file")"
    count=$((count + 1))
    printf '%s' "$count" >"$counter_file"
    case "$count" in
      1) printf '%s\n' "${MOCK_GUM_INPUT_1:-}" ;;
      2) printf '%s\n' "${MOCK_GUM_INPUT_2:-}" ;;
      *) printf '%s\n' "${MOCK_GUM_INPUT_DEFAULT:-}" ;;
    esac
    ;;
  style)
    shift
    printf '%s\n' "${*: -1}"
    ;;
esac
EOF

  write_mock opencode <<'EOF'
#!/usr/bin/env bash
printf 'opencode:%s\n' "$*" >>"$MOCK_LOG"
EOF

  make_tailscale_command "$SANDBOX/mocks/tailscale"
  chmod +x "$SANDBOX/mocks/tailscale"

  write_mock security <<'EOF'
#!/usr/bin/env bash
printf 'security:%s\n' "$*" >>"$MOCK_LOG"
if [ "$1" = "find-generic-password" ]; then
  if [ -n "${MOCK_KEYCHAIN_PASSWORD:-}" ]; then
    printf '%s\n' "$MOCK_KEYCHAIN_PASSWORD"
    exit 0
  fi
  exit 44
fi
if [ "$1" = "add-generic-password" ]; then
  exit 0
fi
EOF

  write_mock pbcopy <<'EOF'
#!/usr/bin/env bash
cat >"$MOCK_PBCOPY"
EOF

  write_mock open <<'EOF'
#!/usr/bin/env bash
printf 'open:%s\n' "$*" >>"$MOCK_LOG"
EOF

  write_mock curl <<'EOF'
#!/usr/bin/env bash
printf 'curl:%s\n' "$*" >>"$MOCK_LOG"
out=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-fsSLo" ]; then
    out="$2"
    break
  fi
  shift
done
[ -n "$out" ] && printf 'pkg' >"$out"
EOF

  write_mock pkgutil <<'EOF'
#!/usr/bin/env bash
printf 'pkgutil:%s\n' "$*" >>"$MOCK_LOG"
printf 'Developer ID Installer: Tailscale Inc. (W5364U7YZB)\n'
EOF

  write_mock sudo <<'EOF'
#!/usr/bin/env bash
printf 'sudo:%s\n' "$*" >>"$MOCK_LOG"
case "$1" in
  installer)
    exit 0
    ;;
  tee)
    cat >"$2"
    exit 0
    ;;
  chmod)
    chmod "$2" "$3"
    exit 0
    ;;
esac
exit 0
EOF

  write_mock jq <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' "$MOCK_DNS_NAME"
EOF

  write_mock tr <<'EOF'
#!/usr/bin/env bash
printf 'tr:%s\n' "$*" >>"$MOCK_LOG"
printf 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
EOF
}

run_module() {
  run bash -c '
    log_info() { printf "INFO:%s\n" "$*"; }
    log_warn() { printf "WARN:%s\n" "$*"; }
    log_error() { printf "ERROR:%s\n" "$*"; }
    log_skip() { printf "SKIP:%s\n" "$*"; }
    log_installed() { printf "INSTALLED:%s\n" "$*"; }
    command_exists() { command -v "$1" >/dev/null 2>&1; }
    ensure_dir() { mkdir -p "$1"; }
    ui_choose() { gum choose "$@"; }
    ui_confirm() { gum confirm "$1"; }
    ui_success() { printf "SUCCESS:%s\n" "$*"; }
    export BOOTSTRAP_DIR PATH HOME XDG_CONFIG_HOME USER AI_BOOTSTRAP_WORKSPACE MOCK_LOG MOCK_PBCOPY MOCK_DNS_NAME MOCK_MAGICDNS_STATUS MOCK_KEYCHAIN_PASSWORD MOCK_GUM_CHOICE MOCK_GUM_INPUT_1 MOCK_GUM_INPUT_2 MOCK_GUM_INPUT_DEFAULT MOCK_GUM_CONFIRM_STATUS TAILSCALE_APP_PATH TAILSCALE_APP_BIN TAILSCALE_WRAPPER_PATH SANDBOX
    source "$REPO_ROOT/modules/14-tailscale.sh"
  '
}

@test "missing gum exits with error" {
  rm -f "$SANDBOX/mocks/gum"

  run_module

  [ "$status" -eq 1 ]
  [[ "$output" == *"Remote Access needs gum"* ]]
}

@test "missing opencode offers installer choice" {
  rm -f "$SANDBOX/mocks/opencode"
  export MOCK_GUM_CHOICE="Run full installer"

  run_module

  [ "$status" -eq 42 ]
  [ -f "$XDG_CONFIG_HOME/ai-bootstrap/breadcrumbs/tailscale" ]
  [[ "$output" == *"bootstrap resumed"* ]]
}

write_tailscale_state() {
  mkdir -p "$HOME/.config/ai-bootstrap"
  cat >"$HOME/.config/ai-bootstrap/tailscale.sh" <<EOF
#!/bin/bash
export TAILSCALE_CT_SHOWN='${1:-1}'
export TAILSCALE_HOSTNAME='${2:-my-mac}'
export TAILSCALE_SERVE_URL='${3:-https://my-mac.tailnet.ts.net}'
export TAILSCALE_SETUP_AT='2026-01-01T00:00:00Z'
EOF
}

assert_file_not_contains() {
  local needle="$1"
  local file="$2"
  [ -f "$file" ]
  ! grep -qF "$needle" "$file"
}

assert_tree_not_contains() {
  local needle="$1"
  local dir="$2"
  [ -d "$dir" ]
  ! grep -R -qF "$needle" "$dir"
}

@test "pkg install resolves highest stable version before reporting download failure" {
  rm -rf "$TAILSCALE_APP_PATH"
  write_mock curl <<'EOF'
#!/usr/bin/env bash
printf 'curl:%s\n' "$*" >>"$MOCK_LOG"

if [ "$1" = "-fsSL" ] && [ "$2" = "https://pkgs.tailscale.com/stable/" ]; then
  cat <<'HTML'
<a href="Tailscale-1.82.5-macos.pkg">Tailscale-1.82.5-macos.pkg</a>
<a href="Tailscale-1.84.1-macos.pkg">Tailscale-1.84.1-macos.pkg</a>
<a href="Tailscale-1.84.2-macos.pkg">Tailscale-1.84.2-macos.pkg</a>
<a href="Tailscale-latest-macos.pkg">Tailscale-latest-macos.pkg</a>
HTML
  exit 0
fi

if [ "$1" = "-fsSLo" ]; then
  printf 'download-url:%s\n' "$3" >>"$MOCK_LOG"
  exit 23
fi

exit 99
EOF

  run_module

  [ "$status" -eq 1 ]
  grep -qF 'curl:-fsSL https://pkgs.tailscale.com/stable/' "$MOCK_LOG"
  grep -qF 'download-url:https://pkgs.tailscale.com/stable/Tailscale-1.84.2-macos.pkg' "$MOCK_LOG"
  ! grep -q -- '-latest-macos.pkg' "$MOCK_LOG"
  [[ "$output" == *"1.84.2"* ]]
}

@test "re-run skips pkg install when Tailscale.app exists" {
  mkdir -p "$TAILSCALE_APP_PATH"
  write_tailscale_state

  run_module

  [ "$status" -eq 0 ]
  ! grep -q '^curl:' "$MOCK_LOG"
  ! grep -q '^sudo:installer ' "$MOCK_LOG"
}

@test "re-run skips CLI wrapper when command lookup succeeds" {
  write_tailscale_state

  run_module

  [ "$status" -eq 0 ]
  [ ! -e "$TAILSCALE_WRAPPER_PATH" ]
  ! grep -q "sudo:tee $TAILSCALE_WRAPPER_PATH" "$MOCK_LOG"
  ! grep -q "sudo:chmod +x $TAILSCALE_WRAPPER_PATH" "$MOCK_LOG"
}

@test "CLI wrapper created when command lookup fails but app binary exists" {
  rm -f "$SANDBOX/mocks/tailscale"

  run_module

  [ "$status" -eq 0 ]
  [ -x "$TAILSCALE_WRAPPER_PATH" ]
  grep -qF 'exec /Applications/Tailscale.app/Contents/MacOS/tailscale "$@"' "$TAILSCALE_WRAPPER_PATH"
  grep -q "sudo:tee $TAILSCALE_WRAPPER_PATH" "$MOCK_LOG"
}

@test "password generation stores in keychain and copies to clipboard" {
  export MOCK_KEYCHAIN_PASSWORD=""

  run_module

  [ "$status" -eq 0 ]
  grep -q "security:add-generic-password -s opencode-server-password -a test-user -w AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA -T " "$MOCK_LOG"
  [ "$(cat "$MOCK_PBCOPY")" = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" ]
}

@test "re-run with existing password skips generation and re-copies" {
  export MOCK_KEYCHAIN_PASSWORD="SavedSecret"
  write_tailscale_state

  run_module
  [ "$status" -eq 0 ]
  ! grep -q "security:add-generic-password" "$MOCK_LOG"
  ! grep -q '^tr:' "$MOCK_LOG"
  [ "$(cat "$MOCK_PBCOPY")" = "SavedSecret" ]
}

@test "re-run skips CT explanation when state says it was already shown" {
  write_tailscale_state 1

  run_module

  [ "$status" -eq 0 ]
  [[ "$output" != *"certificate records"* ]]
}

@test "re-run still overwrites deployed scripts with fresh copies" {
  write_tailscale_state
  mkdir -p "$AI_BOOTSTRAP_WORKSPACE/scripts/personal" "$HOME/.config/ai-bootstrap/shell/rc"
  printf '%s\n' '# stale helper' >"$AI_BOOTSTRAP_WORKSPACE/scripts/personal/opencode-web.sh"
  printf '%s\n' '# stale aliases' >"$HOME/.config/ai-bootstrap/shell/rc/tailscale.zsh"

  run_module

  [ "$status" -eq 0 ]
  ! grep -qF '# stale helper' "$AI_BOOTSTRAP_WORKSPACE/scripts/personal/opencode-web.sh"
  grep -qF 'opencode-web:$*' "$AI_BOOTSTRAP_WORKSPACE/scripts/personal/opencode-web.sh"
  ! grep -qF '# stale aliases' "$HOME/.config/ai-bootstrap/shell/rc/tailscale.zsh"
  grep -qF 'alias opencode-web=' "$HOME/.config/ai-bootstrap/shell/rc/tailscale.zsh"
}

@test "re-run still shows hostname option" {
  write_tailscale_state 1

  run_module

  [ "$status" -eq 0 ]
  [[ "$output" == *"Current device name: my-mac"* ]]
  grep -qF 'gum-input:input --prompt Device name:  --value my-mac' "$MOCK_LOG"
}

@test "hostname validation rejects invalid names" {
  export MOCK_GUM_INPUT_1="Bad_Name!"
  export MOCK_GUM_INPUT_2="valid-name"

  run_module
  [ "$status" -eq 0 ]
  [[ "$output" == *"Use lowercase letters"* ]]
  grep -q "tailscale-set:--hostname valid-name" "$MOCK_LOG"
}

@test "state file written after success" {
  run_module
  [ "$status" -eq 0 ]

  state_file="$HOME/.config/ai-bootstrap/tailscale.sh"
  [ -f "$state_file" ]
  grep -q "export TAILSCALE_CT_SHOWN='1'" "$state_file"
  grep -q "export TAILSCALE_HOSTNAME='my-mac'" "$state_file"
  grep -q "export TAILSCALE_SERVE_URL='https://my-mac.tailnet.ts.net'" "$state_file"
  ! grep -q "ExistingPassword123" "$state_file"
}

@test "password is not written to state, shell config, or module source" {
  export MOCK_KEYCHAIN_PASSWORD="UniqueSecretNotInFiles123"

  run_module
  [ "$status" -eq 0 ]

  assert_file_not_contains "$MOCK_KEYCHAIN_PASSWORD" "$HOME/.config/ai-bootstrap/tailscale.sh"
  assert_tree_not_contains "$MOCK_KEYCHAIN_PASSWORD" "$REPO_ROOT/dotfiles"
  assert_tree_not_contains "$MOCK_KEYCHAIN_PASSWORD" "$HOME/.config/ai-bootstrap/shell"
  assert_file_not_contains "$MOCK_KEYCHAIN_PASSWORD" "$REPO_ROOT/modules/14-tailscale.sh"
}
