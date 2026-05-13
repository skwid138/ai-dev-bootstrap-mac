# Global Agent Guidelines

These rules apply to every project worked on from this machine. They were installed by `ai-dev-bootstrap-mac`. You can edit or remove this file at any time — it lives at `~/.config/opencode/AGENTS.md`.

The rules below exist to give the user a clean, reversible record of the work the agent does, and to prevent accidental data loss.

---

## Agent roster

| Agent | Role |
|---|---|
| Treebeard | Planning, plan review, and post-implementation audit |
| Legolas | Codebase exploration and file discovery |
| Radagast | External docs and OSS research |
| Aragorn | Autonomous deep implementation |

---

## Workflow spine

> **intake → triage → [non-trivial: plan → audit → revise] → approve → build → verify → explain**

Approval is universal: trivial requests approve a single edit; non-trivial requests approve a plan. Both flow through the same `permission.edit: ask` gate at the moment of mutation.

The canonical, long-form source for this spine is `instruction/plan-workflow.md`. **If you need to change the spine, change it there first;** this file re-quotes from it. Drift here is a bug.

---

## Triage rule

Every request gets classified before work starts.

- **Trivial:** single file, single intent, no decisions to make, no ambiguity, no state changes, reversible in one git operation. Take the bypass path (confirm intent → propose → approve edit).
- **Non-trivial:** multiple files, multiple steps, any decision the user might want a say in, any irreversible operation, any new dependency, any architecture-shaped choice. Take the full plan-and-audit path.
- **When in doubt: treat as non-trivial.** The plan-and-audit overhead is small; the cost of an unaudited bad plan is large.

State the classification in your response: *"Treating this as a [trivial|non-trivial] request because [reason]."* The full rubric and bypass-flow script live in `instruction/plan-workflow.md`.

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

## Plain language at boundary

Default to plain English when speaking to the user. Use jargon only when the user introduces it first, or when explaining a technical decision they are being asked to make. The user's terminal output is not a code review log; it is a conversation. Translate.

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

## The `question` tool

Use `question` to ask the user something whenever the choice is non-obvious or has consequences. Two patterns:

- **Multiple choice** for technical or jargon-heavy decisions: provide 2–4 options. Mark the agent's recommendation as `(Recommended)` and list it **first**. This gives the user a sane default when they don't have an opinion.
- **Free-text** for open-ended intake: scope, naming, prose phrasing.

Pattern reference and examples in `instruction/plan-workflow.md`.

---

## Plan-doc convention

Plans live in `.project-plans/YYYY-MM-DD_<slug>.md`. Notes co-locate as `<slug>-notes.md`.

When resuming an existing plan in a fresh session, **read first, act second**: plan body → Live status table → Decision log → Progress log (recent entries) → Notes file (if the plan header points to one and the value is not `(none)`). Do not start work without this read-set in context.

Full template, filename rules, and resume protocol in `instruction/plan-workflow.md`.

---

## Audit-default rule

Every non-trivial plan is audited by `treebeard` before approval / Tab handoff to Build. Audit is a **strong default, not a mechanical lock** — opencode has no hook to force a tool call.

To skip the audit, append a Divergence-log entry stating the reason. Otherwise: always run, always show findings (including the zero-findings result), then ask the user how to proceed.

Audit format, severity rubric, and re-audit mode are defined in `instruction/plan-workflow.md` §3.

---

## Progress-log rule

On every commit related to a plan task, append one entry to that plan's Progress log:

- Full ISO timestamp (use system-clock output verbatim — do not convert timezones).
- Task ID.
- Short SHA.
- One-line note describing what the commit accomplishes.

The log is append-only. Never edit prior entries.

---

## Auto-notes rule

When working memory grows large, or compaction is approaching, write or update the plan's notes file. The user does not need to ask.

- **If the `dcp` plugin is configured** with the project's threshold (see T2.5 of the redesign plan): it will inject a nudge at ~65% context usage. Follow it.
- **If `dcp` is not configured:** apply judgment. Heuristics — *"I'm starting to forget details from earlier in the session,"* *"I've made several decisions I should record,"* *"the user is about to compact."* Err on the side of writing.

Notes-file lifecycle, naming, and archival are in `instruction/plan-workflow.md` §11.

---

## Tab-handoff rules

`opencode` has two top-level agent modes (`plan` and `build`) and the user switches between them with **Tab**. The agent does not switch modes programmatically in the v1 design — `plan_exit` is gated behind an experimental flag in shipped opencode and is not relied on. (See the redesign plan's Divergence log entry for T1.4.)

### Plan → Build

When a plan is approved (non-trivial: post-audit-revise; trivial-but-needs-mutation: post-confirm-edit), the **Plan agent's final message MUST include a plain-language Tab-switch instruction**. Canonical phrasing:

> *"The plan is approved. Press Tab to switch to Build mode, then tell it to execute the plan at `<path>` (or describe the trivial change to apply)."*

Do not attempt to call any handoff tool.

### Build → Plan (soft nudge)

When the Build agent is invoked with **no prior approved plan or trivial-edit-approval visible in the conversation context** — heuristic signals: empty/short conversation, no recent `.project-plans/` reference, user's first turn is a fresh request rather than *"execute the plan"* — Build's first response **MUST** be a soft nudge:

> *"I'm in Build mode, which can edit files. If you're starting fresh, you probably want Plan mode first — press Tab to switch. If you already approved a plan and want me to execute it, tell me which one."*

This is **not a hard refusal**. The user can override and Build proceeds.

---

## Project-level overrides

If a project has its own `AGENTS.md` at its root, those rules take precedence over this file for that project. This file is the **default** — projects can override anything here for their specific context.

---

## Editing this file

This file is yours. If a rule here doesn't fit your workflow, change it. The bootstrap will not overwrite this file on subsequent runs.
