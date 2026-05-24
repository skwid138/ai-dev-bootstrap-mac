#!/usr/bin/env bash
# tui-preview.sh — launch OpenCode in a temporary workspace with the packaged TUI plugin loaded.
# Usage: scripts/tui-preview.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=./scripts/lib/common.sh
# shellcheck disable=SC1091
source "${REPO_ROOT}/scripts/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: tui-preview.sh

Launch OpenCode in an isolated temporary directory with the packaged
@skwid138/opencode-tui TUI plugin enabled in .opencode/tui.json.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die_usage "unexpected argument: $1"
      ;;
  esac
done

require_cmd opencode "Install OpenCode before running the TUI preview."

TUI_PLUGIN_SPEC="@skwid138/opencode-tui@1.0.0"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opencode-tui-preview.XXXXXX")" || die "failed to create temp directory"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/.opencode" || die "failed to create temp OpenCode config directory"

{
  printf '{\n'
  printf "  \"\$schema\": \"https://opencode.ai/tui.json\",\n"
  printf '  "theme": "flamingo-ember",\n'
  printf '  "plugin": [\n'
  printf '    ["%s", {}]\n' "$TUI_PLUGIN_SPEC"
  printf '  ]\n'
  printf '}\n'
} >"$TMP_DIR/.opencode/tui.json" || die "failed to write temp TUI config"

info "Starting OpenCode TUI preview with $TUI_PLUGIN_SPEC in isolated temp directory: $TMP_DIR"
(
  cd "$TMP_DIR" || exit 1
  exec opencode
)
exit $?
