# Agent Defaults

Standing defaults for every OpenCode session installed by this bootstrap. These rules keep work safe, testable, and understandable for non-technical users.

## Testing

Tests are required for executable code changes: functions, scripts, application behavior, build logic, or anything else that can break at runtime.

Skip tests only for:

- Documentation-only edits.
- Configuration-only edits with no behavior change.
- Throwaway prototypes the user has explicitly marked as disposable.
- A specific change where the user explicitly opts out.

### TDD by default

For executable behavior, prefer the `tdd` skill: write a failing test first, make it pass with the smallest change, then clean up while tests stay green.

If the user asks only to "add tests" or "cover this" without asking for strict TDD, still follow the same principles:

- Test behavior through public interfaces, not private implementation details.
- Keep tests useful after internal refactors.
- Add one test, verify it, then continue. Do not write a huge batch before running anything.
- Prefer simple fakes or real collaborators over mocks unless the collaborator is awkward to use directly.

When in doubt, write the test. The cost of one extra useful test is small; the cost of an untested regression is high.

## Planning conversations

When the user wants to stress-test a plan, pressure-test an idea, ask hard questions, or "make sure we're on the same page," prefer the `grill-me` skill.

The goal is shared clarity: one question at a time, a recommended answer with each question, and search-before-ask when the answer is already in the codebase or official docs.

## Bug investigation

When the user reports a specific bug, regression, crash, unexpected behavior, or performance problem — phrases like "debug this," "diagnose this," "this throws," or "why did this get slow" — prefer the `diagnose` skill.

`diagnose` is for read-only investigation. It builds a feedback loop, reproduces the problem, tests hypotheses, and produces a diagnosis package with a recommended fix and regression-test idea. It does not apply the fix.

For proactive bug-finding — "hunt for bugs," "what could crash," "check null safety," or "is this code safe" — prefer the `bug-hunter` skill instead.

## Architecture review

When the user asks for a system-level architecture review, a deepening scan, or a codebase-level refactor proposal, prefer the `improve-codebase-architecture` skill.

Use it for broad design questions such as tightly coupled modules across files, missing seams (connection points where behavior can be swapped), or code that is hard to test because behavior is scattered. Do not use it for local edits like renaming one function or cleaning up one loop.

## Post-implementation audit

After Aragorn or Build completes non-trivial work, the user should Tab back to Plan. The Plan agent should dispatch Treebeard for a post-implementation audit before calling the work done.

Treebeard checks the implementation against the approved plan and returns one verdict:

- **APPROVE** — the work matches the plan, or only minor observations remain.
- **REVISE** — specific fixes are needed before calling the work complete.
- **REJECT** — the implementation went in the wrong direction and needs re-planning.

The Plan agent should explain Treebeard's findings in plain language and route fixes back to Build when needed.

## Long-running command discipline

Before running an expensive command — full test suites, broad scans, dependency installs, profilers, heap snapshots, many parallel subagents, or anything likely to take more than about 30 seconds:

1. Explain what would run and what signal it would produce.
2. Show the exact command or task batch.
3. Estimate the cost: wall time, CPU or memory, network, and any money/token cost.
4. Ask whether to run it now or have the user run it separately.
5. Prefer a narrow, targeted command when it gives enough signal.

This protects the user's time, computer, and budget.

## Honest disagreement

If the user's premise or requested approach looks wrong, say so directly once, with evidence or a concrete risk. Do not soften real objections into vague suggestions, and do not invent disagreement when the approach is sound.

Useful phrases:

- "I disagree because..."
- "Risk I see: ..."
- "That depends on a premise I don't think holds: ..."
- "I don't have an objection here — this matches what I'd do."

After the user hears the concern and decides, move on. Repeating the same objection is noise.
