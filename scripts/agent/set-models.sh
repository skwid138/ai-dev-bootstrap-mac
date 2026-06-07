#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILE="$SCRIPT_DIR/../model-profiles.json"
CONFIG_DIR="$HOME/.config/opencode"
CONFIG="$CONFIG_DIR/opencode.jsonc"
LEGACY_CONFIG="$CONFIG_DIR/opencode.json"
STATE_FILE="$HOME/.config/ai-bootstrap/state.sh"

tier="${1:-default}"

if [[ ! "$tier" =~ ^(default|eco|reset)$ ]]; then
  echo "Usage: set-models.sh [default|eco|reset]" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required" >&2
  exit 1
}
READ_CONFIG=""
if [[ -f "$CONFIG" ]]; then
  READ_CONFIG="$CONFIG"
elif [[ -f "$LEGACY_CONFIG" ]]; then
  READ_CONFIG="$LEGACY_CONFIG"
else
  echo "Error: $CONFIG not found" >&2
  exit 1
fi

strip_jsonc() {
  perl -0pe 's{/\*.*?\*/}{}gs; s{(^|[^:"])//[^\n]*}{$1}g; s/,+(\s*[\]}])/$1/g' "$1"
}

if [[ "$tier" != "reset" ]]; then
  [[ -f "$PROFILE" ]] || {
    echo "Error: $PROFILE not found" >&2
    exit 1
  }
  jq empty "$PROFILE" 2>/dev/null || {
    echo "Error: invalid profile JSON" >&2
    exit 1
  }
  jq -e --arg t "$tier" 'has($t)' "$PROFILE" >/dev/null 2>&1 \
    || {
      echo "Error: tier '$tier' not found in profile" >&2
      exit 1
    }
fi

tmp_file="${CONFIG}.tmp.$$"
read_file="${CONFIG}.read.$$"
trap 'rm -f "$tmp_file" "${tmp_file}.2" "$read_file"' EXIT

strip_jsonc "$READ_CONFIG" >"$read_file" \
  || {
    echo "Error: failed to read OpenCode config" >&2
    exit 1
  }

state_value=""

if [[ "$tier" == "reset" ]]; then
  jq 'del(.model, .small_model, .agent.gandalf, .agent.aragorn, .agent.saruman, .agent.legolas, .agent.radagast, .agent.compaction)' \
    "$read_file" >"$tmp_file"

  # --- Council models reset (second pass) ---
  if [[ -s "$tmp_file" ]]; then
    if jq '
      if (.plugin // [] | any(type == "array" and .[0] == "@skwid138/opencode-council@0.10.0")) then
        .plugin |= map(
          if type == "array" and .[0] == "@skwid138/opencode-council@0.10.0" then
            [.[0], (.[1] | .council.models = [])]
          else . end
        )
      else . end
    ' "$tmp_file" >"${tmp_file}.2"; then
      mv "${tmp_file}.2" "$tmp_file"
    else
      : >"$tmp_file"
    fi
  fi
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
  ' "$read_file" >"$tmp_file"

  # --- Council models (second pass) ---
  if [[ -s "$tmp_file" ]]; then
    council_models="$(jq -c --arg tier "$tier" '.[$tier].council_models // []' "$PROFILE")"

    if jq --argjson council_models "$council_models" '
      if (.plugin // [] | any(type == "array" and .[0] == "@skwid138/opencode-council@0.10.0")) then
        .plugin |= map(
          if type == "array" and .[0] == "@skwid138/opencode-council@0.10.0" then
            [.[0], (.[1] | .council.models = $council_models)]
          else . end
        )
      else . end
    ' "$tmp_file" >"${tmp_file}.2"; then
      mv "${tmp_file}.2" "$tmp_file"
    else
      : >"$tmp_file"
    fi
  fi
  state_value="$tier"
fi

if ! [[ -s "$tmp_file" ]] || ! jq empty "$tmp_file" 2>/dev/null; then
  echo "Error: transform produced invalid JSON" >&2
  exit 1
fi

# Keep this inline: set-models.sh runs from the deployed scripts tree and
# cannot source repo-root lib/opencode.sh's opencode_backup_stale_configs.
backup_ts="$(date +%Y%m%d-%H%M%S).$$"
moved_backups=()
for live_config in "$LEGACY_CONFIG" "$CONFIG"; do
  if [[ -e "$live_config" ]]; then
    backup_config="$live_config.bak.$backup_ts"
    if ! mv "$live_config" "$backup_config"; then
      echo "Error: failed to create backup" >&2
      if [ "${#moved_backups[@]}" -gt 0 ]; then
        for moved_backup in "${moved_backups[@]}"; do
          [[ -e "$moved_backup" ]] || continue
          mv "$moved_backup" "${moved_backup%.bak."$backup_ts"}" 2>/dev/null || true
        done
      fi
      exit 1
    fi
    moved_backups+=("$backup_config")
  fi
done

mv "$tmp_file" "$CONFIG"

if [[ -f "$STATE_FILE" ]]; then
  if grep -q '^export AI_BOOTSTRAP_CURATED_MODELS=' "$STATE_FILE"; then
    /usr/bin/sed -i '' "s/^export AI_BOOTSTRAP_CURATED_MODELS=.*/export AI_BOOTSTRAP_CURATED_MODELS='$state_value'/" "$STATE_FILE" \
      || echo "Warning: could not update state file" >&2
  else
    printf "export AI_BOOTSTRAP_CURATED_MODELS='%s'\n" "$state_value" >>"$STATE_FILE" \
      || echo "Warning: could not update state file" >&2
  fi
else
  echo "Warning: state file not found, skipping state update" >&2
fi

echo "✓ Model profile '${tier}' applied"
