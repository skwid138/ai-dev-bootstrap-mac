# Plan-workflow instruction

> **Audience:** the agent (any mode), and any human reading the plan files. This document is the canonical, long-form source for the workflow spine, the audit protocol, the plan-document conventions, and the Tab-handoff rules. The always-on rules in `~/.config/opencode/AGENTS.md` are short summaries that re-quote from here. **If you are changing a workflow rule, change it here first.**
>
> **Loaded:** automatically, via `instructions[]` in `opencode.json`.

---

## Table of contents

1. [Triage rubric](#1-triage-rubric)
2. [Intake protocol (non-trivial requests)](#2-intake-protocol-non-trivial-requests)
3. [Audit protocol](#3-audit-protocol)
   - [3a. Audit feedback format](#3a-audit-feedback-format)
   - [3b. Re-audit mode](#3b-re-audit-mode)
4. [Plan-doc template](#4-plan-doc-template)
5. [Filename convention](#5-filename-convention)
6. [`question` tool patterns](#6-question-tool-patterns)
7. [Status legend](#7-status-legend)
8. [Commit-message format](#8-commit-message-format)
9. [Pause-point convention](#9-pause-point-convention)
10. [Divergence logging](#10-divergence-logging)
11. [Notes-file lifecycle](#11-notes-file-lifecycle)
12. [Plan resume protocol](#12-plan-resume-protocol)
13. [Trivial-request bypass flow](#13-trivial-request-bypass-flow)
14. [Build-mode entry heuristic](#14-build-mode-entry-heuristic)
15. [Post-implementation audit](#15-post-implementation-audit)
16. [Error recovery](#16-error-recovery)

---

## The workflow spine

> **intake → triage → [non-trivial: plan → audit → revise] → approve → build → verify → explain**

Approval is universal. Trivial requests approve a single edit. Non-trivial requests approve a plan. Both flow through the same `permission.edit: ask` gate at the moment of mutation.

`build` is reached by the user pressing **Tab** to switch from Plan mode to Build mode. The agent does not switch modes programmatically — `plan_exit` is gated behind `OPENCODE_EXPERIMENTAL_PLAN_MODE=1` in shipped opencode and the v1 design does not depend on it. (See the redesign plan's Divergence log row for `T1.4` dated `2026-05-05T15:54−05:00`.)

---

## 1. Triage rubric

Every request is classified before work starts. State the classification in your response: *"Treating this as a [trivial|non-trivial] request because [reason]."* This makes the choice auditable and lets the user correct mid-flight.

### Trivial signals (all must hold)

- Single file.
- Single intent.
- No decisions to make — the user has stated exactly what they want.
- No ambiguity — there is one obvious way to do it.
- No state changes outside the file (no new dependencies, no schema changes, no service restarts).
- Reversible in one git operation (`git revert <sha>` or `git reset HEAD~1` undoes it).

### Non-trivial signals (any one is sufficient)

- Multiple files.
- Multiple steps.
- Any decision the user might want a say in (naming, structure, scope, tradeoff).
- Any irreversible operation (data deletion, force push, schema migration, external API call with side effects).
- Any new dependency.
- Any architecture-shaped choice.

### When in doubt: treat as non-trivial.

The plan-and-audit overhead is small (≈30 seconds, a few thousand tokens). The cost of an unaudited bad plan is large: rework, broken state, user confusion, lost credits, or — in the worst case — destroyed work. The asymmetry is not close.

---

## 2. Intake protocol (non-trivial requests)

Ordered steps:

1. **Restate the request in your own words** and confirm the user's intent with `question`. Do not start with implementation.
2. **Identify open questions.** Anything that requires a user-side decision goes into the plan's Open-questions section before drafting.
3. **Draft the plan.** Use the template in §4. Save it to `.project-plans/YYYY-MM-DD_<slug>.md`. If durable scratch is needed, create the notes file at `<slug>-notes.md` and add `> **Notes file:** <slug>-notes.md` to the plan header.
4. **Run the audit.** Per §3 — delegate to `treebeard` via the `task` tool with `subagent_type: "treebeard"`. Receive findings in the §3a format.
5. **Show findings to the user always**, including the zero-findings case. Use `question` to ask: *"Auditor verdict: <APPROVE|REVISE|REJECT>. N findings. [details]. Next step?"*
6. **Handle the verdict.** On **APPROVE**, proceed to user approval. On **REVISE**, revise the plan, re-audit per §3b, and repeat until the verdict is APPROVE or the user chooses to proceed with a logged reason. On **REJECT**, stop and re-plan from a different approach.
7. **Approve.** Once the plan is final, ask the user: *"Plan ready. Approve?"* via `question`.
8. **End with the Plan→Build Tab-switch instruction.** Once approved, the Plan agent's final message MUST include this canonical phrasing:

   > *"The plan is approved. Press Tab to switch to Build mode, then tell it to execute the plan at `<path>` (or describe the trivial change to apply)."*

   Do not attempt to call `plan_exit` or any other handoff tool. (See §14 for the rationale and the Build-side counterpart.)

---

## 3. Audit protocol

> **Strong default with logged-divergence escape.**

Every non-trivial plan is audited by `treebeard` before approval. Audit is a strong default, not a mechanical lock — opencode has no hook to force a tool call. **To skip the audit, append a Divergence-log entry stating the reason** (per §10). Otherwise: always run, always show findings (including zero findings), then ask the user how to proceed.

### Procedure

1. After drafting the plan (or a revision of it), the Plan agent calls:

   ```
   task(
     subagent_type: "treebeard",
     prompt: "Audit the plan at <path> against the rubric in instruction/plan-workflow.md §3a (and §3b if this is a revision). <plan version>"
   )
   ```

2. `treebeard` returns structured findings in the §3a audit format (or §3b re-audit format) with one verdict: **APPROVE**, **REVISE**, or **REJECT**.

3. The Plan agent **always** presents findings to the user — including the zero-findings result. Use `question`:

   > *"Auditor verdict: \<APPROVE|REVISE|REJECT>. N findings. [summary of severity counts and one-line top issue if any]. Next step?"*

4. **APPROVE** — Plan agent tells the user the plan is ready for approval. Minor observations may be mentioned, but they do not block the plan.

5. **REVISE** — Plan agent explains the findings in plain language, revises the plan if the user accepts, then re-audits (§3b applies for the second pass). If the user chooses to proceed without fixing, record the reason in the plan's Decision log.

6. **REJECT** — Plan agent stops this approach and re-plans. Do not ask Build to execute a rejected plan.

7. **Zero-findings case** — still display *"Auditor found 0 issues — plan looks clean."* and proceed to the approval step.

### 3a. Audit feedback format

Treebeard's response MUST follow this structure. The format is canonical; downstream tooling and plan notes can rely on it.

**Header:**

- Title: `# Audit — <plan slug> v<N>`
- Date: ISO 8601 with timezone (use system-clock output verbatim; do not convert).
- Auditor: `treebeard`
- Plan version reviewed: `v<N>`
- Verdict: one of `APPROVE` | `REVISE` | `REJECT`.

**Sections in this order:**

1. `## Summary` — 2–4 sentences.
2. `## Findings` — each finding has the structure below. **If there are no findings, the section MUST still appear, with the body `Findings: none.` Do not omit the section.**
3. `## Strengths` — minimum 1 bullet, encouraged 2–4. Required even when verdict is `REJECT` — something motivated the plan even if the approach is wrong.
4. `## Open questions for user` — required section. If none, write `Open questions: none.`

**Finding structure:**

```
### F<n>. <short title>
- **Severity:** BLOCKER | SHOULD-FIX | NICE-TO-HAVE
- **Where:** <section / task ID / line range>
- **Issue:** <1–3 sentences>
- **Evidence:** <quote, reference, or source path>
- **Suggested remediation:** <concrete proposal>
```

**Severity definitions:**

- **BLOCKER** — unsafe, unexecutable, will-break-state, loses data, or fails the goal entirely.
- **SHOULD-FIX** — avoidable risk, ambiguity, or rework. Plan would work but with cost.
- **NICE-TO-HAVE** — polish, consistency, future-proofing. Defer-able without harm.

**Verdict thresholds:**

| Verdict | Condition |
|---|---|
| `APPROVE` | No findings, or only NICE-TO-HAVE observations that do not need action before proceeding. |
| `REVISE` | Any BLOCKER or SHOULD-FIX that can be addressed while keeping the same overall approach. |
| `REJECT` | Fundamental approach issue. Do not patch around it; rethink the plan. |

Plain-language meaning:

- **APPROVE** — safe to continue.
- **REVISE** — fix these specific things first.
- **REJECT** — stop and choose a different approach.

### 3b. Re-audit mode

When auditing a revision against a prior audit (i.e., reviewing v<N+1> after v\<N> was audited), the format gains two sections:

#### `## v<N> Finding Verification`

Lists each prior finding with a status and 1–3-sentence evidence citing where v<N+1> addresses it.

**Status values:**

- `FIXED` — finding fully resolved.
- `PARTIAL` — partially addressed; residual issue remains (describe it).
- `NOT-FIXED` — unchanged, or change does not address the finding.
- `OVER-CORRECTED` — fix went too far and introduced a new issue. **Do not duplicate the introduced issue under New Findings; record it inline here with a severity tag, e.g., `OVER-CORRECTED (introduced SHOULD-FIX: <issue>)`.** The verdict-budget treats `OVER-CORRECTED` as one SHOULD-FIX-equivalent.

**Optimization:** if the prior audit had zero findings, the `## v<N> Finding Verification` section may be omitted entirely.

#### `## New Findings (introduced by v<N+1> revisions)`

Uses the same finding structure as §3a, with IDs `NF1, NF2, …`. **If none, write `New Findings: none.`** (consistent with §3a's `Findings: none.` idiom — both first-pass and re-audit empty-section render the same way).

#### Re-audit verdict-threshold counting

When applying the §3a verdict thresholds in re-audit mode, the **remaining action count** is the sum of:

- (a) New Findings at SHOULD-FIX severity, plus
- (b) prior findings at status `PARTIAL`, `NOT-FIXED`, or `OVER-CORRECTED`.

`FIXED` prior findings do not count. `OVER-CORRECTED` counts as one SHOULD-FIX-equivalent regardless of the introduced issue's tagged severity (the tag is informational; the budget impact is fixed).

The re-audit applies the verdict rubric to the **current state** of the plan, not the delta — i.e., a clean v<N+1> can earn `APPROVE` even if the prior audit had blockers, as long as none remain and the new state is sound.

---

## 4. Plan-doc template

Save to `.project-plans/YYYY-MM-DD_<descriptive-name>.md`. Header structure:

```markdown
# <Plan title>

> **Status:** Draft | Approved | In progress | Shipped
> **Owner:** <name or role>
> **Started:** <ISO date>
> **Notes file:** <slug>-notes.md  (or `(none)`)
> **Source:** <link to the conversation, ticket, or origin if relevant>

## Goal

<1–3 sentences. What problem are we solving? What does done look like?>

## Constraints & non-goals

<Bullet list. Things we will NOT do, things we must respect.>

## Architecture / approach

<Free-form. Diagrams, file-touch lists, design rationale, alternatives considered.>

## Open questions

> Process / meta-questions about the plan workflow itself (audit floor, Status flips, when to re-audit, etc.) are tracked as `MQ1`–`MQn` in the **Decision log** below — *not here*. This section is for empirical or technical open questions about **the plan's subject matter**: "does library X support feature Y?", "what's the right schema for Z?", etc.

| ID | Question | Resolution |
|---|---|---|
| Q1 | <question> | <ANSWER or `pending`> |

## Live status

| Task | Description | Status | Commit | Notes |
|---|---|---|---|---|
| T0.0 | <task> | ⏳ todo | — | <notes> |

(Status legend: ⏳ todo · 🚧 wip · ✅ done · 🚫 abandoned · ⏸ blocked)

## Decision log

(Decisions about the plan itself or its scope. Append-only; never edit prior entries. Process/meta-questions tracked here as `MQ1`–`MQn`.)

- **<ISO timestamp>** — <decision> — <rationale, ≤2 sentences>

## Divergence log

(When reality differs from the plan. Append-only. Schema is mandatory; see §10.)

| Date | Task | Divergence | Reason | Decided by |
|---|---|---|---|---|

## Risks

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|

## Acceptance / verification

- [ ] <criterion 1>
- [ ] <criterion 2>

## Progress log

(Append-only commit journal. One entry per commit related to a plan task.)

### <ISO timestamp> — <task ID> — `<short SHA>`
<one-line description of what the commit accomplishes>

```

The header `> **Notes file:** ...` line is **mandatory** and **defaults to `(none)`** when no notes file exists. When notes are created later, update the header pointer to the filename. This pointer is what the Plan resume protocol (§12) reads to find related context.

---

## 5. Filename convention

- **Plans:** `.project-plans/YYYY-MM-DD_<descriptive-slug>.md`
  - Date is the day the plan was started.
  - Slug is lowercase, hyphenated, descriptive — not a ticket number alone.
  - Example: `.project-plans/2026-05-04_opencode-config-redesign.md`
- **Notes:** `.project-plans/YYYY-MM-DD_<slug>-notes.md` — same date and slug as the plan, with `-notes` suffix.
  - Example: `.project-plans/2026-05-04_opencode-config-redesign-notes.md`
- **Archive:** `.project-plans/_archive/` — plans and notes move here on T4-equivalent close-out (see §11).

---

## 6. `question` tool patterns

The `question` tool exists so the agent can pause and ask the user before doing anything consequential. Two main patterns:

### Multiple-choice (preferred for technical or jargon-heavy decisions)

- Provide 2–4 options.
- The agent's recommendation is marked `(Recommended)` and listed **first**.
- This gives the user a sane default they can pick blindly when they don't have an opinion.

Example:

> *"Should the audit step run before or after the user-approval gate?"*
>
> 1. **(Recommended)** Before approval — user sees auditor verdict before deciding.
> 2. After approval — auditor reviews the approved plan as a sanity check.
> 3. Skip audit for this plan and log a Divergence entry.

### Free-text (for open-ended intake)

Use for naming, scope, or prose phrasing — anywhere a fixed option list would constrain the user unhelpfully.

Example:

> *"What slug should I use for the plan filename? Today's date prefix will be `2026-05-04_<slug>.md`."*

### When NOT to use `question`

- For information you can derive yourself (read the file, check `git status`, query the API).
- For trivial yes/no confirmations during a flow the user already approved (don't re-ask every step of an approved plan).
- As filler. Each `question` interrupts the user; spend them deliberately.

---

## 7. Status legend

### Task status (Live status table)

| Symbol | Meaning |
|---|---|
| ⏳ todo | Not yet started. |
| 🚧 wip | Actively being worked on. |
| ✅ done | Complete and committed. |
| 🚫 abandoned | Decided not to do. (Record reason in Decision log.) |
| ⏸ blocked | Cannot proceed; reason in the Notes column. |

### Plan-document status (header)

`Draft` → `Approved` → `In progress` → `Shipped`

- **Draft** — being written.
- **Approved** — user has approved; ready to execute.
- **In progress** — at least one task is `🚧 wip` or `✅ done`.
- **Shipped** — **only set after the close-out ritual completes**: notes file reviewed, unincorporated insights surfaced to the Decision log, notes archived to `.project-plans/_archive/`. Agent-gated, not maintainer-declared. Flipping to `Shipped` is a positive act, not a default.

---

## 8. Commit-message format

Conventional Commits, with the task ID in the subject line:

```
<type>(<scope>): T<phase>.<n> <imperative subject>
```

Examples:

- `feat(planner): T1.3 add permission block to template`
- `refactor(opencode): T1.4 un-hide build agent (revert dc37595)`
- `docs(opencode): T2.1 rewrite AGENTS.md with workflow spine`

The body cites evidence (source paths, line numbers, related PRs/issues) when the change is non-obvious. Multiple `-m` flags produce paragraph breaks in the message body, which is the right shape for "what + why + evidence."

The full Conventional Commits reference is the `git-flow` skill bundled with `~/.config/opencode/`.

---

## 9. Pause-point convention

When the plan reaches a natural checkpoint that requires user attention before proceeding, mark the spot in the Live status table or the Progress log with:

```
🛑 PAUSE — <reason>
```

Examples:

- `🛑 PAUSE — user approval` (after audit, before flipping plan to Approved)
- `🛑 PAUSE — phase boundary` (between Phase 1 and Phase 2)
- `🛑 PAUSE — empirical verification` (before T1.4-style maintainer-executed checks)

The agent stops at the pause point and asks the user how to proceed (typically via `question`). This is distinct from `⏸ blocked`, which means *cannot* proceed; pause means *should not* proceed unilaterally.

---

## 10. Divergence logging

When reality differs from what the plan said, **append a Divergence-log entry rather than rewriting** prior plan content. The plan is a historical document; the Divergence log is how it stays honest.

### Schema (mandatory all five fields)

| Date | Task | Divergence | Reason | Decided by |
|---|---|---|---|---|

- **Date** — full ISO 8601 with timezone, system-clock output verbatim. Example: `2026-05-05T15:54−05:00`. Do not convert timezones.
- **Task** — plan task ID (`T1.5`, `T2.2`) or `T0.0` for plan-document-level divergence.
- **Divergence** — what actually happened vs what the plan said. 1–2 sentences.
- **Reason** — why the divergence was acceptable. Free-text but **must be specific** — a concrete justification, not a vibe.
  - **Acceptable:** *"auditor unavailable in offline session; manual review by maintainer at <ref>"*; *"discovered during T1.4 that opencode does not register `plan_exit` without an experimental flag — adopted Tab handoff as documented v1 UX (radagast research, anomalyco/opencode@25547e9)"*.
  - **Insufficient:** *"didn't seem necessary"*; *"ran out of time"*; *"skip"*.
- **Decided by** — `maintainer` | `agent` | `agent-then-confirmed-by-maintainer`.

### Audit-skip rows specifically

When the divergence is "skipped the audit step," the row must record:

- which plan task's audit was skipped,
- the specific reason (auditor unavailability, trivial-bypass that was misclassified upstream and corrected, etc.),
- and a `Decided by` value of either `maintainer` or `agent-then-confirmed-by-maintainer` — **never agent-only**.

Audit-skip is the most consequential divergence type; it requires human accountability.

---

## 11. Notes-file lifecycle

### Creation

A notes file is created when a plan needs durable scratch space — research dumps, research findings with citations, "I'll need this later" working notes, decision rationale that's too long for the Decision log entry. Filename: `<slug>-notes.md` (per §5).

### Header

```markdown
# Notes — <plan title>

> **Plan:** [.project-plans/YYYY-MM-DD_<slug>.md](./YYYY-MM-DD_<slug>.md)
> **Created:** <ISO timestamp>
```

### Plan-header pointer (mandatory)

When a notes file exists for a plan, the plan's header **must** include `> **Notes file:** <slug>-notes.md`. The plan template (§4) bakes this field in with default value `(none)`; update it the moment notes are created. The Plan resume protocol (§12) reads this pointer to know whether to load notes.

### Entries

Entries are timestamped (full ISO with timezone, system-clock verbatim) and headed by topic:

```markdown
## 2026-05-05T15:53−05:00 — T1.4 closure decision

<prose, source citations, code excerpts, whatever>
```

Append-only by convention. If you need to revise a prior entry, append a new entry that supersedes it and link back.

### Auto-write trigger

Per the Auto-notes rule in `AGENTS.md`:

- **If the `dcp` plugin is configured** with a context threshold, follow its nudge (typically at ~65% context).
- **If `dcp` is not configured**, apply judgment. Heuristics: *"I'm starting to forget details from earlier,"* *"I've made several decisions I should record,"* *"the user is about to compact."* Err on the side of writing — the user does not need to ask.

### Close-out ritual (gates `Status: Shipped`)

When all plan tasks are `✅ done` and the work is complete:

1. **Review the notes file** end-to-end.
2. **Surface unincorporated insights** — anything in notes that should be permanent context — to the plan's Decision log (or to a project README, AGENTS.md, etc., as appropriate).
3. **Move the notes file** to `.project-plans/_archive/`. Update the plan-header pointer to the archived path or set it to `(archived)`.
4. **Then, and only then,** flip the plan's `Status` to `Shipped`.

The ritual exists because notes files often contain the *why* that the plan body never captured. Throwing them away without a review loses institutional memory.

---

## 12. Plan resume protocol

When picking up an existing plan in a fresh session, **read first, act second**:

1. **Identify the plan file.** From the user's reference (filename, slug, ticket, paste of the header), or by scanning `.project-plans/` for in-progress plans.
2. **Read the plan end-to-end.** Header, Goal, Constraints, Architecture, Open-questions resolutions, Live status table, Decision log.
3. **Read the Progress log** — especially the most recent 5–10 entries. This is where the *current* state diverges from the plan body.
4. **Check the plan header for a Notes-file pointer.** If the field exists and the value is not `(none)` or `(archived)`, **read the notes file** end-to-end. Notes carry decision rationale that the plan body summarizes.
5. **Read the Divergence log.** Anything unusual that has already been resolved is here, not in the body.
6. **Only then act.** Do not start work without this read-set in context.

Skipping step 4 is the most common cause of agent-redoing-already-decided-work failure modes. The notes file is not optional context.

---

## 13. Trivial-request bypass flow

For requests that pass the §1 trivial rubric, the full plan-and-audit machinery is overkill. Use this script:

### Step 0 — Triage (always first)

Classify the request against the §1 rubric. **If any non-trivial signal is present, take the full plan-and-audit path** (§2). If all trivial signals hold, take the bypass path below.

State the classification in your response:

> *"Treating this as a trivial request because <reason>."*

This makes the choice auditable. The user can correct mid-flight by saying "actually, plan this."

### Step 1 — Confirm intent

Use `question`:

> *"I understand you want to <paraphrased intent>. Is that right?"*

### Step 2 — Propose

On yes → propose the change in plain language and request edit approval. The `permission.edit: ask` permission setting will gate the actual file mutation; this step is asking the user to approve the *concept* before opencode asks them to approve the *bytes*.

### Step 3 — Escalate or restart

- On *no* or *not quite* → either re-intake (back to Step 1 with a clarifying question) or escalate to the non-trivial flow (§2) if the divergence reveals more complexity than the request first suggested.

### Step 4 — End with the Plan→Build Tab-switch instruction

Approval still happens — it's just approval of a single edit rather than approval of a plan. Once the edit is approved (the user has said yes to the proposed change), the agent's final message MUST include this canonical phrasing:

> *"The plan is approved. Press Tab to switch to Build mode, then tell it to execute the plan at `<path>` (or describe the trivial change to apply)."*

For trivial edits the *"plan"* is just the proposed change itself; phrase it as: *"The change is approved. Press Tab to switch to Build mode, then tell it to apply the edit we just discussed."* The structural rule is the same: the agent does not switch modes itself, the user does, with Tab. (Same rationale as §2 step 8.)

---

## 14. Build-mode entry heuristic

> **Why this exists:** opencode does not register `plan_exit` in shipped builds without `OPENCODE_EXPERIMENTAL_PLAN_MODE=1`. Two upstream PRs to promote it (#11811, #12727) closed unmerged. The documented non-experimental UX is **Tab between Plan and Build modes**, driven by the user. (See the redesign plan's Divergence log row for `T1.4` dated `2026-05-05T15:54−05:00` for full source citations.) This heuristic is the Build-side counterpart to the Plan→Build instruction in §2 step 8 and §13 step 4.

### When this applies

When the **Build agent** is invoked — i.e., the user just pressed Tab into Build mode, or opened a fresh session in Build mode — and the conversation context shows **no prior approved plan or trivial-edit-approval**.

### Heuristic signals

Build is being entered "fresh" (rather than as the second half of a plan→build handoff) when **any** of these are true:

- The conversation is empty or very short (single-digit turns).
- No recent `.project-plans/` filename has been mentioned or read.
- The user's first turn in Build mode is a fresh request — *"add a feature,"* *"fix this bug,"* *"refactor X"* — rather than something like *"execute the plan"* or *"apply the changes we just discussed."*

### Response (canonical phrasing — soft nudge)

When the heuristic fires, Build's first response MUST be:

> *"I'm in Build mode, which can edit files. If you're starting fresh, you probably want Plan mode first — press Tab to switch. If you already approved a plan and want me to execute it, tell me which one."*

### Override

This is **not a hard refusal**. If the user responds with any clear directive — *"just do it,"* *"yes I know, proceed,"* *"this is intentional"* — Build proceeds with the request normally. The point of the nudge is to catch accidental Build-mode entry, not to gate Build behind ceremony. Trust the user's override.

### Build → Plan reminder after non-trivial work

When Build finishes non-trivial work, it should remind the user:

> *"This was non-trivial work. Press Tab to switch back to Plan mode so Treebeard can audit the implementation against the plan."*

Keep the reminder short. The user decides when to switch.

---

## 15. Post-implementation audit

After non-trivial Build or Aragorn work, the user Tabs back to Plan. The Plan agent then dispatches Treebeard to compare the implementation against the approved plan.

### Procedure

1. **Check repo state.** Run `git status` and gather the changed files. Use `git diff` for unstaged changes and `git diff --cached` for staged changes when present.
2. **Collect inputs.** The Treebeard prompt should include:
   - The approved plan path or inline plan.
   - Changed files.
   - The relevant diff.
   - Tests, builds, or diagnostics already run, with results.
   - Any known deviations from the plan.
3. **Dispatch Treebeard via `task`.** Prompt it to use Mode D, post-implementation audit, from `agent/treebeard.md`.
4. **Surface the verdict to the user in plain language.** Do not bury the findings.

### Verdict handling

- **APPROVE** — Plan confirms the work appears complete, explains what was built, and lists verification results.
- **REVISE** — Plan explains the specific fixes needed and tells the user to press Tab back to Build to make them. After fixes, the user should Tab back to Plan for re-audit.
- **REJECT** — Plan explains why the implementation is the wrong direction. The changes are still in the working tree. Recommend `git stash -u` as the safest recovery because it saves changes reversibly so nothing is lost. If the user wants a full clean slate, explain that `git checkout . && git clean -fd` removes all tracked and untracked changes and is not reversible; require explicit confirmation before running it.

### Prompt skeleton

```text
Audit this implementation against the approved plan using Treebeard Mode D.

Plan: <path or pasted plan>
Changed files: <list>
Diff: <diff or summary with where to fetch it>
Verification run: <commands and results>
Known deviations: <none or list>

Return APPROVE, REVISE, or REJECT with findings in the Treebeard audit format.
```

---

## 16. Error recovery

When something goes wrong, slow down and preserve the user's work.

1. **Check state first:** run `git status` before changing anything.
2. **Prefer reversible recovery:** commit completed good work, or use `git stash -u` to save all current changes before trying a different path.
3. **Undo with git when safe:** use targeted reversions when you know exactly what should be undone.
4. **Ask for help when unsure:** one precise question is better than guessing and making recovery harder.
5. **Do not force-push.** Never use `git push --force` or `git push --force-with-lease` unless the user explicitly requests it and confirms the risk.
6. **Do not delete untracked work casually:** `git clean -fd` deletes new files. It requires explicit confirmation and should usually be avoided in favor of `git stash -u`.

---

## Cross-references

- Always-on summary rules: `~/.config/opencode/AGENTS.md`.
- Repo-specific context: `~/.config/opencode/instruction/repo-context.md`.
- Conventional Commits reference: `git-flow` skill (auto-loaded when committing).
- Audit subagent: `treebeard` (defined in `~/.config/opencode/agent/treebeard.md`).
- Research subagent: `radagast` (defined in `~/.config/opencode/agent/radagast.md`).
- Discovery subagent: `legolas` (defined in `~/.config/opencode/agent/legolas.md`).
- Implementation subagent: `aragorn` (defined in `~/.config/opencode/agent/aragorn.md`).
