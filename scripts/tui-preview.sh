#!/usr/bin/env bash
# tui-preview.sh — launch OpenCode in a temporary workspace with repo TUI plugins loaded.
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

Launch OpenCode in an isolated temporary directory with all repo TUI plugins
copied into .opencode/plugins/ and enabled in .opencode/tui.json.
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

PLUGIN_SRC_DIR="${REPO_ROOT}/opencode/plugins"
[[ -d "$PLUGIN_SRC_DIR" ]] || die "plugin source directory not found: $PLUGIN_SRC_DIR"

plugin_files=()
for plugin_file in "$PLUGIN_SRC_DIR"/*.tsx; do
  [[ -f "$plugin_file" ]] || continue
  plugin_files+=("$plugin_file")
done

[[ "${#plugin_files[@]}" -gt 0 ]] || die "no TSX plugins found in $PLUGIN_SRC_DIR"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/opencode-tui-preview.XXXXXX")" || die "failed to create temp directory"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/.opencode/plugins" || die "failed to create temp OpenCode plugin directory"

plugin_names=()
for plugin_file in "${plugin_files[@]}"; do
  plugin_name="$(basename "$plugin_file")"
  cp "$plugin_file" "$TMP_DIR/.opencode/plugins/$plugin_name" || die "failed to copy plugin: $plugin_name"
  plugin_names+=("$plugin_name")
done

{
  printf '{\n'
  printf "  \"\$schema\": \"https://opencode.ai/tui.json\",\n"
  printf '  "theme": "flamingo-ember",\n'
  printf '  "plugin": [\n'
  last_index=$((${#plugin_names[@]} - 1))
  for index in "${!plugin_names[@]}"; do
    comma=","
    if [[ "$index" -eq "$last_index" ]]; then
      comma=""
    fi
    printf '    ["./plugins/%s", {}]%s\n' "${plugin_names[$index]}" "$comma"
  done
  printf '  ]\n'
  printf '}\n'
} >"$TMP_DIR/.opencode/tui.json" || die "failed to write temp TUI config"

info "Starting OpenCode TUI preview in isolated temp directory: $TMP_DIR"
(
  cd "$TMP_DIR" || exit 1
  exec opencode
)
exit $?
