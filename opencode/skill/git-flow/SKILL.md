---
name: git-flow
description: >-
  Atomic-commit discipline using Conventional Commits. Stages and commits
  meaningful units of work as the user completes them, never pushes without
  explicit confirmation, never runs destructive git operations without
  explicit confirmation. Use this skill when the user asks to "commit",
  "save my changes", "commit my work", "make a commit", or any request to
  record progress in git — and proactively when finishing a discrete unit
  of work during a longer task.
---

# Git Flow — Atomic Commits with Conventional Commits

You are operating in atomic-commit mode. The user wants their git history to be a clean, reversible record of meaningful units of work. Every commit is a checkpoint they can roll back to. You never make assumptions about what to push or destroy.

## Core principles

1. **One logical change per commit.** Don't batch unrelated edits.
2. **Conventional Commits format** for every message. Type, optional scope, subject.
3. **Never push to a remote without explicit confirmation** from the user.
4. **Never run destructive operations** (force-push, hard reset, branch deletion) without explicit confirmation.
5. **If the project isn't a git repo, initialize one first.** Don't refuse the request — make it work.
6. **The user's history is a safety net.** Commits should be small enough that reverting one is a low-cost action.

## Commit message format

```
<type>(<scope>): <subject>

<optional body — wrap at 72 chars>

<optional footer — issue refs, breaking changes>
```

### Types (use exactly one)

| Type | When to use |
|------|------------|
| `feat` | A new user-facing feature or behavior |
| `fix` | A bug fix |
| `docs` | Documentation only (README, comments, plan docs) |
| `style` | Formatting / whitespace / no logic change |
| `refactor` | Internal restructure, no behavior change, no fix |
| `test` | Tests only |
| `chore` | Tooling, deps, config, gitignore, editorconfig |
| `ci` | CI/CD pipelines and workflows |
| `perf` | Performance improvement |

### Scope (optional, lowercase, parenthesized)

A short noun pointing at the affected area: `feat(auth): ...`, `fix(api): ...`, `chore(deps): ...`. Use it when it helps reading; omit when the change is broad.

### Subject

- Imperative mood: "add", "fix", "remove" — not "added", "fixes".
- No trailing period.
- Lowercase first letter unless it's a proper noun.
- Under 72 characters total (type + scope + subject).

### Body (when needed)

Use a body when the *why* isn't obvious from the subject. Wrap at 72 columns. Skip the body for trivial commits (typo fixes, formatting passes, dependency bumps).

## Workflow

### When the user says "commit"

1. **Check repo state.**
   - If `git status` shows no changes: tell the user, stop.
   - If the directory is not a git repo: ask if they want to initialize one. On yes, run `git init`, stage, and commit with `chore: initial commit`.
2. **Inspect the diff.** Run `git status` and `git diff` (and `git diff --cached` if anything is already staged). Read what changed.
3. **Decide if it's one logical change or several.**
   - **One change:** stage everything relevant, draft a message, commit.
   - **Multiple changes:** explain what you see, propose a sequence of separate commits, get user approval, then commit them one at a time.
4. **Stage explicitly.** Prefer `git add <paths>` over `git add -A` when changes span multiple logical units. Never add files that look like secrets (`.env`, `credentials.json`, `*.pem`, anything matching common secret patterns) without warning the user.
5. **Commit with a Conventional Commits message.** Show the user the exact message you used.
6. **Verify.** Run `git status` to confirm a clean tree (or to show what remains for the next commit).

### When finishing a unit of work proactively

If you've just finished a self-contained piece of work during a longer task — a feature, a fix, a refactor — proactively offer to commit it before moving on. Don't wait to be asked. The user wants checkpoints.

### When the user says "push"

1. Confirm the remote and branch (`git remote -v`, current branch).
2. Show what will be pushed (`git log @{u}..HEAD --oneline` if upstream exists, otherwise the full local commit list).
3. Ask: "Push N commits from `<branch>` to `<remote>/<branch>`?" — wait for explicit yes.
4. On yes, run the push. On no, stop.
5. Never `--force` or `--force-with-lease` without the user explicitly using the word "force" or "overwrite".

### When you're asked to do something destructive

These commands all require explicit confirmation, regardless of how casually they're requested:

- `git push --force`, `git push --force-with-lease`
- `git reset --hard`
- `git branch -D` (force delete)
- `git clean -fd` (delete untracked files)
- `git rebase` (interactive or onto a commit before pushed history)
- `git checkout <path>` (discards uncommitted changes to that path)

Pattern: explain what it does, explain what will be lost, ask for confirmation. Do not execute on first request.

## Hard rules

### Always
- Use Conventional Commits format.
- Stage explicitly when there are multiple logical changes.
- Show the exact commit message before running `git commit`.
- Run `git status` after each commit to verify state.
- Warn before staging anything that looks like a secret.
- Initialize a git repo if one isn't present and the user wants to commit.

### Never
- Never push without explicit confirmation.
- Never run destructive operations without explicit confirmation.
- Never amend a commit that's been pushed unless the user explicitly asks.
- Never batch unrelated changes into one commit.
- Never use `git add -A` blindly when the diff spans multiple logical units.
- Never commit files that match common secret patterns without warning the user first.

## Output format

When committing, structure the response like this:

```
## Changes detected
<one-paragraph summary of what changed>

## Plan
<one commit, or list N commits with a one-line summary each>

## Commits made
1. <type>(<scope>): <subject>
   <files>

## State
<git status output, summarized>

## Next step
<what to do next, or "Working tree clean.">
```

Keep it tight. The user wants the agent to *do the work*, not narrate it.
