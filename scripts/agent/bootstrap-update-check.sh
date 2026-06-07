#!/usr/bin/env bash
# Check whether the ai-dev-bootstrap-mac checkout is behind origin and report
# category counts as JSON. Self-contained by design: do not source bootstrap
# libraries from here, because this script is run by an already-installed agent.

set -euo pipefail

# Accept --json for forward compatibility (output is always JSON).
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) shift ;;
    *) shift ;;
  esac
done

json_error() {
  local message="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg error "$message" '{error: $error}'
  else
    printf '{"error":"%s"}\n' "$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  fi
}

state_file="${HOME}/.config/ai-bootstrap/state.sh"
fallback_dir="${HOME}/code/ai-dev-bootstrap-mac"
bootstrap_dir="$fallback_dir"

if [ -f "$state_file" ]; then
  state_dir_line=$(grep -E "^export AI_BOOTSTRAP_DIR='[^']*'$" "$state_file" | tail -n 1 || true)
  if [ -n "$state_dir_line" ]; then
    bootstrap_dir=$(printf '%s' "$state_dir_line" | sed "s/^export AI_BOOTSTRAP_DIR='//; s/'$//")
  fi
fi

if [ ! -d "$bootstrap_dir" ]; then
  json_error "bootstrap directory not found: $bootstrap_dir"
  exit 1
fi

if ! git -C "$bootstrap_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  json_error "bootstrap directory is not a git repo: $bootstrap_dir"
  exit 1
fi

if ! git -C "$bootstrap_dir" fetch origin --prune >/dev/null 2>&1; then
  json_error "could not fetch updates from origin"
  exit 1
fi

detached_head=false
comparison=""
if git -C "$bootstrap_dir" symbolic-ref -q HEAD >/dev/null 2>&1; then
  comparison=$(git -C "$bootstrap_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ -z "$comparison" ]; then
    comparison="origin/main"
  fi
else
  detached_head=true
  comparison="origin/main"
fi

if ! git -C "$bootstrap_dir" rev-parse --verify "$comparison" >/dev/null 2>&1; then
  json_error "could not find comparison ref: $comparison"
  exit 1
fi

if ! commits_behind=$(git -C "$bootstrap_dir" rev-list --count "HEAD..$comparison" 2>/dev/null); then
  json_error "could not compare local checkout with $comparison"
  exit 1
fi

skills=0
commands=0
scripts=0
config=0
launcher=0
other=0

if [ "$commits_behind" -gt 0 ]; then
  while IFS= read -r changed_file || [ -n "$changed_file" ]; do
    [ -n "$changed_file" ] || continue
    case "$changed_file" in
      opencode/skill/*) skills=$((skills + 1)) ;;
      opencode/command/*) commands=$((commands + 1)) ;;
      scripts/*) scripts=$((scripts + 1)) ;;
      opencode/opencode.jsonc.template | lib/*) config=$((config + 1)) ;;
      launcher/*) launcher=$((launcher + 1)) ;;
      *) other=$((other + 1)) ;;
    esac
  done <<<"$(git -C "$bootstrap_dir" diff --name-only "HEAD..$comparison")"
fi

up_to_date=false
if [ "$commits_behind" -eq 0 ]; then
  up_to_date=true
fi

jq -n \
  --argjson up_to_date "$up_to_date" \
  --argjson commits_behind "$commits_behind" \
  --argjson detached_head "$detached_head" \
  --argjson skills "$skills" \
  --argjson commands "$commands" \
  --argjson scripts "$scripts" \
  --argjson config "$config" \
  --argjson launcher "$launcher" \
  --argjson other "$other" \
  --arg bootstrap_dir "$bootstrap_dir" \
  '{
    up_to_date: $up_to_date,
    commits_behind: $commits_behind,
    detached_head: $detached_head,
    categories: {
      skills: $skills,
      commands: $commands,
      scripts: $scripts,
      config: $config,
      launcher: $launcher,
      other: $other
    },
    bootstrap_dir: $bootstrap_dir
  }'
