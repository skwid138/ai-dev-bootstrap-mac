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

  local subdir
  for subdir in agent skill command instruction plugins; do
    if [ -d "$src/$subdir" ]; then
      mkdir -p "$dest/$subdir"
      # cp -R src/sub/. dest/sub/ — the trailing /. on the source ensures
      # contents are copied into dest/sub/, not nested as dest/sub/sub/.
      cp -R "$src/$subdir/." "$dest/$subdir/"
    fi
  done
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
