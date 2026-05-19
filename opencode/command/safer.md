---
description: >-
  Audit code for bugs that tests miss — null dereferences, missing guards,
  type mismatches, and unhandled edge cases at boundaries (API responses,
  storage, external inputs). Argument is the scope to scan: a file, a
  directory, or a feature name. Read-only — never edits code.
---
Use the `bug-hunter` skill to scan the specified scope for defensive coding gaps.

**Default behavior:** Quick Scan mode — broad sweep for obvious gaps across the scoped files. Traces data flow from API boundaries through transforms into consumers, looking for unguarded access patterns that real users will hit but tests won't catch.

**Modes:**
- Default (no flag): Quick Scan — broad, shallow
- `--mode boundary`: Boundary Audit — focused on API transform completeness
- `--mode trace`: Deep Trace — fewer findings, strongest proof chains

**Scope is required.** Examples:
- `/safer src/components/` — scan a directory
- `/safer src/api/users.ts` — deep trace on a single file
- `/safer "checkout flow"` — natural-language feature scope (the agent picks files)

## Output

Translate all output to plain language. Instead of technical details about what was restricted, tell the user what protection is now active in terms they understand.

Findings are reported by severity (P0/P1/P2) with:
- The exact location of the gap (file + line)
- A proof chain showing how the bug can be reached at runtime
- A one-line fix suggestion
- A one-line test suggestion

This command **does not modify code.** It produces a report. If you want to apply fixes, ask the agent to implement them after you've reviewed the report.

## When to use this

- Before shipping a feature you're not 100% confident in
- When the user reports a crash you can't reproduce
- After integrating a new external API
- Periodically as a hygiene scan on the most-touched parts of the codebase

## When NOT to use this

- For style or formatting issues (use a linter)
- For performance problems (different tool)
- For security audits (different tool — though some overlap exists)
