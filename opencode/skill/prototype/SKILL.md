---
description: >-
  Build a throwaway prototype to answer a design question before committing to
  production code. Routes between two branches: a small terminal app for logic
  or state-model questions, or several UI variations switchable from one route.
  Use when the user says "prototype this", "mock this up", "let me play with
  it", "try a few designs", or wants to sanity-check an idea quickly.
---

# Prototype

A prototype is **throwaway code that answers a question**. The question decides the shape.

## Pick a branch

Identify what the user needs to learn:

- **"Does this logic or state model feel right?"** → [LOGIC.md](LOGIC.md). Build a tiny interactive terminal app so the user can press keys and watch state change.
- **"What should this look like?"** → [UI.md](UI.md). Build several clearly different UI variations, switchable from one page.

If the question is ambiguous and the user is unavailable, choose the branch that matches the surrounding code: backend or data model → logic; page or component → UI. State the assumption at the top of the prototype.

## Rules for both branches

1. **Throwaway from day one.** Name files so a casual reader can see they are prototypes, not production.
2. **One command to run.** Use the project's existing task runner. Do not add a package manager or runtime just for the prototype.
3. **No persistence by default.** Keep state in memory unless persistence is the question being tested.
4. **Skip polish.** No production-grade error handling, abstractions, or tests. The point is to learn quickly.
5. **Surface the state.** Show the relevant state after every action or variant switch.
6. **Delete or absorb when done.** Fold the winning idea into real code, or delete the prototype.
7. **Confirm scope before creating files.** State the question, target location, and files to create unless the user explicitly said to proceed.

## Long-running commands

Dev servers, watchers, and builds can be expensive. Before starting anything likely to run more than about 30 seconds, explain the command, what signal it gives, the expected cost, and ask whether to run it now.

## Testing policy

Prototype code is disposable and does not need tests. If the user decides to keep the idea, rewrite or promote it as production code with normal tests.

## When done

The answer is the only thing worth keeping. Capture what the prototype taught in the conversation, a commit message, or a small note next to the prototype. Remind the user to delete or absorb the prototype.

## References

- [LOGIC.md](LOGIC.md) — terminal prototypes for state and business logic
- [UI.md](UI.md) — UI variation prototypes for layout and interaction decisions
