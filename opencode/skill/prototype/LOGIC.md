# Logic Prototype

A logic prototype is a tiny interactive terminal app that lets the user drive a state model by hand. Use it for business rules, state transitions, data shapes, and other ideas that look fine on paper but may feel wrong in real cases.

## When this is right

- "Does this state machine handle X then Y?"
- "Can this data model represent the weird case?"
- "I want to feel out the interface before writing production code."
- Anything where the user wants to press buttons and watch state change.

If the question is "what should this look like?" use [UI.md](UI.md) instead.

## Process

### 1. State the question

Before writing code, write one short paragraph in a comment or small README: what state model are we testing, and what question should the prototype answer?

### 2. Pick the language

Use the host project's language and tooling. If the project has no obvious runtime, ask the user.

### 3. Isolate the logic

Put the actual logic behind a small, pure interface — the part a caller must know to use it correctly. The terminal shell is throwaway; the logic might become real later.

Good shapes:

- A reducer: `(state, action) => nextState`.
- A state machine: explicit states and allowed transitions.
- A few pure functions over a plain data type.
- A small class or module when the logic owns internal state.

Keep I/O, prompts, and terminal rendering outside the logic module.

### 4. Build the smallest terminal UI

On each action, redraw one clear frame:

1. Current state, pretty-printed.
2. Available keyboard shortcuts.

Behavior:

1. Initialize one in-memory state object.
2. Read one key or line at a time.
3. Dispatch to a handler.
4. Re-render the full frame.
5. Loop until quit.

The full frame should fit on one screen.

### 5. Make it runnable in one command

Add a script to the existing task runner when practical. If there is no task runner, put the run command at the top of the prototype file or README.

### 6. Hand it over

Give the user the command. The valuable moments are "that should not be possible" or "I assumed this would behave differently." Those are idea bugs.

### 7. Capture the answer

When the question is answered, record the answer and delete or absorb the prototype.

## Anti-patterns

- Do not add tests to disposable prototype code.
- Do not connect it to a real database unless persistence is the question.
- Do not generalize beyond the one question.
- Do not mix terminal rendering into the logic module.
- Do not ship the terminal shell into production.
