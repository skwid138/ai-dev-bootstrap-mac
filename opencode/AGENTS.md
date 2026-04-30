# Global Agent Guidelines

These rules apply to every project worked on from this machine. They were installed by `ai-dev-bootstrap-mac`. You can edit or remove this file at any time — it lives at `~/.config/opencode/AGENTS.md`.

The rules below exist to give the user a clean, reversible record of the work the agent does, and to prevent accidental data loss.

---

## Git workflow (mandatory)

### Atomic commits as you work

When working through a task that has multiple meaningful steps, commit your work in small atomic units rather than batching everything into one commit at the end. Each commit should represent one logical change.

After completing a self-contained piece of work — a feature, a fix, a refactor, a test, a docs update — stage the relevant files and commit before moving on to the next unit of work. Do not wait to be asked.

### Conventional Commits

Every commit message follows the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <subject>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`, `perf`. The scope is optional. The subject is in imperative mood, lowercase, no trailing period, under 72 characters total.

When in doubt, the `git-flow` skill (installed alongside this file) has the full reference and is invoked automatically when the user asks to commit.

### Never push without confirmation

Do not run `git push` (or any equivalent that publishes commits to a remote) without the user explicitly asking. When asked to push, first show:

1. The branch and remote that will be pushed.
2. The list of commits that will be pushed.
3. Whether any of those commits would force-overwrite remote history.

Then wait for the user's confirmation before executing.

### Never run destructive operations without confirmation

The following commands require an explicit "yes" from the user before running, regardless of how casually they're requested:

- `git push --force` and `git push --force-with-lease`
- `git reset --hard`
- `git branch -D <name>` (force delete)
- `git clean -fd` (delete untracked files)
- `git rebase` against pushed history
- `git checkout <path>` (when it would discard uncommitted changes)
- Any `rm -rf` or equivalent that touches version-controlled or user-editable directories

Explain what the command does, explain what will be lost, then ask. Do not execute on the first request.

### Initialize git when missing

If the user wants to record progress in a directory that isn't a git repository, initialize one before committing. This is the right default for a vibe-coding flow — the user's work should always be recoverable.

```sh
git init
git add -A
git commit -m "chore: initial commit"
```

### Don't commit secrets

Before staging files, scan for common secret patterns: `.env`, `.env.*`, `credentials.json`, `*.pem`, `*.key`, `id_rsa*`, AWS access keys (`AKIA*`), GitHub tokens (`ghp_*`, `gho_*`), Slack tokens (`xoxb-*`, `xoxp-*`), generic strings shaped like `(api|secret|token|password)\s*[:=]\s*["'][A-Za-z0-9+/=_-]{20,}["']`.

If anything matches, **warn the user before staging it.** Never silently include secrets in a commit.

---

## Communication

- Default to concise, structured responses. Use headings and lists when they help; skip them when they don't.
- Show the exact commands you ran and their output.
- When you make a decision the user might disagree with, name the alternative and explain the tradeoff in one sentence.
- If you're stuck, say so plainly and ask one precise question.

---

## Working with files

- Prefer editing existing files over creating new ones.
- Don't create documentation files (READMEs, plans) unless the user asks.
- When editing, preserve the file's existing indentation, line endings, and formatting conventions.
- Read a file before editing it. Don't guess at its contents.

---

## Project-level overrides

If a project has its own `AGENTS.md` at its root, those rules take precedence over this file for that project. This file is the **default** — projects can override anything here for their specific context.

---

## Editing this file

This file is yours. If a rule here doesn't fit your workflow, change it. The bootstrap will not overwrite this file on subsequent runs.
