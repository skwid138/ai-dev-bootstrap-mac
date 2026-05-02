# path_helpers.zsh — PATH manipulation helpers
#
# Sourced by env-tier (init_env.zsh) before any path manipulation.
#
# Contract:
#   - MUST be silent on stdout AND stderr.
#   - MUST be nounset-safe (callable from set -u contexts).
#   - MUST NOT depend on tools beyond zsh builtins.
#   - Re-sourcing MUST be safe and a no-op for observable behavior; the function
#     is always (re)defined so init_profile.zsh can re-source the env-tier
#     barrel for path_helper recovery without losing _path_prepend.

# _path_prepend <dir>
#
# Idempotent PATH-front insertion with promotion semantics:
#   - Missing dir on disk           → silent no-op (do not add non-existent paths).
#   - Already at front of PATH      → no-op.
#   - Present but not at front      → promoted to front (rebuilds PATH minus the
#                                     existing entry, then prepends).
#   - Absent from PATH              → prepended.
#
# Promotion semantics are required to recover from macOS's path_helper, which
# rebuilds PATH between .zshenv and .zprofile and demotes /opt/homebrew/bin
# below /usr/bin. Without promotion, _path_prepend would see the dir as
# "already present" and skip — leaving PATH demoted. See §3.6 of the plan.
_path_prepend() {
  local dir="${1:-}"
  [[ -z "$dir" ]] && return 0
  [[ -d "$dir" ]] || return 0

  # Already at front? No-op.
  case ":${PATH:-}:" in
    "${dir}":*) return 0 ;;
  esac

  # Present but not at front? Strip the existing entry, then prepend.
  case ":${PATH:-}:" in
    *":${dir}:"*)
      # Remove all occurrences of :dir: from PATH (handles both middle and end positions).
      local stripped=":${PATH}:"
      stripped="${stripped//:${dir}:/:}"
      # Trim leading/trailing colons left by substitution.
      stripped="${stripped#:}"
      stripped="${stripped%:}"
      export PATH="${dir}:${stripped}"
      return 0
      ;;
  esac

  # Absent: prepend.
  export PATH="${dir}:${PATH:-}"
}

# Sentinel set AFTER function definition so re-source always (re)defines
# _path_prepend. The sentinel exists as a load marker for diagnostics, not
# as a guard — re-sourcing is intentionally idempotent and cheap.
_AI_BOOTSTRAP_PATH_HELPERS_LOADED=1
