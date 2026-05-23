#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="$SCRIPT_DIR/../model-profiles.json"
CONFIG="$HOME/.config/opencode/opencode.json"
STATE_FILE="$HOME/.config/ai-bootstrap/state.sh"

tier="${1:-default}"

if [[ ! "$tier" =~ ^(default|eco|reset)$ ]]; then
  echo "Usage: set-models.sh [default|eco|reset]" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "Error: jq is required" >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "Error: $CONFIG not found" >&2; exit 1; }

if [[ "$tier" != "reset" ]]; then
  [[ -f "$PROFILE" ]] || { echo "Error: $PROFILE not found" >&2; exit 1; }
  jq empty "$PROFILE" 2>/dev/null || { echo "Error: invalid profile JSON" >&2; exit 1; }
  jq -e --arg t "$tier" 'has($t)' "$PROFILE" >/dev/null 2>&1 \
    || { echo "Error: tier '$tier' not found in profile" >&2; exit 1; }
fi

tmp_file="${CONFIG}.tmp.$$"
trap 'rm -f "$tmp_file"' EXIT

cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S).$$" \
  || { echo "Error: failed to create backup" >&2; exit 1; }

state_value=""

if [[ "$tier" == "reset" ]]; then
  jq 'del(.model, .small_model, .agent.gandalf, .agent.aragorn, .agent.saruman, .agent.legolas, .agent.radagast, .agent.compaction)' \
    "$CONFIG" >"$tmp_file"
else
  jq --slurpfile profile "$PROFILE" --arg tier "$tier" '
    .model = $profile[0][$tier].model |
    .small_model = $profile[0][$tier].small_model |
    .agent.gandalf = $profile[0][$tier].agent.gandalf |
    .agent.aragorn = $profile[0][$tier].agent.aragorn |
    .agent.saruman = $profile[0][$tier].agent.saruman |
    .agent.legolas = $profile[0][$tier].agent.legolas |
    .agent.radagast = $profile[0][$tier].agent.radagast |
    .agent.compaction = $profile[0][$tier].agent.compaction
  ' "$CONFIG" >"$tmp_file"
  state_value="$tier"
fi

if ! [[ -s "$tmp_file" ]] || ! jq empty "$tmp_file" 2>/dev/null; then
  echo "Error: transform produced invalid JSON" >&2
  exit 1
fi

mv "$tmp_file" "$CONFIG"

if [[ -f "$STATE_FILE" ]]; then
  if grep -q '^export AI_BOOTSTRAP_CURATED_MODELS=' "$STATE_FILE"; then
    /usr/bin/sed -i '' "s/^export AI_BOOTSTRAP_CURATED_MODELS=.*/export AI_BOOTSTRAP_CURATED_MODELS='$state_value'/" "$STATE_FILE" || \
      echo "Warning: could not update state file" >&2
  else
    printf "export AI_BOOTSTRAP_CURATED_MODELS='%s'\n" "$state_value" >>"$STATE_FILE" || \
      echo "Warning: could not update state file" >&2
  fi
else
  echo "Warning: state file not found, skipping state update" >&2
fi

echo "✓ Model profile '${tier}' applied"
