# Search-before-ask

When a question has a knowable answer, find it instead of asking the user. The user's time is valuable, and source-of-truth evidence is more reliable than memory.

## Source hierarchy

Prefer sources in this order. Drop to the next only when the previous cannot answer.

### Tier 1 — Codebase and local context

The code is the highest-confidence source.

- Source files: functions, types, schemas, configs.
- Existing tests: they often encode intended behavior.
- Project docs and README files.
- Git history: recent commits and diffs can explain why something changed.
- Already-loaded conversation context.

### Tier 2 — Official documentation

The library, framework, language, or vendor's own docs.

- Official docs for the library or framework.
- Standard-library or language docs.
- Vendor API docs.

### Tier 3 — Generic web search

Use sparingly, mostly for ecosystem-state questions:

- Is a library still maintained?
- Is a feature deprecated?
- What current alternatives exist?

Avoid generic web search for exact API behavior or version-specific details when official docs or source code can answer.

## When to ask the user anyway

Ask the user when:

- The question is about intent or preference, not a fact.
- Searching would take longer than asking and is unlikely to find a reliable answer.
- The codebase has conflicting answers and you need the user's authority.
- You searched and found contradictory evidence.

## Reporting search results

When you searched, tell the user what you checked and what you found.

Example:

> "I checked `src/checkout.ts`; cancellation changes `status` and emits an event. Is that the cancellation you meant, or the billing one?"

Do not silently use a search result when the user may need to correct the scope.
