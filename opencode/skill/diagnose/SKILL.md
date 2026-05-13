---
description: >-
  Disciplined read-only diagnosis loop for hard bugs and performance
  regressions. Reproduce the problem, narrow it down, test hypotheses,
  design careful instrumentation, then propose a fix and regression test.
  Use when the user says "diagnose this", "debug this", "figure out why X is broken",
  reports a crash or failing behavior, or describes a performance regression.
---

# Diagnose

A disciplined way to investigate hard bugs without jumping straight to edits.

**This skill is read-only investigation.** Build a feedback loop, reproduce the bug, generate hypotheses, use existing read-only probes where available, and design any code-changing probes as recommendations. Do not write files, apply temporary instrumentation, apply the fix, restart services, change config, or mutate production state. Hand proposed instrumentation and implementation to the user or Aragorn.

## Plain-language glossary

- **Feedback loop** — a fast way to tell "bug still happens" or "bug is gone."
- **Failure mode (what could go wrong)** — a crash, wrong result, timeout, or confusing screen.
- **Call path (how the code is reached)** — the route from the user's action or command to the line that fails.
- **Seam (connection point where behavior can be swapped)** — a place to test or replace behavior without changing everything around it.

## Long-running command discipline

Diagnosis tempts you to run everything. Before any expensive command — full test suites, broad fuzz loops, large searches, profilers, heap snapshots, dependency installs, or anything likely to take more than about 30 seconds:

1. Explain what would run and what signal it would produce.
2. Show the exact command.
3. Estimate cost: wall time, CPU/memory, network, and any money/token cost.
4. Ask whether to run it now or have the user run it separately.
5. Prefer a targeted, narrow loop when it gives enough signal.

See [feedback-loops.md](feedback-loops.md) for narrower alternatives.

## Phase 1 — Build a feedback loop

This is the most important phase. A fast, deterministic pass/fail signal makes the rest of debugging mechanical. Without one, the investigation becomes guessing.

Spend real effort here. Be creative, but stay narrow: a 2-second focused check beats a 5-minute broad suite.

See [feedback-loops.md](feedback-loops.md) for ways to build and sharpen the loop.

Do not proceed until you have a loop you trust, or until you have clearly explained why no loop can be built with the access available.

## Phase 2 — Reproduce

Run the loop and watch the bug appear.

Confirm:

- [ ] The loop shows the same failure mode the user described, not a nearby different problem.
- [ ] The failure reproduces reliably, or often enough to debug if it is intermittent.
- [ ] You captured the exact symptom: error text, wrong output, slow timing, screenshot details, or logs.

Wrong bug means wrong fix. Stop and adjust the loop if the symptom does not match.

## Phase 3 — Hypothesize

Generate **3–5 ranked hypotheses** before testing any one of them. A single plausible idea can anchor the whole investigation too early.

Each hypothesis must be falsifiable:

> "If <X> is the cause, then <checking Y> will show <specific result>."

Show the ranked list to the user when practical. They may know recent changes or already-ruled-out causes. If they are not available, proceed with your ranking and state the assumption.

## Phase 4 — Instrument

Each probe design must map to a specific prediction from Phase 3. Change one variable at a time when a write-capable agent or the user applies it.

Tool preference:

1. Debugger or REPL inspection when available.
2. Existing observability: structured logs, traces, metrics, or test output.
3. Proposed targeted temporary logs at the seams that distinguish hypotheses, handed off for a write-capable agent or the user to apply.

Never "log everything and search later." That creates noise, not evidence.

If a hypothesis needs temporary logs, disposable-branch changes, or scratch changes, do not apply them in this skill. Instead, include the exact proposed probe locations, a unique prefix such as `[DEBUG-a4f2]`, and cleanup instructions in the diagnosis package. Do not leave probe changes mixed into the final recommendation.

For performance regressions, measure first: establish a baseline with an existing timing harness, profiler, query plan, or browser performance trace, then compare one variable at a time. If a new harness or code change is needed, propose it for handoff instead of applying it.

See [instrumentation.md](instrumentation.md) for probe patterns and cleanup checks.

## Phase 5 — Propose fix + regression test

This skill does not apply fixes or code-changing probes. It produces a fix proposal, any remaining probe recommendations, and a regression-test design.

The test design should exercise the real bug pattern at the right seam. If the only available seam is too shallow, say that clearly: the architecture is preventing the bug from being locked down.

Produce a diagnosis package containing:

- **Symptom** — what the user reported, restated precisely.
- **Repro** — the feedback loop and how to run it.
- **Cause** — the surviving hypothesis, stated mechanically: what happens, where, and why.
- **Evidence** — loop output, available probe output from read-only tools or user-applied probes, and ruled-out hypotheses.
- **Recommended probes** — any proposed temporary instrumentation that still needs a write-capable handoff, with exact locations, expected signal, tags, and cleanup notes.
- **Recommended fix** — specific code change at a specific seam, with rationale.
- **Regression test** — what test should fail before the fix and pass after it.
- **Risks** — what the fix might break and what to verify.
- **Follow-ups** — missing coverage, hard-to-test call paths, or architecture concerns.

Hand the package to the user or Aragorn for implementation.

## Phase 6 — Post-mortem

After the diagnosis is complete, ask: **what would have prevented this bug?**

If the answer is architectural — no good seam, tangled call paths, behavior spread across too many files — recommend the `improve-codebase-architecture` skill. Do this after diagnosis, not before.

## Behavioral rules

### Always

- Build the feedback loop before hypothesizing.
- Apply long-running command discipline before expensive commands.
- Tie every probe to a hypothesis.
- State uncertainty plainly.
- Hand off proposed instrumentation and the fix; do not apply them yourself.

### Never

- Never write files, including temporary instrumentation or the production fix, in this skill.
- Never run expensive commands without proposing them first.
- Never mutate production state, restart services, or change config as part of diagnosis.
- Never proceed past a phase without satisfying its exit criteria or explaining why it is blocked.

## Checklist

```text
[ ] Feedback loop built and verified
[ ] Bug reproduced and matched to the user's symptom
[ ] 3–5 falsifiable hypotheses ranked
[ ] Each read-only probe or proposed probe design mapped to a prediction
[ ] Proposed temporary instrumentation tagged and paired with cleanup instructions
[ ] Diagnosis package complete
[ ] Handoff target identified
[ ] Post-mortem asked: what would have prevented this?
```

## References

- [feedback-loops.md](feedback-loops.md) — ways to build a loop, sharpen it, and handle intermittent bugs
- [instrumentation.md](instrumentation.md) — probe patterns, performance measurement, and cleanup checks
