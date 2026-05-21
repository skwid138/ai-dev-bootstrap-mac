#!/bin/bash
# Argument parsing for bootstrap.sh.
#
# Seven flags supported:
#   --dry-run         Print the install plan and exit. Side-effect-free:
#                     no brew, no file writes, no module sourcing.
#   --non-interactive Skip all prompts. Falls back to defaults
#                     (--tier=recommended, workspace=~/code) with a loud
#                     log line so the user knows what was assumed. Useful
#                     for CI smoke tests and unattended re-runs.
#   --launcher-only   Rebuild ~/Applications/Just Vibes.app and exit.
#                     Skips preflight, Phase 0, tier selection, workspace
#                     prompt, and all installer modules. Useful for
#                     recovering from an accidentally-deleted launcher,
#                     iterating on launcher/launch.sh during dev, or
#                     manually testing the .app bundle without committing
#                     to a full bootstrap run. Implies --non-interactive
#                     (no prompts to ask). Composes with --dry-run
#                     ("would rebuild ~/Applications/Just Vibes.app").
#   --check-paths     Read-only staleness check on the baked Homebrew
#                     prefix in ~/.config/ai-bootstrap/shell/env/paths.zsh.
#                     Exits 0 (fresh) / 1 (stale) / 2 (error). Designed
#                     to be agent-pollable: the opencode agent on the
#                     user's machine runs this when it sees `command not
#                     found`, then runs --refresh-paths if exit code is 1.
#                     See plan §3.8 (rev-7).
#   --refresh-paths   Re-run modules/10-shell-config.sh only with a
#                     re-baked Homebrew prefix. Skips all other modules.
#                     ~1–2 seconds. Idempotent. Implies --non-interactive.
#                     Errors if state.sh is missing (no first install yet)
#                     or if AI_BOOTSTRAP_TIER='custom' (we can't
#                     reconstruct the custom package list from state.sh
#                     alone — re-run full bootstrap instead).
#   --list-modules    Print canonical module names, one per line, and exit.
#                     Implies --non-interactive.
#   --module <name>   Run only one named module. Standard modules require a
#                     previous standard-tier install; add-on modules can define
#                     their own prerequisites. Implies --non-interactive.
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
  ./bootstrap.sh --launcher-only    (Re)build ~/Applications/Just Vibes.app
                                    and exit. Useful if the launcher was
                                    deleted, or to test the .app bundle
                                    without a full bootstrap run.
  ./bootstrap.sh --check-paths      Check whether the Homebrew prefix baked
                                    into your shell config is still current.
                                    Read-only. Exits 0 (fresh), 1 (stale),
                                    or 2 (error). Useful when a CLI tool
                                    suddenly stops working after a brew or
                                    macOS upgrade.
  ./bootstrap.sh --refresh-paths    Re-bake the Homebrew prefix into your
                                    shell config (re-runs the shell-config
                                    module only). ~1-2 seconds. Run after
                                    --check-paths reports stale.
  ./bootstrap.sh --list-modules     Show module names that can be used with
                                    --module, one per line.
  ./bootstrap.sh --module <name>    Run one module by name from a previous
                                    standard-tier install. Use --list-modules
                                    to see available names; add-on modules
                                    such as tailscale can be run this way.
  ./bootstrap.sh --help             Show this help message

Flags can be combined. Examples:
  ./bootstrap.sh --dry-run --non-interactive
      Show what an unattended run would do.
  ./bootstrap.sh --launcher-only --dry-run
      Show what a launcher rebuild would do, without actually rebuilding.
  ./bootstrap.sh --refresh-paths --dry-run
      Show what a paths-refresh would do, without actually rewriting.

Sets up a Mac for vibe-coding with OpenCode. Safe to run multiple times.
https://github.com/skwid138/ai-dev-bootstrap-mac
EOF
}

# ── args_parse ────────────────────────────────────────────────────────────
# Parse argv. Sets these env vars (exports for module visibility):
#   BOOTSTRAP_DRY_RUN          ="1" if --dry-run was passed, else unset
#   BOOTSTRAP_NONINTERACTIVE   ="1" if --non-interactive (or env) set
#   BOOTSTRAP_LAUNCHER_ONLY    ="1" if --launcher-only was passed
#   BOOTSTRAP_CHECK_PATHS      ="1" if --check-paths was passed
#   BOOTSTRAP_REFRESH_PATHS    ="1" if --refresh-paths was passed
#   BOOTSTRAP_LIST_MODULES     ="1" if --list-modules was passed
#   BOOTSTRAP_MODULE_ONLY      = module name if --module <name> was passed
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
      --launcher-only)
        export BOOTSTRAP_LAUNCHER_ONLY=1
        # Implies non-interactive — there's nothing to prompt for in
        # this mode. The launcher always reads workspace from the
        # existing state.sh (or falls back to ~/code).
        export BOOTSTRAP_NONINTERACTIVE=1
        export AI_BOOTSTRAP_NONINTERACTIVE=1
        shift
        ;;
      --check-paths)
        export BOOTSTRAP_CHECK_PATHS=1
        # Implies non-interactive — read-only check; nothing to prompt.
        export BOOTSTRAP_NONINTERACTIVE=1
        export AI_BOOTSTRAP_NONINTERACTIVE=1
        shift
        ;;
      --refresh-paths)
        export BOOTSTRAP_REFRESH_PATHS=1
        # Implies non-interactive — refresh re-runs module 10 with the
        # tier already persisted in state.sh; nothing to prompt for.
        export BOOTSTRAP_NONINTERACTIVE=1
        export AI_BOOTSTRAP_NONINTERACTIVE=1
        shift
        ;;
      --list-modules)
        export BOOTSTRAP_LIST_MODULES=1
        # Implies non-interactive — list is read-only; nothing to prompt.
        export BOOTSTRAP_NONINTERACTIVE=1
        export AI_BOOTSTRAP_NONINTERACTIVE=1
        shift
        ;;
      --module)
        if [ $# -lt 2 ]; then
          echo "error: --module requires a module name argument" >&2
          echo "  Run with --list-modules to see available names." >&2
          return 2
        fi
        export BOOTSTRAP_MODULE_ONLY="$2"
        # Implies non-interactive — module-only mode reads existing state.
        export BOOTSTRAP_NONINTERACTIVE=1
        export AI_BOOTSTRAP_NONINTERACTIVE=1
        shift 2
        ;;
      *)
        echo "Unknown flag: $1" >&2
        return 2
        ;;
    esac
  done

  return 0
}
