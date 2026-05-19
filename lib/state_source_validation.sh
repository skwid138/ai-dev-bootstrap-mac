#!/bin/bash
# Shared guard for shell-sourceable ai-bootstrap state files.

state_validate_sourceable_file() {
  local state_file="$1"

  if [ ! -f "$state_file" ]; then
    return 1
  fi

  local line line_no=0
  while IFS= read -r line || [ -n "$line" ]; do
    line_no=$((line_no + 1))

    if [[ "$line" =~ ^[[:space:]]*$ ]]; then
      continue
    fi
    if [[ "$line" =~ ^#!.*$ ]]; then
      continue
    fi
    if [[ "$line" =~ ^[[:space:]]*#.*$ ]]; then
      continue
    fi
    if [[ "$line" =~ ^export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*\=\'[^\']*\'$ ]]; then
      continue
    fi

    echo "warning: unsafe state file $state_file:$line_no: $line" >&2
    return 1
  done <"$state_file"

  return 0
}
