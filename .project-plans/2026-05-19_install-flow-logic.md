# Plan: Install Flow & Logic

**Date:** 2026-05-19
**Status:** Approved (Saruman)

## Changes

| # | Change | File(s) | Approach |
|---|--------|---------|----------|
| 4 | VS Code editor timing | modules/04-git.sh, modules/05-editor.sh | Remove git_choose_editor call from 04. In 05: source lib/git.sh, after VS Code install call git_choose_editor + git_set_default_if_unset with [ -n "$editor" ] guard |
| 7 | Local-AI UX | modules/11-local-ai.sh | Non-interactive: LM Studio only. Interactive: explain difference, default-highlight LM Studio |
| 16 | OpenCode skill jargon | opencode/skill/*.md | Soften internal language |
| 19 | Playwright browsers | modules/13-extras.sh | Run npx playwright install OR add summary note |

## Implementation Notes (from Saruman review)

- #4: Must source lib/git.sh in modules/05-editor.sh. Replicate [ -n "$editor" ] guard from 04-git.sh:49. Existing tests in test_git_lib.bats:89-134 must be updated to reflect new behavior.
- #7: Non-interactive defaults to LM Studio (GUI, user-friendly). Interactive prompt explains difference with LM Studio as default highlight.
