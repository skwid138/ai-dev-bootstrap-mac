# `opencode/` — design intent and structure

> **Audience:** the human maintaining this directory and any AI agent working on this codebase.
>
> **What this is:** the components installed to `~/.config/opencode/` by the `ai-dev-bootstrap-mac` bootstrap. This directory is the source of truth; the bootstrap copies from here.
>
> **What this is not:** opencode itself. We configure opencode; we do not fork it.

This README explains why the directory looks the way it does and where to put future changes.

---

## 1. What lives here

```text
opencode/
├── opencode.json.template      # rendered by bootstrap → ~/.config/opencode/opencode.json
├── AGENTS.md                   # short, always-on safety rules
├── instruction/                # small auto-loaded defaults
│   ├── repo-context.md
│   └── agent-defaults.md
├── agent/                      # custom agent definitions
│   ├── gandalf.md              # primary orchestrator
│   ├── saruman.md              # adversarial reviewer
│   ├── radagast.md             # external-research specialist
│   ├── legolas.md              # codebase discovery specialist
│   └── aragorn.md              # sole implementation worker
├── command/                    # custom slash commands
├── skill/                      # on-demand skill definitions
├── package.json                # plugin/runtime dependencies
└── package-lock.json
```

The `template` extension on `opencode.json.template` exists because the bootstrap renders it into the final `opencode.json` on the user's machine.

The repo-level `scripts/` tree is deployed separately to `$AI_BOOTSTRAP_WORKSPACE/scripts/`. Commands or skills that need deterministic shell logic should call those deployed scripts rather than embedding long shell snippets in prompts.

---

## 2. Architecture: Gandalf as the primary agent

Gandalf is the only user-facing entry point. The user talks to Gandalf; Gandalf routes the work.

The default flow is:

> **intake → triage → plan → Saruman audit → Aragorn build → verify → explain**

Why this shape:

1. **Clear ownership.** Gandalf coordinates, Saruman reviews, Legolas explores, Radagast researches, and Aragorn writes files.
2. **One writer.** Aragorn is the sole custom agent with write permission, so file changes have one accountable path.
3. **Review before risk.** Non-trivial work is reviewed by Saruman before implementation, when mistakes are cheapest to fix.
4. **Plain language.** Gandalf explains what is happening for non-technical users instead of exposing internal handoffs.

The built-in `plan`, `build`, and `general` agents are hidden in the template config. They are not the intended user path for this bootstrap.

---

## 3. Agent topology

**Primary:**

- `gandalf` — orchestrates the conversation, triages requests, drafts chat-first plans, delegates to specialists, and explains results.

**Subagents:**

- `saruman` — adversarial reviewer. Reviews non-trivial plans before implementation and audits non-trivial completed work afterward.
- `aragorn` — implementer. The only custom agent that edits or writes files.
- `legolas` — internal codebase explorer. Finds files, call paths, tests, and project patterns.
- `radagast` — external researcher. Checks official docs and source-backed references.

This keeps the agent picker simple for users and keeps safety boundaries explicit for maintainers.

---

## 4. Audit protocol

Saruman review is the default for non-trivial work.

Before implementation, Saruman attacks the plan for missing steps, data-shape mismatches, failure-mode gaps, weak tests, and unsafe assumptions. Gandalf revises the plan or surfaces user-facing tradeoffs based on Saruman's verdict.

After implementation, Saruman compares Aragorn's changes against the approved plan. Gandalf routes any required fixes back to Aragorn and explains the outcome in plain language.

Verdicts:

- **APPROVE** — safe to continue.
- **REVISE** — fix specific issues first.
- **REJECT** — stop and choose a different approach.

---

## 5. Where things go

When adding behavior, choose the smallest layer that works:

1. **Always-on safety rule?** Add it to `AGENTS.md`.
2. **Session-wide default with more explanation?** Add it under `instruction/` and register it in `opencode.json.template`.
3. **Role-specific behavior?** Add it to `agent/<name>.md`.
4. **On-demand workflow?** Add a skill under `skill/<name>/SKILL.md`.
5. **Hard enforcement?** Add or tighten a `permission` block in `opencode.json.template` or the relevant agent file.

Prefer short, focused docs. Long always-on files become harder for both humans and agents to use.

---

## 6. Skills

Skills are for workflows that should load only when relevant: test-driven development, diagnosis, bug hunting, prototypes, architecture review, and plan grilling.

Current curated skills:

- `bug-hunter`
- `dependency-update`
- `diagnose`
- `grill-with-docs`
- `improve-codebase-architecture`
- `prototype`
- `tdd`

When a skill needs deterministic multi-step work, prefer a small script bundled under the repo-level `scripts/` tree (or under that skill's directory when it is truly skill-local). Scripts are easier to test and safer to reuse than long prose instructions.

Curated slash commands:

- `/architecture`
- `/commit`
- `/diagnose`
- `/explain`
- `/grill`
- `/help-me`
- `/prototype`
- `/safer`
- `/update-opencode-deps`

---

## 7. Extension recipes

### Adding an agent

1. Create `agent/<name>.md`.
2. Add YAML frontmatter with `description`, `mode`, and `permission`.
3. Do not pin a model in the agent file; the global config owns model choice.
4. Keep the body focused on the agent's role.

### Adding a skill

1. Create `skill/<name>/SKILL.md`.
2. Write the description as a clear "use this when..." trigger.
3. Bundle reference files or scripts under the skill directory when needed.
4. Test by triggering the skill in a real session.

### Adding an instruction file

1. Create `instruction/<name>.md`.
2. Add it to `opencode.json.template`'s `instructions[]` array.
3. Keep it small and broadly useful.

### Tightening permissions

1. Edit the relevant `permission` block.
2. Prefer deny rules for dangerous patterns and ask rules for ambiguous ones.
3. Test the new rule in a real session when possible.

---

## 8. What was removed, and why

Earlier versions used the built-in planning mode as the primary user path and relied on the user switching modes for implementation. That made the workflow harder to explain and split responsibility across too many places.

The current design restores a single front door: Gandalf. Users ask for help once, Gandalf coordinates the specialists, and Aragorn performs all writes.

Older runtime-control commands were also removed. Delegation now happens through normal agent dispatch rather than a separate orchestration loop.

---

## Cross-references

- Always-on rules: `AGENTS.md`.
- Session defaults: `instruction/agent-defaults.md`.
- Repo-specific context discovery: `instruction/repo-context.md`.
