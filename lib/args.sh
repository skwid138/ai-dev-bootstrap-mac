#!/bin/bash
# Argument parsing for bootstrap.sh.
#
# Two flags supported:
#   --dry-run         Print the install plan and exit. Side-effect-free:
#                     no brew, no file writes, no module sourcing.
#   --non-interactive Skip all prompts. Falls back to defaults
#                     (--tier=recommended, workspace=~/code) with a loud
#                     log line so the user knows what was assumed. Useful
#                     for CI smoke tests and unattended re-runs.
#
# Both can be combined: `--dry-run --non-interactive` prints what a
# non-interactive run *would* do.
#
# Why a dedicated arg-parse module:
#
#   bootstrap.sh used to do `if [[ "${1:-}" == "--help" ]]` inline. Adding
#   two more flags makes that O(n²) ugly fast, and we want the arg-parse
#   logic itself to be unit-testable. So: a single parse function that
#   exports flags as env vars (BOOTSTRAP_DRY_RUN, BOOTSTRAP_NONINTERACTIVE)
#   and lets bootstrap.sh handle the actions.
#
# Compatibility note: the existing AI_BOOTSTRAP_NONINTERACTIVE env var is
# preserved as an alias for --non-interactive (it was already partially
# wired in bootstrap.sh's workspace prompt). Setting either turns
# non-interactive mode on.

# ── args_print_help ───────────────────────────────────────────────────────
args_print_help() {
  cat <<'EOF'
AI Dev Bootstrap for Mac

Usage:
  ./bootstrap.sh                    Run the interactive installer
  ./bootstrap.sh --dry-run          Show the install plan and exit (safe)
  ./bootstrap.sh --non-interactive  Run with defaults, skip all prompts
  ./bootstrap.sh --help             Show this help message

Flags can be combined. Examples:
  ./bootstrap.sh --dry-run --non-interactive
      Show what an unattended run would do.

Sets up a Mac for vibe-coding with OpenCode. Safe to run multiple times.
https://github.com/skwid138/ai-dev-bootstrap-mac
EOF
}

# ── args_parse ────────────────────────────────────────────────────────────
# Parse argv. Sets these env vars (exports for module visibility):
#   BOOTSTRAP_DRY_RUN          ="1" if --dry-run was passed, else unset
#   BOOTSTRAP_NONINTERACTIVE   ="1" if --non-interactive (or env) set
#
# Honors AI_BOOTSTRAP_NONINTERACTIVE env as alias for --non-interactive
# (preserves backward compat with the early workspace-prompt wiring).
#
# Returns 0 on success.
# Returns 1 if --help was passed (caller should exit 0 after printing).
# Returns 2 on unknown flag (caller should exit 2 after printing usage).
args_parse() {
  # Honor pre-existing env var.
  if [ -n "${AI_BOOTSTRAP_NONINTERACTIVE:-}" ]; then
    export BOOTSTRAP_NONINTERACTIVE=1
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --help | -h)
        return 1
        ;;
      --dry-run)
        export BOOTSTRAP_DRY_RUN=1
        # Dry-run implies non-interactive: we can't show a plan if we're
        # going to prompt the user mid-way through. Setting both keeps
        # the control flow simple — `if dry-run, skip Phase 0` and
        # `if non-interactive, use defaults` compose cleanly.
        export BOOTSTRAP_NONINTERACTIVE=1
        export AI_BOOTSTRAP_NONINTERACTIVE=1
        shift
        ;;
      --non-interactive)
        export BOOTSTRAP_NONINTERACTIVE=1
        # Also set the legacy var so any code paths still checking it
        # see the same state.
        export AI_BOOTSTRAP_NONINTERACTIVE=1
        shift
        ;;
      *)
        echo "Unknown flag: $1" >&2
        return 2
        ;;
    esac
  done

  return 0
}
