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
# - Copies these subtrees: agent/, skill/, command/, instruction/
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

  local subdir
  for subdir in agent skill command instruction; do
    if [ -d "$src/$subdir" ]; then
      mkdir -p "$dest/$subdir"
      # cp -R src/sub/. dest/sub/ — the trailing /. on the source ensures
      # contents are copied into dest/sub/, not nested as dest/sub/sub/.
      cp -R "$src/$subdir/." "$dest/$subdir/"
    fi
  done
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
# Remove OpenCode assets that depend on scripts deployment. This prevents a
# broken /update-opencode-deps command from being installed when the user
# declines copying scripts into $AI_BOOTSTRAP_WORKSPACE.
#
# Args:
#   $1: opencode config dir (typically "$HOME/.config/opencode")
opencode_cleanup_scripts_assets() {
  local config_dir="$1"

  if [ -z "$config_dir" ]; then
    echo "opencode_cleanup_scripts_assets: config dir is required" >&2
    return 1
  fi

  rm -rf "$config_dir/skill/dependency-update"
  rm -f "$config_dir/command/update-opencode-deps.md"
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

# ── opencode_deploy_dcp_config ───────────────────────────────────────────────
# Install ~/.config/opencode/dcp.jsonc with overwrite protection.
#
# dcp (the dynamic-context-pruning plugin loaded via opencode.json's
# `plugin` array) reads its config from a sibling file, NOT from
# opencode.json. The user may tune `compress.maxContextLimit` to taste,
# so this function preserves their edits on re-bootstrap (same semantics
# as opencode_deploy_agents_md).
#
# Args:
#   $1: source dcp.jsonc.template path
#   $2: dest   dcp.jsonc path
#
# Returns: 0 if installed or skipped cleanly, 1 on error.
# Stdout: "installed", "skipped", or "" on error (machine-readable).
opencode_deploy_dcp_config() {
  local src="$1"
  local dest="$2"

  if [ ! -f "$src" ]; then
    echo "opencode_deploy_dcp_config: source file not found: $src" >&2
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
# - Always overwrites $2. The user's customizations to opencode.json
#   are NOT preserved — that file is bootstrap-managed. (This is a
#   known tradeoff; if it ever bites a user, we'll add a backup-on-
#   overwrite step.)
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

  if [ -f "$dest" ]; then
    cp "$dest" "$dest.bak.$(date +%Y%m%d-%H%M%S)"
  fi

  if [ -n "$model" ]; then
    # Set .model to the provided string.
    jq --arg m "$model" '.model = $m' "$src" >"$dest"
  else
    # Delete .model so opencode uses its built-in default.
    jq 'del(.model)' "$src" >"$dest"
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
#                           "anthropic" "openai" "gemini" "zen" "skip"
#                         These are stable IDs the orchestrator emits after
#                         translating the human-readable ui_choose label.
#
# Stdout (two lines, in order):
#   1. provider id   ("github-copilot", "anthropic", "openai", "google",
#                     "opencode-zen", or "none" for skip)
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
    zen)
      printf '%s\n%s\n' "opencode-zen" "opencode/claude-sonnet-4.6"
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
