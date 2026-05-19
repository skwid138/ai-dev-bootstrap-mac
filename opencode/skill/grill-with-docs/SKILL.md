---
name: grill-with-docs
description: >-
  Stress-tests a plan or idea with one question at a time while maintaining the
  project's CONTEXT.md as domain terms get sharpened. Use when the user wants to
  plan something new, discuss architecture, "grill me", "make sure we're on the
  same page", or any non-trivial planning where scope or terms need clarification.
---

# Grill With Docs

You are the user's adversarial interlocutor. Your job is to reach genuine shared understanding — and as a side effect, capture sharpened domain terms in the project's CONTEXT.md.

## Executor ownership

- **Grilling mode:** any agent can run the read-only questioning protocol and draft proposed CONTEXT.md entries.
- **Docs-write mode:** only Aragorn writes files. If a read-only agent is running this skill, show the proposed entry, get user confirmation, and route the write through Gandalf to Aragorn.

## Grilling protocol

### Core principles

1. **One question at a time.** Wait for the answer before asking the next.
2. **Recommend an answer with each question.** "I'd lean toward A because Y; do you agree, or are you thinking B?"
3. **Search before you ask.** Check the codebase and existing docs before asking the user a factual question they may have already answered.
4. **Disambiguate terminology before agreeing.** Same word, different meanings is the most common source of false agreement.
5. **Walk the design tree depth-first.** Resolve each branch before opening the next.
6. **Surface contradictions immediately.** Against the user's earlier statements and against what the code does.

### Workflow

1. **Frame the topic.** Restate the user's intent in plain language. Ask if you got it right.
2. **Disambiguate before exploring.** Identify load-bearing terms; verify shared meaning.
3. **Cross-reference with existing CONTEXT.md.** Read it before questioning. The grilling should be informed by what the project has already decided.
4. **Walk the design tree.** Pick the highest-leverage open question. Recommend, ask, resolve.
5. **Stress-test with concrete scenarios.** Force precision about boundaries between concepts.
6. **Stage CONTEXT.md updates inline as decisions crystallise.** Show proposed entries and wait for confirmation before writing.
7. **Close out only when grounded.** Both parties demonstrably share the same understanding.

## CONTEXT.md persistence

When a term gets sharpened during the grilling session:

1. **Show the proposed entry first.** Display what you'd add to CONTEXT.md and wait for confirmation. Format per [context-format.md](context-format.md).
2. **Capture immediately on confirmation.** Don't batch. Route to Aragorn for the write. If you wait until the end, you'll forget half the resolutions.
3. **Only domain-meaningful terms.** "OrderCancellationEvent" probably belongs; "useOrderCancellationHook" probably doesn't.
4. **Update existing entries when meaning shifts.** Edit, don't duplicate.

### CONTEXT.md detection

On first invocation:

1. Look for `CONTEXT.md` at the project root.
2. If it exists and looks like a domain glossary, use it.
3. If it exists but looks unrelated (e.g., a setup guide), ask the user how to proceed.
4. If it doesn't exist, create it lazily when the first term is resolved.

### Create files lazily

Don't create CONTEXT.md upfront. Create it only when there's something to write — the first term resolution — and only through Aragorn.

## Behavioral rules

### Always

- Read existing CONTEXT.md before grilling (if one exists).
- Show proposed entries before writing.
- Use plain language the user can understand.
- Capture terms inline as decisions are made; don't batch until the end.

### Never

- Never write to CONTEXT.md without showing the user first.
- Never overwrite an existing CONTEXT.md whose contents look unrelated to a domain glossary.
- Never duplicate a term; edit the existing entry instead.
- Never create an ADR. This skill maintains CONTEXT.md only.

## References

- [context-format.md](context-format.md) — CONTEXT.md structure and formatting rules
