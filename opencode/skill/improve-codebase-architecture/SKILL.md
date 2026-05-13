---
description: >-
  Read-only architecture review. Finds deepening opportunities — refactors
  that make code simpler to use from the outside while concentrating behavior
  in one place. Use for system-level architecture review, cross-file refactor
  proposals, tightly coupled modules, missing seams, or deciding where to
  invest architecture effort. Not for one-function or one-file cleanup.
---

# Improve Codebase Architecture

Surface architectural friction and propose **deepening opportunities** — changes that make code simpler to use from the outside while hiding more behavior inside a well-shaped module.

**This skill is read-only investigation.** Explore, propose candidates, optionally grill the chosen candidate, and hand off a proposal package. Do not execute the refactor. Implementation goes to the user or Aragorn.

## When to use this skill

Use it for system-level architecture review:

- Clusters of shallow modules across multiple files.
- Missing or wrong-place seams (connection points where behavior can be swapped).
- Tightly coupled modules that resist testing or change.
- Questions like "where should we invest architecture effort?"

Do **not** use it for local refactors: renaming a function, extracting a helper inside one file, or cleaning up one loop. If unclear, ask: "system-level architecture review, or local refactor?"

## Plain-language glossary

Use these terms consistently. Full definitions live in [LANGUAGE.md](LANGUAGE.md).

- **Module** — a piece of code with an interface and implementation: function, class, package, or feature slice.
- **Interface** — everything a caller must know to use the module correctly, not just the type signature.
- **Deepening (making code simpler to use from the outside)** — putting more useful behavior behind a smaller interface.
- **Seam (connection point where behavior can be swapped)** — a place to test or replace behavior.
- **Adapter** — a concrete implementation plugged into a seam.
- **Call path (how the code is reached)** — the route from a user action or command to this code.
- **Failure mode (what could go wrong)** — crash, wrong result, data loss, confusing UI, or slow path.
- **Locality** — changes and bugs stay concentrated in one place.
- **Leverage** — callers get more behavior from less interface.

## Long-running command discipline

Architecture review tempts broad scans. Before full dependency graphs, large call-path searches, full test suites, or many parallel subagents:

1. Explain what would run and what signal it would produce.
2. Show the command or subagent brief.
3. Estimate cost: wall time, subagent count, and token cost.
4. Ask whether to run it now.

Prefer targeted reads of the highest-signal files.

## Process

### 1. Explore

Start with the user's stated area of friction. If needed, delegate focused codebase exploration to Legolas with a brief that names the suspected friction and asks for files, call paths, shallow modules, leaked seams, and hard-to-test clusters.

Explore organically and note where understanding becomes hard:

- Where does one concept require bouncing between many small files?
- Where is a module shallow — interface nearly as complex as implementation?
- Where were functions extracted only for testing, while the real bugs live in the call path?
- Where do modules leak assumptions across seams?
- Which behavior is untested because the current interface is awkward?

Apply the **deletion test**: if deleting a module makes complexity vanish, it was pass-through. If complexity reappears across many callers, the module was earning its keep.

### 2. Present candidates

Present a numbered list of deepening opportunities. For each:

- **Files** — paths involved.
- **Problem** — why the current shape causes friction.
- **Solution** — plain-English change.
- **Benefits** — locality, leverage, and testability.
- **Failure modes** — what could go wrong if implemented poorly.

Do not design interfaces yet. Ask: "Which candidate should we explore?"

### 3. Grilling loop

When the user picks a candidate, walk the design tree one question at a time:

- What behavior belongs inside the deepened module?
- What should callers no longer need to know?
- Where should the seam live?
- Which adapters are real, not hypothetical?
- Which tests should survive through the new interface?

If the user wants alternative interface designs, use [INTERFACE-DESIGN.md](INTERFACE-DESIGN.md).

### 4. Hand off

Produce a deepening package:

- **Candidate** — chosen opportunity and why.
- **Files involved** — concrete paths.
- **Current shape** — why it is shallow or friction-prone.
- **Target shape** — proposed module interface and seam placement.
- **Dependency strategy** — category from [DEEPENING.md](DEEPENING.md) and required adapters.
- **Test strategy** — what tests move, disappear, or get added at the new interface.
- **Risks** — likely failure modes and verification steps.

Hand the package to the user or Aragorn. Do not execute the refactor in this skill.

## Behavioral rules

### Always

- Use the vocabulary in [LANGUAGE.md](LANGUAGE.md).
- Apply the deletion test before calling something shallow.
- Apply long-running command discipline before broad scans or many subagents.
- Present candidates before designing interfaces.
- Hand off the package instead of implementing.

### Never

- Never use this for local single-file cleanup.
- Never propose a seam with only one adapter unless you name why it is temporary.
- Never test through private implementation details when an interface test can cover behavior.
- Never execute the refactor in this skill.

## Checklist

```text
[ ] Scope confirmed as system-level architecture review
[ ] Relevant files and call paths explored
[ ] Candidates presented with files/problem/solution/benefits
[ ] User chose a candidate before interface design
[ ] Grilling loop covered behavior, seam, adapters, and tests
[ ] Deepening package complete and handed off
```

## References

- [LANGUAGE.md](LANGUAGE.md) — full vocabulary and principles
- [DEEPENING.md](DEEPENING.md) — dependency categories, seam discipline, testing strategy
- [INTERFACE-DESIGN.md](INTERFACE-DESIGN.md) — alternative interface exploration
