#!/bin/bash
# Bash installer.
# This module is sourced by bootstrap.sh (not executed standalone).
#
# Why this exists: macOS ships bash 3.2 (GPLv2-era; never updated since
# 2007). Modern shell tutorials, AI-tutor sessions, and OSS install
# scripts assume bash 5.x features — associative arrays, ${var,,} case
# munging, etc. Without this module, after bootstrap completes the
# user's `command -v bash` still points at /bin/bash 3.2 even though
# PATH has /opt/homebrew/bin first, because Homebrew bash was never
# installed. See zsh_init_plan.md Phase 7.5.
#
# Why a dedicated module instead of folding into 08-cli-tools.sh:
# placement matters. bash is foundational — like gum (module 02), it
# should be available before any tier-conditional module runs so
# downstream tooling that wants bash 5+ on PATH has it. 08-cli-tools
# runs late (after runtime, python, opencode).
#
# This module runs via bootstrap.sh's run_module_if_selected dispatch
# (gated on the "bash" package key being in SELECTED_PACKAGES). The
# package is registered tier=essential in config/packages.sh, so it
# applies to essential / recommended / complete; only a custom-tier
# user explicitly deselecting bash would skip this module.

install_brew_formula "bash"
