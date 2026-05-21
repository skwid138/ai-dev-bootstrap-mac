#!/bin/bash
# Breadcrumb helpers for add-on modules that need to resume after a full
# Bootstrap run.

breadcrumb_config_dir() {
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    echo "$XDG_CONFIG_HOME/ai-bootstrap"
  else
    echo "$HOME/.config/ai-bootstrap"
  fi
}

breadcrumb_dir() {
  echo "$(breadcrumb_config_dir)/breadcrumbs"
}

breadcrumb_path() {
  local module_name="$1"
  echo "$(breadcrumb_dir)/$module_name"
}

breadcrumb_write() {
  local module_name="$1"
  local dir
  dir=$(breadcrumb_dir)

  mkdir -p "$dir" || return 1
  : >"$(breadcrumb_path "$module_name")"
}

breadcrumb_exists() {
  local module_name="$1"
  [ -f "$(breadcrumb_path "$module_name")" ]
}

breadcrumb_clear() {
  local module_name="$1"
  rm -f "$(breadcrumb_path "$module_name")"
}

breadcrumb_pending() {
  local dir
  dir=$(breadcrumb_dir)

  [ -d "$dir" ] || return 1

  local found=0
  local breadcrumb
  for breadcrumb in "$dir"/*; do
    [ -f "$breadcrumb" ] || continue
    basename "$breadcrumb"
    found=1
  done

  [ "$found" -eq 1 ]
}
