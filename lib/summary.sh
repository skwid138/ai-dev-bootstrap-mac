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
  echo "    1. Open a new terminal window (or run: source ~/.zshenv ~/.zprofile ~/.zshrc)"
  echo "    2. Try running: opencode"
  echo "    3. Start building something! 🎉"
  echo ""

  return 0
}
