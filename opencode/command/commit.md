---
description: >-
  Save your work as a git commit. Reviews what's changed, decides whether
  it's one or multiple logical units, drafts a Conventional Commits
  message, and commits. Never pushes to a remote without confirmation.
  Never runs destructive operations.
---
Ask Aragorn to record the user's current changes as one or more atomic git commits using the global git workflow rules from AGENTS.md. Do not perform git write operations in the current agent; delegate the work to Aragorn and have Aragorn report the result.

## Default behavior for Aragorn

1. Check repo state. If the directory is not a git repository, ask the user if they want to initialize one. On yes, run `git init`, stage everything, and commit with `chore: initial commit`.

2. If there are no changes (`git status` is clean), tell the user and stop.

3. Inspect the diff:
   ```
   git status
   git diff
   git diff --cached    # if anything is already staged
   ```

4. Decide whether the changes form one logical unit or several:
   - **One unit:** stage what's relevant, draft a Conventional Commits message, show it to the user, then commit.
   - **Multiple units:** explain what you see, propose a sequence of separate commits with their messages, ask for approval, then commit them one at a time.

5. After committing, run `git status` and report state. If the working tree is clean, say so. If anything remains uncommitted, list what.

## Hard rules (from the global AGENTS.md)

- **Conventional Commits format** for every message: `<type>(<scope>): <subject>`. Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`.
- **Never push to a remote** unless the user explicitly asks.
- **Never run destructive operations** (force-push, hard reset, branch -D, clean, rebase, checkout-as-discard) without explicit confirmation.
- **Warn before staging files that look like secrets** (`.env`, `credentials.json`, `*.pem`, etc.).

## Optional argument

If the user passes a message after `/commit`, treat it as a *hint* about what they consider the unit of work — not a verbatim commit message. Use it to inform Aragorn's Conventional Commits draft. Aragorn always controls the final formatting.

Example: `/commit add login button` → Aragorn might commit as `feat(auth): add login button`.

## When to push back

If the changes Aragorn sees are clearly multiple unrelated things (e.g., a bug fix in one file plus a refactor in another plus a docs update), don't squash them into one commit just because it's faster. Aragorn should propose the split, get approval, then commit them separately. The user's history is more valuable than the saved keystrokes.
