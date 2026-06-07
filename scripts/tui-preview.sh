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

Options:
  --local [path]  Use local dev build instead of npm package. Default: $HOME/code/opencode-tui/dist/tui.js
EOF
}

TUI_PLUGIN_SPEC="@skwid138/opencode-tui@1.1.1"
TUI_PLUGIN_CONFIG="{}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --local)
      shift
      if [[ $# -gt 0 ]] && [[ -n "$1" ]] && [[ "$1" != -* ]]; then
        LOCAL_PATH="$1"
        shift
      else
        LOCAL_PATH="$HOME/code/opencode-tui/dist/tui.js"
      fi
      ;;
    *)
      die_usage "unexpected argument: $1"
      ;;
  esac
done

if [[ -n "${LOCAL_PATH:-}" ]]; then
  # Reject paths with characters unsafe for JSON printf
  if [[ "$LOCAL_PATH" == *'"'* ]] || [[ "$LOCAL_PATH" == *\\* ]]; then
    die "Path contains unsafe characters (quotes or backslashes): $LOCAL_PATH"
  fi
  # Resolve relative paths to absolute
  if [[ "$LOCAL_PATH" != /* ]]; then
    resolved_dir="$(cd "$(dirname "$LOCAL_PATH")" 2>/dev/null && pwd)" || {
      die "Cannot resolve path: $LOCAL_PATH (directory does not exist)"
    }
    LOCAL_PATH="$resolved_dir/$(basename "$LOCAL_PATH")"
  fi
  # Validate file exists and is readable
  if [[ ! -f "$LOCAL_PATH" ]] || [[ ! -r "$LOCAL_PATH" ]]; then
    printf '%s\n' "Local TUI plugin not found or not readable: $LOCAL_PATH" >&2
    die "  Try: cd ~/code/opencode-tui && npm run build"
  fi
  TUI_PLUGIN_SPEC="$LOCAL_PATH"
fi

require_cmd opencode "Install OpenCode before running the TUI preview."

TUI_TEMPLATE="${REPO_ROOT}/opencode/tui.json.template"
if command -v jq >/dev/null 2>&1 && [[ -f "$TUI_TEMPLATE" ]]; then
  if TUI_PLUGIN_CONFIG_CANDIDATE="$(jq -c '
    [.plugin[]? | select(
      type == "array"
      and length > 1
      and (.[0] | type == "string" and startswith("@skwid138/opencode-tui"))
    ) | .[1]]
    | first // empty
  ' "$TUI_TEMPLATE" 2>/dev/null)"; then
    if [[ -n "$TUI_PLUGIN_CONFIG_CANDIDATE" ]] && [[ "$TUI_PLUGIN_CONFIG_CANDIDATE" != "null" ]]; then
      TUI_PLUGIN_CONFIG="$TUI_PLUGIN_CONFIG_CANDIDATE"
    fi
  fi
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opencode-tui-preview.XXXXXX")" || die "failed to create temp directory"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/.opencode" || die "failed to create temp OpenCode config directory"

{
  printf '{\n'
  printf "  \"\$schema\": \"https://opencode.ai/tui.json\",\n"
  printf '  "theme": "flamingo-ember",\n'
  printf '  "plugin": [\n'
  printf '    ["%s", %s]\n' "$TUI_PLUGIN_SPEC" "$TUI_PLUGIN_CONFIG"
  printf '  ]\n'
  printf '}\n'
} >"$TMP_DIR/.opencode/tui.json" || die "failed to write temp TUI config"

info "Starting OpenCode TUI preview with $TUI_PLUGIN_SPEC in isolated temp directory: $TMP_DIR"
(
  cd "$TMP_DIR" || exit 1
  exec opencode
)
exit $?
