#!/bin/bash
# OpenCode-specific helpers, factored out of modules/09-opencode.sh
# so they can be unit-tested with bats and reused by a future doctor
# script (Phase F.5).
#
# Conventions:
# - Every function is pure: no side effects beyond the documented ones.
# - $1 is always either a path or a key the function operates on; never
#   a reference to a global. This keeps the bats tests trivial.
# - All paths the caller passes can be relative; we don't assume $HOME.
# - Output to stderr is for humans; stdout is for return values only,
#   so callers can capture results.

# ── opencode_deploy_assets ───────────────────────────────────────────────────
# Mirror the curated asset tree (agents, skills, commands, instructions,
# plugins) from the bootstrap repo into the user's ~/.config/opencode.
#
# Args:
#   $1: source dir (typically "$BOOTSTRAP_DIR/opencode")
#   $2: dest dir   (typically "$HOME/.config/opencode")
#
# Behavior:
# - Copies these subtrees: agent/, skill/, command/, instruction/, plugins/
# - Does NOT touch AGENTS.md (handled separately, see opencode_deploy_agents_md).
# - Does NOT touch opencode.json (handled separately, see opencode_render_config).
# - Overwrites destination files unconditionally — they're maintained by
#   the bootstrap, not the user. This matches the "asset" semantic: the
#   user's customizations belong in opencode.json or in their own
#   ~/.config/opencode/agent/<custom>.md files (we never delete files
#   that aren't ours).
# - Uses cp -R rather than rsync so we don't take a dependency on rsync
#   being installed; macOS ships with cp.
opencode_deploy_assets() {
  local src="$1"
  local dest="$2"

  if [ ! -d "$src" ]; then
    echo "opencode_deploy_assets: source dir not found: $src" >&2
    return 1
  fi

  mkdir -p "$dest"

  local new_manifest
  new_manifest=$(mktemp "${TMPDIR:-/tmp}/opencode-managed-files.XXXXXX")
  : >"$new_manifest"

  local subdir
  for subdir in agent skill command instruction plugins; do
    if [ -d "$src/$subdir" ]; then
      find "$src/$subdir" -type f -print | while IFS= read -r asset_file; do
        printf '%s\n' "${asset_file#"$src"/}" >>"$new_manifest"
      done
      mkdir -p "$dest/$subdir"
      # cp -R src/sub/. dest/sub/ — the trailing /. on the source ensures
      # contents are copied into dest/sub/, not nested as dest/sub/sub/.
      cp -R "$src/$subdir/." "$dest/$subdir/"
    fi
  done

  local top_file
  for top_file in package.json package-lock.json; do
    if [ -f "$src/$top_file" ]; then
      cp "$src/$top_file" "$dest/$top_file"
      printf '%s\n' "$top_file" >>"$new_manifest"
    fi
  done

  if [ -f "$dest/.managed-files" ]; then
    local old_entry
    while IFS= read -r old_entry || [ -n "$old_entry" ]; do
      [ -z "$old_entry" ] && continue
      case "$old_entry" in
        /* | *..*) continue ;;
      esac
      if ! grep -Fxq "$old_entry" "$new_manifest"; then
        rm -f "$dest/$old_entry"
      fi
    done <"$dest/.managed-files"
  fi

  sort "$new_manifest" >"$new_manifest.sorted"
  mv "$new_manifest.sorted" "$dest/.managed-files"
  rm -f "$new_manifest"
}

# ── opencode_deploy_scripts ──────────────────────────────────────────────────
# Copy bootstrap-managed helper scripts into the user's AI workspace so
# OpenCode commands can execute them through a stable $AI_BOOTSTRAP_WORKSPACE
# path.
#
# Args:
#   $1: source scripts dir (typically "$BOOTSTRAP_DIR/scripts")
#   $2: dest scripts dir   (typically "$AI_BOOTSTRAP_WORKSPACE/scripts")
#
# Returns:
#   0 on success
#   1 if the user declines an overwrite prompt or the source is invalid
opencode_deploy_scripts() {
  local src="$1"
  local dest="$2"

  if [ ! -d "$src" ]; then
    echo "opencode_deploy_scripts: source dir not found: $src" >&2
    return 1
  fi

  if [ -d "$dest" ] && [ "${BOOTSTRAP_NONINTERACTIVE:-}" != "1" ]; then
    local reply
    printf "Scripts directory already exists at %s. Overwrite? (y/n) No keeps your existing scripts and skips helper script updates. " "$dest" >&2
    if ! IFS= read -r reply; then
      echo "opencode_deploy_scripts: overwrite declined" >&2
      return 1
    fi

    case "$reply" in
      [Yy] | [Yy][Ee][Ss]) ;;
      *)
        echo "opencode_deploy_scripts: overwrite declined" >&2
        return 1
        ;;
    esac
  fi

  mkdir -p "$dest"
  cp -R "$src/." "$dest/"
}

# ── opencode_cleanup_scripts_assets ──────────────────────────────────────────
# Remove OpenCode assets whose specific helper scripts are absent from the
# deployed workspace scripts tree. This prevents commands from shipping when
# their backing helper cannot run, while preserving assets whose helpers are
# present from an earlier accepted script deployment.
#
# Args:
#   $1: opencode config dir (typically "$HOME/.config/opencode")
#   $2: deployed scripts dir (typically "$AI_BOOTSTRAP_WORKSPACE/scripts")
opencode_cleanup_scripts_assets() {
  local config_dir="$1"
  local scripts_dir="${2:-}"

  if [ -z "$config_dir" ]; then
    echo "opencode_cleanup_scripts_assets: config dir is required" >&2
    return 1
  fi

  opencode_cleanup_asset_if_helper_missing "$config_dir" "$scripts_dir" \
    "skill/check-updates" "agent/bootstrap-update-check.sh"
  opencode_cleanup_asset_if_helper_missing "$config_dir" "$scripts_dir" \
    "skill/set-models" "agent/set-models.sh"
  opencode_cleanup_asset_if_helper_missing "$config_dir" "$scripts_dir" \
    "skill/permission-audit" "agent/permission-audit.sh"
  opencode_cleanup_asset_if_helper_missing "$config_dir" "$scripts_dir" \
    "skill/dependency-update" "agent/opencode-deps-check.sh"
  opencode_cleanup_asset_if_helper_missing "$config_dir" "$scripts_dir" \
    "command/update-opencode-deps.md" "agent/opencode-deps-check.sh"
  opencode_cleanup_asset_if_helper_missing "$config_dir" "$scripts_dir" \
    "skill/check-my-site" "agent/chrome_mcp.sh"
  opencode_cleanup_asset_if_helper_missing "$config_dir" "$scripts_dir" \
    "command/check-my-site.md" "agent/chrome_mcp.sh"
}

opencode_cleanup_asset_if_helper_missing() {
  local config_dir="$1"
  local scripts_dir="$2"
  local asset_rel="$3"
  local helper_rel="$4"

  if [ -n "$scripts_dir" ] && [ -e "$scripts_dir/$helper_rel" ]; then
    return 0
  fi

  case "$asset_rel" in
    command/*.md) rm -f "$config_dir/$asset_rel" ;;
    skill/*) rm -rf "$config_dir/$asset_rel" ;;
  esac
}

# ── opencode_deploy_agents_md ────────────────────────────────────────────────
# Install ~/.config/opencode/AGENTS.md with overwrite protection.
#
# Per plan §0.5: this file contains the user's global agent rules. The
# bootstrap writes a sensible default on first install, but never
# overwrites existing user customizations on subsequent runs.
#
# Args:
#   $1: source AGENTS.md path
#   $2: dest   AGENTS.md path
#
# Returns: 0 if installed or skipped cleanly, 1 on error.
# Stdout: "installed", "skipped", or "" on error (machine-readable).
opencode_deploy_agents_md() {
  local src="$1"
  local dest="$2"

  if [ ! -f "$src" ]; then
    echo "opencode_deploy_agents_md: source file not found: $src" >&2
    return 1
  fi

  mkdir -p "$(dirname "$dest")"

  if [ -f "$dest" ]; then
    echo "skipped"
    return 0
  fi

  cp "$src" "$dest"
  echo "installed"
}

# ── opencode_deploy_if_missing ───────────────────────────────────────────────
# Install an OpenCode support config file with overwrite protection.
#
# Some OpenCode support files are templates that users may tune later, so this
# function installs them only when missing and preserves existing edits on
# re-bootstrap (same semantics as opencode_deploy_agents_md).
#
# Args:
#   $1: source template path
#   $2: dest   config path
#
# Returns: 0 if installed or skipped cleanly, 1 on error.
# Stdout: "installed", "skipped", or "" on error (machine-readable).
opencode_deploy_if_missing() {
  local src="$1"
  local dest="$2"

  if [ ! -f "$src" ]; then
    echo "opencode_deploy_if_missing: source file not found: $src" >&2
    return 1
  fi

  mkdir -p "$(dirname "$dest")"

  if [ -f "$dest" ]; then
    echo "skipped"
    return 0
  fi

  cp "$src" "$dest"
  echo "installed"
}

# ── opencode_deploy_tui_config ───────────────────────────────────────────────
# Install or merge OpenCode's TUI config, preserving user top-level settings and
# user plugin entries while keeping bootstrap-managed plugins current.
#
# Args:
#   $1: source tui.json template path
#   $2: dest   tui.json config   path
#
# Returns: 0 if installed or updated cleanly, non-zero on error.
# Stdout: "installed", "updated", or "" on error (machine-readable).
opencode_deploy_tui_config() (
  local src="$1"
  local dest="$2"
  local dest_dir tmp historical_json
  # If opencode/tui.json.template bumps @skwid138/opencode-tui past @1.1.1,
  # add the prior package spec here (for example, @skwid138/opencode-tui@1.1.1).
  # Otherwise the merge below can keep the old user-installed tuple and emit
  # duplicate managed TUI plugins alongside the new template tuple.
  local -a historical_managed_plugins=(
    "@skwid138/opencode-tui@1.1.0"
    "@skwid138/opencode-tui@1.0.0"
    "./plugins/home-prompt.tsx"
    "./plugins/justvibes-logo.tsx"
  )

  # Test-only injection extends the production historical list so edge cases can
  # be exercised without waiting for another real plugin rename/discontinuation.
  if [ "${OPENCODE_BOOTSTRAP_TEST:-0}" = "1" ] && [ -n "${OPENCODE_TEST_HISTORICAL_MANAGED_PLUGINS:-}" ]; then
    while IFS= read -r historical_plugin || [ -n "$historical_plugin" ]; do
      [ -z "$historical_plugin" ] && continue
      historical_managed_plugins+=("$historical_plugin")
    done <<<"$OPENCODE_TEST_HISTORICAL_MANAGED_PLUGINS"
  fi

  if [ ! -f "$src" ]; then
    echo "opencode_deploy_tui_config: template not found: $src" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "opencode_deploy_tui_config: jq is required but not installed" >&2
    return 1
  fi

  if ! jq -e 'type == "object" and (.plugin | type == "array")' "$src" >/dev/null 2>&1; then
    echo "opencode_deploy_tui_config: invalid template: $src" >&2
    return 1
  fi

  if [ "${#historical_managed_plugins[@]}" -gt 0 ]; then
    if ! historical_json=$(printf '%s\n' "${historical_managed_plugins[@]}" | jq -Rn '[inputs]'); then
      echo "opencode_deploy_tui_config: failed to encode historical plugin list" >&2
      return 1
    fi
  else
    historical_json='[]'
  fi

  dest_dir="$(dirname "$dest")"
  mkdir -p "$dest_dir"
  tmp=$(mktemp "$dest_dir/.tui.json.XXXXXX") || return 1
  trap 'rm -f "$tmp"' EXIT

  if [ ! -f "$dest" ]; then
    if ! cp "$src" "$tmp"; then
      echo "opencode_deploy_tui_config: failed to stage install: $dest" >&2
      return 1
    fi
    if ! mv "$tmp" "$dest"; then
      echo "opencode_deploy_tui_config: failed to install: $dest" >&2
      return 1
    fi
    trap - EXIT
    echo "installed"
    return 0
  fi

  if ! jq -e 'type == "object" and ((has("plugin") | not) or (.plugin | type == "array"))' "$dest" >/dev/null 2>&1; then
    if ! cp "$dest" "$dest.bak.$(date +%s)"; then
      echo "opencode_deploy_tui_config: failed to backup: $dest" >&2
      return 1
    fi
    if ! cp "$src" "$tmp"; then
      echo "opencode_deploy_tui_config: failed to stage install: $dest" >&2
      return 1
    fi
    if ! mv "$tmp" "$dest"; then
      echo "opencode_deploy_tui_config: failed to install: $dest" >&2
      return 1
    fi
    trap - EXIT
    echo "installed"
    return 0
  fi

  if ! cp "$dest" "$dest.bak.$(date +%s)"; then
    echo "opencode_deploy_tui_config: failed to backup: $dest" >&2
    return 1
  fi

  if ! jq --argjson historical "$historical_json" -s '
    .[0] as $template
    | .[1] as $existing
    | ($template.plugin | map(select(type == "array" and length > 0 and (.[0] | type == "string")))) as $template_plugins
    | ($template_plugins | map(.[0])) as $current_managed
    | (($current_managed + $historical) | unique) as $managed
    | ($existing.plugin // [] | map(select(
        type == "array"
        and length > 0
        and (.[0] | type == "string")
        and ((.[0] as $id | $managed | index($id)) | not)
      ))) as $user_plugins
    | $existing
    | .["$schema"] = $template["$schema"]
    | .plugin = ($template_plugins + $user_plugins)
  ' "$src" "$dest" >"$tmp"; then
    echo "opencode_deploy_tui_config: failed to merge: $dest" >&2
    return 1
  fi

  if ! mv "$tmp" "$dest"; then
    echo "opencode_deploy_tui_config: failed to update: $dest" >&2
    return 1
  fi

  trap - EXIT
  echo "updated"
)

# Backward-compatible wrapper for any out-of-tree callers that still use the
# old full-overwrite helper name.
opencode_deploy_with_backup() {
  opencode_deploy_tui_config "$@"
}

# ── opencode_render_config ───────────────────────────────────────────────────
# Render opencode.json from the template, optionally setting the model.
#
# Per plan §0.4: the model field is the single source of truth for the
# default model. The template ships with model: "" as a placeholder.
# - If a model id is provided, write it into the model field.
# - If no model id is provided (or empty), DELETE the model key entirely
#   so opencode falls back to its built-in default. This is the
#   "user skipped provider setup" path — opencode still launches, it
#   just won't have a usable model until the user runs /connect.
#
# Args:
#   $1: source template path  (e.g. opencode/opencode.json.template)
#   $2: dest   config   path  (e.g. ~/.config/opencode/opencode.json)
#   $3: model id (optional)   (e.g. "github-copilot/claude-sonnet-4.5")
#
# Behavior:
# - Always overwrites $2. opencode_render_config backs up an existing
#   file to $2.bak.<timestamp> first, but does not merge user
#   customizations because opencode.json is bootstrap-managed.
# - Requires jq (an Essential bootstrap package).
opencode_render_config() {
  local src="$1"
  local dest="$2"
  local model="${3:-}"

  if [ ! -f "$src" ]; then
    echo "opencode_render_config: template not found: $src" >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "opencode_render_config: jq is required but not installed" >&2
    return 1
  fi

  mkdir -p "$(dirname "$dest")"

  # Resolve workspace for permission rule substitution
  local workspace="${AI_BOOTSTRAP_WORKSPACE:-}"
  if [ -z "$workspace" ]; then
    local state_file="$HOME/.config/ai-bootstrap/state.sh"
    if [ -f "$state_file" ]; then
      workspace=$(. "$state_file" && printf '%s' "$AI_BOOTSTRAP_WORKSPACE")
    fi
  fi
  if [ -z "$workspace" ]; then
    workspace="$HOME/code"
  fi
  workspace="${workspace%/}"

  # Substitute bootstrap placeholders with resolved literal paths. opencode's
  # bash permission matcher does not expand shell variables at runtime.
  local rendered_src
  rendered_src=$(mktemp "${TMPDIR:-/tmp}/opencode-cfg.XXXXXX") || return 1

  local workspace_escaped config_dir config_dir_escaped
  workspace_escaped=$(printf '%s' "$workspace" | sed 's/[\\\/&]/\\&/g')
  config_dir="$(dirname "$dest")"
  config_dir_escaped=$(printf '%s' "$config_dir" | sed 's/[\\\/&]/\\&/g')
  sed \
    -e "s/\\\$AI_BOOTSTRAP_WORKSPACE/${workspace_escaped}/g" \
    -e "s/\\\$OPENCODE_CONFIG_DIR/${config_dir_escaped}/g" \
    "$src" >"$rendered_src" || {
    rm -f "$rendered_src"
    echo "opencode_render_config: sed substitution failed" >&2
    return 1
  }

  if [ -f "$dest" ]; then
    cp "$dest" "$dest.bak.$(date +%Y%m%d-%H%M%S)"
  fi

  local rc=0
  if [ -n "$model" ]; then
    # Set .model to the provided string.
    jq --arg m "$model" '.model = $m' "$rendered_src" >"$dest" || rc=$?
  else
    # Delete .model so opencode uses its built-in default.
    jq 'del(.model)' "$rendered_src" >"$dest" || rc=$?
  fi

  rm -f "$rendered_src"

  if [ $rc -ne 0 ]; then
    echo "opencode_render_config: jq failed processing template" >&2
    return 1
  fi
}

# ── opencode_has_github_auth ─────────────────────────────────────────────────
# True iff the GitHub CLI is installed AND authenticated. This is the
# signal we use to decide whether to default the provider question to
# GitHub Copilot.
#
# Side effects: none.
opencode_has_github_auth() {
  command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1
}

# ── opencode_login_copilot ───────────────────────────────────────────────────
# Drive `opencode auth login --provider github-copilot --method oauth`,
# which prints a github.com/login/device URL + 8-digit code and waits
# for the user to authorize in a browser.
#
# This is interactive but only at the user level (paste-URL-and-code);
# the shell side is fine to run synchronously.
#
# Returns: 0 on success, non-zero if the login subcommand fails or
# the user aborts.
opencode_login_copilot() {
  if ! command -v opencode >/dev/null 2>&1; then
    echo "opencode_login_copilot: opencode CLI not found" >&2
    return 1
  fi

  opencode auth login --provider github-copilot --method oauth
}

# ── opencode_decide_provider_path ────────────────────────────────────────────
# Pure decision function: given the user's GitHub-auth state and their
# menu choice, return (a) the opencode provider to log into and (b) the
# model id to write into opencode.json.
#
# This is the single point of policy for the provider flow. Splitting it
# out keeps modules/09-opencode.sh as a thin orchestrator and lets us
# test every branch with bats — no CLI shell-outs, no $HOME side effects.
#
# Args:
#   $1: gh_auth_state   — "yes" if `gh auth status` succeeded, else "no"
#   $2: menu_selection  — one of:
#                           "copilot"   (chosen because gh_auth=yes and user agreed)
#                           "anthropic" "openai" "gemini" "opencode" "skip"
#                         These are stable IDs the orchestrator emits after
#                         translating the human-readable ui_choose label.
#
# Stdout (two lines, in order):
#   1. provider id   ("github-copilot", "anthropic", "openai", "google",
#                     "opencode-go", or "none" for skip)
#   2. model id      e.g. "github-copilot/claude-sonnet-4.5", or empty
#                    string for skip
#
# Returns: 0 always for valid input; 2 for unrecognized selection (so
# the orchestrator can fall through cleanly rather than silently default).
#
# Note: the gh_auth_state arg is currently only consulted in test mode
# to guard against the "menu picked copilot but gh isn't authed" edge
# case. The orchestrator should not pass "copilot" if gh_auth_state is
# "no" — that's a bug. We surface it as exit 2 to make the contract
# explicit and the test easy to write.
opencode_decide_provider_path() {
  local gh_auth_state="$1"
  local menu_selection="$2"

  case "$menu_selection" in
    copilot)
      if [ "$gh_auth_state" != "yes" ]; then
        echo "opencode_decide_provider_path: 'copilot' chosen but gh not authed" >&2
        return 2
      fi
      printf '%s\n%s\n' "github-copilot" "github-copilot/claude-sonnet-4.5"
      ;;
    anthropic)
      printf '%s\n%s\n' "anthropic" "anthropic/claude-sonnet-4.5"
      ;;
    openai)
      printf '%s\n%s\n' "openai" "openai/gpt-5.2"
      ;;
    gemini)
      printf '%s\n%s\n' "google" "google/gemini-2.5-flash"
      ;;
    opencode)
      printf '%s\n%s\n' "opencode-go" "opencode-go/kimi-k2.6"
      ;;
    skip)
      printf '%s\n%s\n' "none" ""
      ;;
    *)
      echo "opencode_decide_provider_path: unknown selection: $menu_selection" >&2
      return 2
      ;;
  esac
}
