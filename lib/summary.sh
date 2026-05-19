#!/bin/bash
# Final install summary renderer.
#
# Keep this deliberately plain: no gum styling and no interactive behavior, so
# bootstrap can print it in --non-interactive environments after a successful
# install run.

# ── summary_print ───────────────────────────────────────────────────────────
# Args:
#   $1: workspace — configured workspace path
#   $2: tier      — selected install tier
#   $3: brewfile  — generated Brewfile path
#   $4: launcher  — generated Just Vibes.app path
#
# Writes a human-readable summary + next steps to stdout. Returns 0.
summary_print() {
  local workspace="${1:-}"
  local tier="${2:-}"
  local brewfile="${3:-}"
  local launcher="${4:-}"

  echo ""
  echo "========================================"
  echo "  📋 Installation Summary"
  echo "========================================"
  echo ""
  echo "  Generated/configured:"
  echo "    Workspace: ${workspace:-"(not generated)"}"
  echo "    Tier:      ${tier:-"(not generated)"}"
  echo "    Brewfile:  ${brewfile:-"(not generated)"}"
  echo "    Launcher:  ${launcher:-"(not generated)"}"
  echo ""
  echo "  Next steps:"
  echo "    1. Quit and reopen Just Vibes, or open a new terminal window."
  echo "    2. Try running: opencode"
  echo "    3. Start building something! 🎉"
  echo "       (If you must keep this terminal open, run: source ~/.zshenv ~/.zprofile ~/.zshrc)"
  echo ""

  return 0
}

# ── summary_print_failure ───────────────────────────────────────────────────
# Args:
#   $1: workspace — configured workspace path
#   $2: tier      — selected install tier
#   $3: brewfile  — generated Brewfile path
#   $4: launcher  — generated Just Vibes.app path
#   $@: failures  — friendly names for failed modules/tools
#
# Writes a failure-oriented summary + recovery steps to stdout. Returns 0;
# callers decide the process exit code.
summary_print_failure() {
  local workspace="${1:-}"
  local tier="${2:-}"
  local brewfile="${3:-}"
  local launcher="${4:-}"
  shift 4 || true

  echo ""
  echo "========================================"
  echo "  ⚠️  Installation finished with issues"
  echo "========================================"
  echo ""
  echo "  Generated/configured:"
  echo "    Workspace: ${workspace:-"(not generated)"}"
  echo "    Tier:      ${tier:-"(not generated)"}"
  echo "    Brewfile:  ${brewfile:-"(not generated)"}"
  echo "    Launcher:  ${launcher:-"(not generated)"}"
  echo ""
  echo "  Could not finish:"

  local failure
  for failure in "$@"; do
    echo "    - $failure"
  done

  echo ""
  echo "  What to do next:"
  echo "    1. Check the error messages above."
  echo "    2. Run this installer again after fixing the problem."
  echo ""

  return 0
}
