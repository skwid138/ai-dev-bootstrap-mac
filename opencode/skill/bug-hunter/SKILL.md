---
name: bug-hunter
description: >-
  Read-only, evidence-based scanner for crash risks and missing safety checks in
  Python, shell, JavaScript, and HTML script code. Use when the user asks to
  "make this safer", "find crashes", "check for missing guards", "audit
  defensive coding", "find runtime errors", "what could crash", "is this code
  safe", or any request to proactively find bugs that tests may not catch.
---

# Bug Hunter

Proactively find bugs that tests miss by following outside data from where it
enters a program to where the program uses it. The target code is practical
Mac-project code: Python helpers, shell scripts, JavaScript, and JavaScript
inside HTML files.

> **Core insight:** The most dangerous crash bugs often live where the program
> trusts something it did not create: a web reply, file contents, command
> output, saved state, environment variable, or user input. Tests usually use
> neat sample data, but real files and replies can be missing keys, contain
> `null`, be empty, be invalid JSON, or arrive late. This skill looks for the
> missing checks between that outside data and the line that can crash or do the
> wrong thing.

## When to use this skill

- "Make this script safer"
- "What could crash in this folder?"
- "Check if this handles missing fields in a JSON reply"
- "Find missing checks around file reads or command output"
- "Audit the defensive coding in this helper"
- "Is this code safe against malformed data?"
- "What happens if this web request returns nothing?"
- "Find unguarded property or dictionary access"
- "Proactively find bugs in this project"
- Any request to find crash risks that tests may not catch

Do **not** use this skill for:
- General code review or style feedback
- Bugs already tied to a specific report that need diagnosis first
- Performance analysis
- Security audits focused on authentication, secrets, injection, or privilege
  issues. This skill finds crash and wrong-result risks, not full security
  coverage.

## Plain-language glossary

- **Outside data** — anything the program did not create itself: web replies,
  files, saved state, command output, environment variables, or user input.
- **Guard** — a check or default that handles missing, empty, invalid, or late
  data before the program uses it.
- **Crash site** — the exact line that can throw an error, exit early, or stop
  the user's work.
- **Coverage contract** — the report must say what was read and what was not
  read. Never imply the whole project is safe when some files were not
  inspected.

## Modes

| Mode | Flag | Best for | Scan depth |
|------|------|----------|-----------|
| **Quick Scan** (default) | none | A folder or small project | Broad, shallow — obvious crash risks |
| **Outside Data Audit** | `--mode data` | Code that reads files, web replies, command output, or saved state | Checks how outside data is cleaned before use |
| **Deep Trace** | `--mode trace` | One file or one data path | Fewer findings, strongest evidence chains |

If the user's intent is ambiguous, default to **Quick Scan**.

## Input parsing

| Format | Example | Handling |
|--------|---------|---------|
| Directory | `/safer scripts/` | Scan supported code files in the directory |
| File | `/safer app.py` | Deep trace on a single supported file |
| Feature name | `/safer "invoice helper"` | Resolve to likely project files, then scan |
| Outside-data focus | `/safer --mode data helpers/fetch_weather.py` | Focus on data intake and cleanup |
| Deep trace | `/safer --mode trace web/index.html` | Trace one file or one data path |
| Diff scope | `/safer --scope diff` | If git history exists, scan changed supported files; otherwise explain that diff mode is not useful and scan the requested folder or current folder instead |
| No argument | `/safer` | Gandalf asks the user which file or folder to check |

**Scope is required.** If no scope is provided, Gandalf asks the user for a
file or folder in plain language. Subagents must not ask the user directly;
they return the missing-scope blocker to Gandalf.

Optional flags:

| Flag | Default | Purpose |
|------|---------|---------|
| `--mode <mode>` | `quick` | Scan mode (`quick`, `data`, `trace`) |
| `--scope diff` | none | Scan changed files when git history is available; inert in non-git folders |
| `--max-files <N>` | 30 | Cap on supported code files to inspect |
| `--detectors <list>` | all | Comma-separated detector subset |

## Preflight

1. **Resolve the project folder without assuming git exists.**
   - Try `git rev-parse --is-inside-work-tree` only as an optional hint.
   - If it fails, continue with the folder the user provided, or the current
     folder when `--scope diff` was the only scope.
   - For non-git folders with `--scope diff`, state plainly: "This folder does
     not have change history yet, so diff mode cannot tell what changed. I
     scanned `<scope>` instead. Next time, use `/safer <folder>` for this kind
     of project."
2. **Enumerate every file in scope before judging anything.** Partition each
   file into exactly one bucket:
   - `scanned`: supported code files that were read by the crash detectors.
   - `skippedUnsupported`: files the crash detectors do not inspect. This
     includes data/config files such as JSON, plist, YAML, TOML, INI, CSV, and
     `.env`, plus unsupported code languages.
   - `skippedExcluded`: dependency, generated, cache, build, coverage, binary,
     and minified files intentionally excluded from analysis.
3. **Supported code files for crash detection:**
   - Python: `.py`, `.pyw`
   - Shell: `.sh`, `.bash`, `.zsh`, `.fish`, `.command`
   - JavaScript: `.js`, `.mjs`, `.cjs`
   - HTML with script blocks: `.html`, `.htm`
4. **Exclude noisy or unsafe-to-read bulk folders/files:**
   - Dependency/cache/build folders: `.git`, `node_modules`, `.venv`, `venv`,
     `env`, `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`,
     `dist`, `build`, `coverage`, `.next`, `.cache`, `vendor`.
   - Generated/minified files: `*.min.js`, generated bundles, lockfiles, binary
     assets, images, videos, archives, databases.
5. **Cap huge lists honestly.** In reports, list at most 50 skipped files per
   bucket and summarize the rest as "and N more". The machine-readable block
   must include the same capped list plus the hidden count.
6. **Respect the scan cap without hiding uninspected code.** If supported code
   files exceed `--max-files`, do not silently skip the overflow. Return a
   coverage-only blocker to Gandalf: say how many supported files were found,
   show the first files by relevance, and ask Gandalf to request a narrower
   folder or a higher limit.

## Phase 1 — Coverage Map

**Goal:** Build the coverage contract before any findings.

Record:

- `scanned`: every supported code file actually read.
- `skippedUnsupported`: every file not inspected because these detectors cannot
  reason about it. For data/config files, include this exact warning in the
  human report: **"I didn't inspect these; a typo in them can still break
  things."**
- `skippedExcluded`: every dependency/generated/minified file omitted to keep
  the scan useful.
- `coverageSummary`: counts for all buckets and capped display lists.

The coverage contract appears in the report header and in the JSON block.

## Phase 2 — Outside Data Map

**Goal:** Identify where outside data enters the scanned code and where it is
used.

Delegate read-only exploration to **legolas** with this prompt structure:

> Explore the codebase at the specified scope to build an outside-data map.
>
> **Scope:** `<resolved scanned file paths>`
>
> **Coverage:** include the scanned, skippedUnsupported, and skippedExcluded
> file lists provided by the preflight. Do not inspect skipped files.
>
> Find and return a structured summary of:
>
> 1. **Outside data entry points** — web requests, `fetch`, `axios`, `requests`,
>    `urllib`, file reads, JSON parsing, plist reads, environment variables,
>    command output, form/input values, local storage, and saved state. For each:
>    file path, line number, function/script name, and what shape the code seems
>    to expect.
>
> 2. **Places that use that data** — dictionary/key access, property access,
>    indexing, loops, method calls, arithmetic, string operations, shell variable
>    expansion, path building, and command arguments. For each: file path, line
>    number, expression, and whether a guard exists nearby.
>
> 3. **Cleanup/defaulting path** — where the code validates, defaults, catches,
>    retries, or normalizes outside data before use. Note values that pass
>    through unchanged.
>
> 4. **Runtime expectations** — comments, annotations, examples, sample files,
>    tests, or naming that show whether a value is expected to be required,
>    optional, list-like, object-like, string-like, numeric, or non-empty.
>
> 5. **Existing guards** — checks for missing keys, `None`, `null`, `undefined`,
>    empty strings, empty arrays, failed commands, failed parses, bad status
>    codes, and timeouts.
>
> Return ONLY a structured summary. Include file paths and line numbers. Do not
> return raw file contents. Do not ask the user questions; return blockers or
> ambiguity to Gandalf.

## Phase 3 — Trace & Prove

**Goal:** For each outside-data path, prove whether a missing guard can cause a
crash, wrong result, or future fragility.

### Detector categories

Run these detectors against the outside-data map. Read
`references/detector-rules.md` for detailed heuristics.

#### 1. Missing Value Crash (`MissingValueCrash`)
- Python: `data["user"]["name"]`, `items[0]`, `.get(...).strip()`, or
  `response.json()["items"]` without handling missing keys, `None`, empty
  lists, bad status codes, or invalid JSON.
- Shell: unquoted or unset variables, unchecked command output, `jq` results
  used as paths or arguments, or pipelines where an earlier failure is ignored.
- JavaScript/HTML: `data.user.name`, `items[0].title`, `value.trim()`,
  `JSON.parse(...)`, or `await response.json()` without handling missing,
  `null`, invalid, or failed replies.
- **Proof required:** Show the outside value can be missing/bad, no guard exists,
  and the exact line can crash or exit.

#### 2. Runtime Shape Mismatch (`RuntimeShapeMismatch`)
- Code comments, annotations, examples, or variable names say a value is a
  string/list/object/number, but outside data can arrive as `None`, `null`, an
  empty string, an empty list, a different object shape, or invalid JSON.
- **Proof required:** Show the expected shape and evidence the runtime shape can
  differ.

#### 3. Guard Gap (`GuardGap`)
- One path checks a value, but another path uses the same value unchecked.
- A function returns `None`, an empty string, or an error marker, and the caller
  assumes success.
- A shell script checks one command but not the next command whose output is
  used the same way.
- **Proof required:** Show both the guarded path and the unguarded path for the
  same value or same kind of value.

#### 4. Hidden Assumption (`HiddenAssumption`)
- Code assumes a list is non-empty, an object has a key, a string contains a
  delimiter, a command prints a path, or a file exists.
- **Proof required:** Show the assumption and a plausible normal scenario where
  it fails.

#### 5. Async or Timing Failure (`AsyncFailure`)
- Promise, task, timer, subprocess, or network work has no error handling,
  timeout, cancellation, or stale-result protection.
- Shell background jobs or pipelines can fail without stopping the script.
- **Proof required:** Show the async/timing code and the missing error,
  timeout, cancellation, or ordering path.

### Evidence standard

**A finding is valid only if the agent can show all of:**
1. **Outside data can yield the problematic value** — evidence from a web
   response, file parse, command output, saved state, comments, examples, tests,
   or neighboring guards.
2. **No guard exists** on the path from outside data to use.
3. **Crash or wrong-result site** — the specific line that fails or produces the
   wrong result.
4. **Reachability** — a plausible way the user runs the code and reaches that
   line.

If any link in the chain is uncertain, downgrade to **Could break later** or
move it to **Notes**.

### Delegation

For **Quick Scan** and **Outside Data Audit**: delegate trace work to a single
**legolas** agent with the coverage map and outside-data map as input.

For **Deep Trace**: delegate to **legolas** for evidence gathering, then produce
the final synthesis from that evidence. Do not ask subagents to prompt the user;
they return ambiguity or blockers to Gandalf.

## Phase 4 — Classify & Deduplicate

Assign severity per `references/severity-rubric.md`:

| Severity | Criteria | Example |
|----------|----------|---------|
| **Will crash** | A normal run can stop, throw, exit, or leave the user stuck | `data["items"][0]` when the reply omits `items` |
| **Wrong results** | A normal run can finish but show, save, delete, or send the wrong thing | Empty fallback hides a failed lookup and saves blank data |
| **Could break later** | A missing guard is not failing today but can become a crash or wrong result when outside data changes | Optional field has no fallback because today's sample always includes it |

Assign confidence:

| Confidence | Criteria |
|------------|----------|
| **High** | Complete evidence chain with concrete files and lines |
| **Medium** | Evidence chain with one clearly labeled inference |

Do not emit low-confidence findings. If confidence is low, move it to
**Notes** as an area to investigate.

**Deduplicate by root cause.** If the same missing check causes five crash
sites, report one finding with the root cause and list all affected sites.

## Phase 5 — Report

### Mandatory coverage wording

Every report begins with a coverage contract. It must never use a bare pass
message. Use this shape:

```markdown
## Safer Scan Report: <scope>

**Mode:** <quick|data|trace>
**Files read:** <N>
**Files I could not inspect:** <M> — <capped list, or "none">
**Files skipped as dependencies/generated/minified:** <K> — <capped list, or "none">
**Findings:** <Will crash count> will crash, <Wrong results count> wrong results, <Could break later count> could break later

**Verdict:** I read <N> files. I could not inspect these <M> files: <capped list, or "none">. In what I read, I found <summary>.

For data/config files: I didn't inspect these; a typo in them can still break things.
```

If there are no findings, the verdict summary must be exactly:

```text
no crash risks
```

That means the full no-finding verdict is:

```text
I read <N> files. I could not inspect these <M> files: <list or none>. In what I read, I found no crash risks.
```

This is a statement about inspected files only. It is not a claim about skipped
or unsupported files.

### Finding format

```markdown
### Will crash

#### BH-<Type>-<N>: <one-line summary>

**Severity:** Will crash | **Confidence:** High | **Type:** <detector category>
**Location:** `<file>:<line>`

**Evidence chain:**
1. **Outside data:** `<source>` can return/provide `<bad value>` — `<file>:<line>`
2. **Missing guard:** `<function/script>` does not handle `<bad value>` — `<file>:<line>`
3. **Use site:** `<expression>` uses the value — `<file>:<line>`
4. **Failure:** `<expression>` throws, exits, or stops the task when value is `<bad value>` — `<file>:<line>`

**Runtime scenario:** <concrete description of when this happens>

**Fix suggestion:** <one-line fix that matches the codebase pattern>

**Test suggestion:** <one-line test or manual check using the bad value>

---

### Wrong results

<same format per finding>

---

### Could break later

<same format per finding>

---

### Notes

<uncertain findings, areas to investigate, patterns observed>
```

### Machine-readable block

After the markdown report, emit a fenced JSON block for composition with other
skills:

````markdown
```json:bug-hunt-findings
{
  "meta": {
    "mode": "<mode>",
    "scope": "<scope>",
    "filesEnumerated": <N>,
    "filesScanned": <N>,
    "filesUninspected": <N>,
    "filesSkippedExcluded": <N>,
    "coverageVerdict": "I read <N> files. I could not inspect these <M> files: <list or none>. In what I read, I found <summary>.",
    "uninspectedWarning": "I didn't inspect these; a typo in them can still break things."
  },
  "coverage": {
    "scanned": ["<path>"],
    "skippedUnsupported": {
      "count": <N>,
      "files": [
        { "path": "<path>", "reason": "data/config file not inspected by crash detectors" }
      ],
      "andMore": <N>
    },
    "skippedExcluded": {
      "count": <N>,
      "files": [
        { "path": "<path>", "reason": "dependency/generated/minified" }
      ],
      "andMore": <N>
    }
  },
  "findings": [
    {
      "id": "BH-MissingValueCrash-001",
      "type": "MissingValueCrash",
      "severity": "Will crash",
      "confidence": "High",
      "location": { "file": "<path>", "line": <N> },
      "chain": [
        { "step": "outsideData", "file": "<path>", "line": <N>, "detail": "<desc>" },
        { "step": "missingGuard", "file": "<path>", "line": <N>, "detail": "<desc>" },
        { "step": "useSite", "file": "<path>", "line": <N>, "detail": "<desc>" },
        { "step": "failure", "file": "<path>", "line": <N>, "detail": "<desc>" }
      ],
      "fix": "<one-line fix description>",
      "test": "<one-line test description>"
    }
  ]
}
```
````

## Stretch goals (opt-in, not implemented in v1)

These are hooks for future enhancement. Do not implement them unless the user
explicitly requests.

### Fix plan output (`--emit fix-plan`)
- Generate a plan with files to modify and changes to make.
- Does not apply the fix — outputs the plan for review.
- User can then ask Aragorn to implement.

### Fix mode (`/safer-fix`)
- Separate future command that takes findings and applies fixes.
- Delegates to Aragorn for implementation.
- Runs relevant checks after each fix to verify no regressions.

## Guardrails

1. **Read-only by default.** This skill never modifies code, creates files,
   commits, or pushes. It only reads and reports.
2. **Coverage before confidence.** Always enumerate files and show scanned,
   unsupported, and excluded buckets before making claims.
3. **No bare pass messages.** Even when no findings exist, the verdict must say
   how many files were read and which files were not inspected.
4. **Evidence threshold.** No **Will crash** or **Wrong results** finding
   without a complete evidence chain. Speculation goes in Notes, not findings.
5. **Scan radius cap.** Default 30 supported code files. If the scope is larger,
   return a blocker to Gandalf rather than silently skipping supported code.
6. **Prefer fixing at intake.** The best fix is usually where outside data first
   enters or is parsed, not scattered checks at every later use.
7. **Don't fabricate.** If you cannot find evidence for a link in the chain,
   say so and move the item to Notes with what you do know.
8. **Respect codebase patterns.** Fix suggestions must match existing
   conventions, such as `dict.get`, `set -u`, `|| exit`, `?? []`, or existing
   project helper functions.
9. **No scope creep.** Only report bugs within the specified scope. Do not
   follow imports beyond one hop unless in Deep Trace mode.
10. **Question routing.** If a choice or clarification is needed, return it to
    Gandalf. Do not introduce a subagent step that asks the user directly.

## Error handling

| Situation | Action |
|-----------|--------|
| Scope resolves to 0 files | Report the coverage contract with 0 files read, list any unsupported/excluded files found, and say: "I did not find supported code files at `<scope>`. Ask Gandalf to choose a Python, shell, JavaScript, or HTML file or folder." |
| Scope exceeds max-files | Return a coverage-only blocker to Gandalf: "I found <N> supported code files, which is over the <max> file scan limit. Ask Gandalf to narrow the folder or approve `--max-files <N>`." |
| Non-git folder with `--scope diff` | Continue by scanning the requested folder or current folder. State that diff mode cannot tell what changed without git history and suggest `/safer <folder>` next time. |
| No outside-data entry points found | Still emit the coverage contract. Say: "I read <N> files. I could not inspect these <M> files: <list or none>. In what I read, I found no crash risks." Add a note that the scanned files did not appear to read outside data. |
| No findings | Emit the required coverage verdict: "I read <N> files. I could not inspect these <M> files: <list or none>. In what I read, I found no crash risks." |

## Reference files

- `references/severity-rubric.md` — Detailed severity definitions with examples
- `references/fix-patterns.md` — Common fix patterns organized by detector type
- `references/detector-rules.md` — Heuristics for each detector category
- `references/examples.md` — A language-neutral walkthrough using HTML and Python
