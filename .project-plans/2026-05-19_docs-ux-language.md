# Plan: Docs & UX Language

**Date:** 2026-05-19
**Status:** Approved (Saruman)

## Changes

| # | Change | File(s) | Approach |
|---|--------|---------|----------|
| 10 | README manual clone | README.md | Add mkdir -p ~/code |
| 11 | Error messages → actionable | lib/common.sh, lib/workspace.sh, modules/*.sh | Add "what to do next" |
| 12 | README jargon | README.md | Rephrase accessibly (jargon OK if explained) |
| 13 | Requirements placement | README.md | Move before Quick Start |
| 14 | Summary source command | lib/summary.sh | "Open new terminal" + "quit/reopen Just Vibes" primary; source as parenthetical |
| 15 | Workspace spaces warning | lib/workspace.sh | Upfront note in prompt |
| 17 | CONTRIBUTING stale refs | CONTRIBUTING.md | Remove PLAN.md/ANALYSIS_AND_PLAN.md references |
| 18 | Shell config stale warning | modules/10-shell-config.sh | Friendly message, suggest asking OpenCode |
| 25 | CONTRIBUTING quality gates | CONTRIBUTING.md | Add scripts/ and launcher/ |

## Implementation Notes (from Saruman review)

- #14: Also mention "quit and reopen Just Vibes" if launcher was installed in same run
