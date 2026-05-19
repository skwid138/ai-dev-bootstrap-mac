# Plan: Shell Safety & Reliability

**Date:** 2026-05-19
**Status:** Approved (Saruman)

## Changes

| # | Change | File(s) | Approach |
|---|--------|---------|----------|
| 1 | Xcode CLT timeout | modules/00-xcode-clt.sh | 15-min timeout + "Look for popup" message |
| 2 | Homebrew curl failure | modules/01-homebrew.sh | Download to temp file with checked curl, then execute |
| 3 | set -e module isolation | bootstrap.sh | Phase 0 (00-02) FATAL. Phase 1+ wrapped: failures recorded, don't abort. Summary shows pass/fail. |
| 5 | opencode.json backup | lib/opencode.sh | cp to opencode.json.bak.$(date +%Y%m%d-%H%M%S) before overwrite |
| 6 | Atomic state writes | lib/state.sh, lib/workspace.sh | Write to .tmp, then mv |
| 8 | Scripts overwrite prompt | modules/09-opencode.sh | Explain what "no" means; don't remove assets on decline |
| 20 | State file sourcing safety | lib/state.sh, launcher/launch-helper.sh | Shared validation function: allow shebang, comments, blanks, export KEY='value'. Reject+warn otherwise. |
| 21 | --help exit code | bootstrap.sh | Fix to args_parse "$@"; rc=$? pattern |
| 22 | Single-quote in workspace path | lib/workspace.sh | Reject single quotes in validation |
| 23 | Stale OpenCode assets | lib/opencode.sh | Manifest at ~/.config/opencode/.managed-files. Delete old-not-in-new. No manifest = skip cleanup, write manifest. |
| 24 | Deploy package.json | lib/opencode.sh | Copy package.json + package-lock.json if present |

## Implementation Notes (from Saruman review)

- #3: Phase 0 (00-02) stays fatal; only Phase 1+ gets failure isolation
- #20: Shared validation function called by both lib/state.sh and launcher/launch-helper.sh. Whitelist: shebang, comments, blanks, `export KEY='value'` (values may contain spaces, slashes, colons, dots).
- #23: No manifest on first run = skip cleanup, just write manifest
- #9 (launcher atomicity): DROPPED — already atomic enough via mktemp staging
