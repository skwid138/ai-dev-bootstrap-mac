#!/bin/bash
# Workspace anchor: where the user keeps their code projects.
#
# A non-techy user shouldn't need to think about "where do my projects
# live?" — but the bootstrap, the .app launcher (Phase E), the cdc
# alias, and ghostty's working-directory option all need a concrete
# answer. This module owns that answer.
#
# Storage: a sourceable shell file at ~/.config/ai-bootstrap/state.sh
# holding key=value vars (AI_BOOTSTRAP_WORKSPACE, etc.). Chosen over
# JSON because:
#   1. No jq dependency for reads — plain `source` works in any shell.
#   2. Aliases that use the value (like cdc) can `source` and reference
#      $AI_BOOTSTRAP_WORKSPACE directly, which means moving the
#      workspace just requires re-running bootstrap (or hand-editing
#      state.sh) — the alias adapts automatically.
#   3. Future modules can read it with one line. JSON would force every
#      consumer through jq.
#
# Trade-off: state.sh is executed (sourced), not parsed. If a future
# value contains user-controlled text we have to quote it carefully. We
# control all writes today; if that ever changes, switch to JSON.

# ── workspace_default_path ──────────────────────────────────────────────────
# Returns the default workspace path for the current user. Pure — no
# filesystem side effects, no env reads beyond $HOME. Exists so tests
# can pin behavior without sandboxing.
workspace_default_path() {
  echo "$HOME/code"
}

# ── workspace_expand_path ───────────────────────────────────────────────────
# Expand a user-supplied path. Two cases:
#   "~/foo"      -> "$HOME/foo"
#   "~"          -> "$HOME"
#   anything else -> echoed back unchanged (relative paths stay relative;
#                     the caller decides whether to make them absolute)
#
# We deliberately do NOT use `eval` for tilde expansion — it would let
# a malicious input run arbitrary shell. This is a string operation
# only.
#
# The case patterns use \~ (escaped tilde) to make our intent explicit
# to shellcheck: we want the literal '~' character in the pattern, not
# tilde expansion at parse time.
workspace_expand_path() {
  local input="$1"
  case "$input" in
    \~) echo "$HOME" ;;
    \~/*)
      # Strip the leading "~/" (2 chars) and prepend $HOME.
      echo "$HOME/${input:2}"
      ;;
    *) echo "$input" ;;
  esac
}

# ── workspace_validate_path ─────────────────────────────────────────────────
# Validate a workspace path. Returns 0 if usable, non-zero otherwise.
# Prints a human-readable error to stderr on failure.
#
# Rules (deliberately minimal):
#   - Must be an absolute path (so the .app launcher and ghostty can
#     reference it without ambiguity).
#   - Must not contain spaces (lots of CLI tools, including some bash
#     constructs we use, get tripped up by spaces — and a non-techy
#     user choosing "My Projects" would find their tooling subtly
#     broken later).
#   - Must not be / or $HOME itself (writing a `.app-bootstrap-state`
#     marker into / or stomping random $HOME contents is unfriendly).
workspace_validate_path() {
  local path="$1"

  if [ -z "$path" ]; then
    echo "workspace path cannot be empty" >&2
    return 1
  fi

  case "$path" in
    /*) ;;
    *)
      echo "workspace path must be absolute (got: $path)" >&2
      return 1
      ;;
  esac

  case "$path" in
    *" "*)
      echo "workspace path cannot contain spaces (got: $path)" >&2
      return 1
      ;;
  esac

  case "$path" in
    *"'"*)
      echo "Folder names with apostrophes (') are not supported yet. Please choose a path without them, like ~/code" >&2
      return 1
      ;;
  esac

  if [ "$path" = "/" ] || [ "$path" = "$HOME" ]; then
    echo "workspace cannot be / or your home directory directly (got: $path)" >&2
    return 1
  fi

  return 0
}

# ── workspace_ensure_dir ────────────────────────────────────────────────────
# Create the workspace directory if it doesn't already exist. Idempotent.
# Returns 0 on success, 1 if creation failed.
workspace_ensure_dir() {
  local path="$1"

  if [ -d "$path" ]; then
    return 0
  fi

  if mkdir -p "$path"; then
    return 0
  fi

  echo "workspace_ensure_dir: failed to create $path" >&2
  return 1
}

# ── workspace_write_state ───────────────────────────────────────────────────
# Render ~/.config/ai-bootstrap/state.sh with the given workspace path.
# Overwrites the file every time (it's bootstrap-managed; user edits to
# state.sh will be lost on re-run — this is documented in a header
# comment we write at the top).
#
# We single-quote the value when writing so future shells that source
# the file don't try to expand metacharacters in path components.
# Validation already excluded spaces and special chars upstream.
#
# Args:
#   $1: state_file  — absolute path to write (typically
#                     ~/.config/ai-bootstrap/state.sh)
#   $2: workspace   — absolute, validated workspace path
workspace_write_state() {
  local state_file="$1"
  local workspace="$2"

  local state_dir
  state_dir=$(dirname "$state_file")
  if ! mkdir -p "$state_dir"; then
    echo "workspace_write_state: failed to create $state_dir" >&2
    return 1
  fi

  local tmp_file="${state_file}.tmp.$$"
  if ! cat >"$tmp_file" <<EOF; then
#!/bin/bash
# Generated by ai-dev-bootstrap-mac. Edit at your own risk —
# this file is overwritten on every bootstrap run.
#
# Sourced by ~/.config/ai-bootstrap/shell/aliases.sh and read by
# other bootstrap modules to locate user assets.

export AI_BOOTSTRAP_WORKSPACE='$workspace'
EOF
    rm -f "$tmp_file"
    echo "workspace_write_state: failed to write $tmp_file" >&2
    return 1
  fi

  if ! mv "$tmp_file" "$state_file"; then
    rm -f "$tmp_file"
    echo "workspace_write_state: failed to replace $state_file" >&2
    return 1
  fi
}

# ── workspace_read_state ────────────────────────────────────────────────────
# Read AI_BOOTSTRAP_WORKSPACE from a state file (without polluting the
# caller's env beyond what's needed). Echoes the value, exits 0 on
# success, exits 1 if the file doesn't exist or doesn't define the var.
#
# Used by tests and could be used by future modules. The bootstrap
# itself has the value in scope already so doesn't need to call this.
workspace_read_state() {
  local state_file="$1"

  if [ ! -f "$state_file" ]; then
    return 1
  fi

  # Run the source in a subshell so we don't leak vars to the caller.
  local value
  value=$(
    # shellcheck disable=SC1090
    source "$state_file" 2>/dev/null
    echo "${AI_BOOTSTRAP_WORKSPACE:-}"
  )

  if [ -z "$value" ]; then
    return 1
  fi

  echo "$value"
  return 0
}
