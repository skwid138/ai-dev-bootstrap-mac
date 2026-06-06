---
description: >-
  Read-only scan for crash risks and missing safety checks in Python, shell,
  JavaScript, and HTML script code. Argument is the file, folder, or feature to
  check. The command reports what it read, what it could not inspect, and what
  could fail; it never edits code.
---
Use the `bug-hunter` skill to scan the specified scope for crash risks and
missing safety checks.

**Default behavior:** Quick Scan mode — a broad sweep for obvious ways real
files, web replies, command output, saved state, or user input could make the
code crash or do the wrong thing.

**Modes:**
- Default (no flag): Quick Scan — broad, shallow
- `--mode data`: Outside Data Audit — focused on code that reads or parses
  outside data
- `--mode trace`: Deep Trace — fewer findings, strongest evidence chains

**Scope is required.** Examples:
- `/safer scripts/` — scan a folder
- `/safer helpers/load_feed.py` — scan one file
- `/safer web/index.html` — scan an HTML file and its script blocks
- `/safer "checkout helper"` — natural-language feature scope; the agent picks
  likely files

Findings are reported in plain bands:
- **Will crash** — a normal run can stop or leave the user stuck
- **Wrong results** — the code can finish but do the wrong thing
- **Could break later** — not proven broken today, but missing a safety check

Each finding includes:
- The exact file and line
- A short explanation showing how the bad value reaches that line
- A one-line fix suggestion
- A one-line test or manual check suggestion

The report always includes coverage: which files were read, which files were not
inspected, and which files were skipped because they are dependencies,
generated, or minified. A no-finding result only applies to the files that were
actually read.

This command **does not modify code.** It produces a report. If you want to
apply fixes, ask the agent to implement them after you've reviewed the report.

## When to use this

- Before shipping a helper, script, or small app you're not confident in
- When the user reports a crash you cannot reproduce
- After adding a new web request, file parser, command call, or saved-state read
- Periodically on the most-used parts of a project

## When NOT to use this

- For style or formatting issues
- For performance problems
- For full security audits
