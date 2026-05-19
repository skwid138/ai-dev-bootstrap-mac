---
name: bug-hunter
description: >-
  Read-only, evidence-based scanner for defensive coding gaps at system
  boundaries. Traces runtime data flow from API responses, storage, and external
  inputs through transforms, selectors, and hooks into components to find
  null/undefined dereferences, type-reality mismatches, missing guards, and
  unhandled edge cases that unit tests and mutation testing miss. Use this skill
  whenever a user asks to "hunt for bugs", "find crashes", "check for null
  safety", "audit defensive coding", "find runtime errors", "what could crash",
  "is this code safe", "check API boundary safety", "find unguarded access",
  or any request to proactively find bugs in code that tests aren't catching
  — even if they don't explicitly say "bug hunt."
---

# Bug Hunter

Proactively find bugs that tests miss by tracing data flow from system
boundaries to crash sites. Focuses on the gap between what TypeScript types
promise and what runtime data actually delivers.

> **Core insight:** The most dangerous bugs live at system boundaries where
> external data enters the app. TypeScript types describe the *intended* shape,
> but APIs, storage, and user input can deliver anything. Tests use well-formed
> mocks that match the types, so the failing path is never exercised. Mutation
> testing can't help because there's no guard code to mutate — the bug is
> *missing* code. Only tracing the actual data flow from boundary to
> dereference site reveals these gaps.

## When to use this skill

- "Hunt for bugs in the creative audit feature"
- "What could crash in this component?"
- "Check if this code handles null API responses"
- "Audit the API boundary safety for this feature"
- "Find defensive coding gaps"
- "Is this code safe against malformed data?"
- "What happens if the API returns null here?"
- "Find unguarded property access"
- "Proactively find bugs in src/features/X"
- Any request to find bugs that tests aren't catching

Do **not** use this skill for:
- Reviewing code changes generally (use the normal Gandalf and Saruman review flow)
- Finding bugs reported in GitHub issues (use standard investigation)
- Performance analysis (use profiling tools)
- Security audits focused on auth/injection (this skill finds crash bugs, not
  security vulnerabilities specifically)

## Modes

| Mode | Flag | Best for | Scan depth |
|------|------|----------|-----------|
| **Quick Scan** (default) | none | Feature directory, broad sweep | Broad, shallow — obvious gaps |
| **Boundary Audit** | `--mode boundary` | RTK Query slice, API layer | Transform completeness, normalization |
| **Deep Trace** | `--mode trace` | Single component or data flow | Fewer findings, strongest proof chains |

If the user's intent is ambiguous, default to **Quick Scan**.

## Input parsing

| Format | Example | Handling |
|--------|---------|---------|
| Directory | `/bug-hunt src/features/creativeAudit/` | Scan all source files in directory |
| File | `/bug-hunt src/components/Table.tsx` | Deep trace on single file |
| Feature name | `/bug-hunt creativeAudit` | Resolve to feature directory |
| API slice | `/bug-hunt --mode boundary api:creativeAudit` | Find RTK Query slice, trace endpoints |
| Component | `/bug-hunt --mode trace TagsTable` | Resolve component, trace its data sources |
| Diff scope | `/bug-hunt --scope diff` | Analyze files changed from main |
| No argument | `/bug-hunt` | Error: scope is required |

**Scope is required.** If no scope is provided, ask the user to specify one.

Optional flags:

| Flag | Default | Purpose |
|------|---------|---------|
| `--mode <mode>` | `quick` | Scan mode (quick, boundary, trace) |
| `--max-files <N>` | 30 | Cap on files to scan (prevents runaway) |
| `--detectors <list>` | all | Comma-separated detector subset |

## Preflight

1. **Verify git context:**
   ```bash
   git rev-parse --is-inside-work-tree
   ```
2. **Resolve scope to concrete file paths:**
   - Directory: glob for `*.ts`, `*.tsx` (exclude test files, generated files)
   - Feature name: resolve to `src/features/<name>/`
   - Component name: grep for `export.*<Name>` to find the file
   - API slice: grep for RTK Query `injectEndpoints` or `createApi` with the
     slice name
   - Diff: `git diff main...HEAD --name-only -- '*.ts' '*.tsx'`
3. **Check file count against max-files.** If over limit, inform the user and
   ask to narrow scope or increase limit.

---

## Phase 1: Boundary Map

**Goal:** Identify all system boundaries in scope — places where external data
enters the application.

Delegate to **legolas** (explorer) with this prompt structure:

> Explore the codebase at the specified scope to build a boundary map.
>
> **Scope:** `<resolved file paths>`
>
> Find and return a structured summary of:
>
> 1. **API boundaries** — RTK Query endpoints, fetch calls, axios calls.
>    For each: the hook/function name, the `transformResponse` (if any),
>    and the TypeScript return type.
>
> 2. **Data consumers** — Components, hooks, and selectors that consume
>    the boundary data. For each: file path, how they access the data
>    (destructuring, property access, indexing).
>
> 3. **Transform chain** — The path from raw API response to final
>    consumer. Note where data is normalized, defaulted, or passed through
>    unchanged.
>
> 4. **Type definitions** — The TypeScript types/interfaces for the
>    boundary data. Note which fields are optional vs required, and
>    whether the types use `Partial`, nullable unions, or are fully
>    required.
>
> 5. **Existing guards** — Any null checks, optional chaining, nullish
>    coalescing, default values, or type narrowing already in place.
>
> Return ONLY a structured summary. Include file paths and line numbers.
> Do not return raw file contents.

---

## Phase 2: Trace & Prove

**Goal:** For each boundary, trace data flow to every consumer and identify
unguarded access patterns.

### Detector categories

Run these detectors against the boundary map. Read `references/detector-rules.md`
for detailed heuristics.

#### 1. Null/Undefined Dereference at Boundary (`NullDerefBoundary`)
- API response field typed as required but no normalization in transform
- Consumer accesses `obj.field.subfield` or `obj[key]` without guard
- **Proof required:** Show the transform does NOT guard the field AND the
  consumer does NOT guard before access

#### 2. Type-Reality Mismatch (`TypeRealityMismatch`)
- TypeScript type says `string` but API could return `null`
- Type says `T[]` but API could return `undefined`
- Type says required field but API documentation or patterns suggest optional
- **Proof required:** Show the type definition AND evidence the runtime value
  can differ (e.g., other fields in same response ARE guarded, suggesting
  awareness of the issue)

#### 3. Guard Gap (`GuardGap`)
- Some code paths guard against null for a value, but other paths using the
  same value don't
- `transformResponse` guards `results` but not `averageAssetScores` in the
  same response
- **Proof required:** Show the guarded path AND the unguarded path for the
  same data

#### 4. Implicit Assumption (`ImplicitAssumption`)
- Code assumes array is non-empty (`arr[0]`, `arr.length` without check)
- Code assumes object has specific key (`obj[dynamicKey]` without `in` check)
- Code assumes string is non-empty (used in template without fallback)
- **Proof required:** Show the assumption AND a plausible scenario where it
  fails

#### 5. Unhandled Async Edge Case (`UnhandledAsync`)
- Promise without catch in non-RTK-Query code
- State update after potential unmount (no cleanup in useEffect)
- Race condition between concurrent requests
- **Proof required:** Show the async code AND the missing error/cleanup path

### Evidence standard

**A finding is only valid if the agent can show ALL of:**
1. **Boundary can yield the problematic value** — evidence from transform gaps,
   API patterns, or type looseness
2. **No guard exists** on the path from boundary to dereference
3. **Crash or corruption site** — the specific line that would fail
4. **Reachability** — a plausible call path from boundary to crash site

If any link in the chain is uncertain, downgrade to P2 or move to Notes.

### Delegation

For **Quick Scan** and **Boundary Audit**: delegate trace work to a single
**legolas** agent with the boundary map as input.

For **Deep Trace**: delegate to **legolas** for evidence gathering, then
**saruman** for synthesis and deduplication.

---

## Phase 3: Classify & Deduplicate

Assign severity per `references/severity-rubric.md`:

| Severity | Criteria | Example |
|----------|----------|---------|
| **P0 — Crasher** | Will crash the app in production given a plausible API response | `tag.averageAssetScores[key]` when API returns null |
| **P1 — Likely Bug** | Will produce incorrect behavior but not crash | Filter returns wrong results due to missing guard |
| **P2 — Hardening** | Defensive gap that could become P0/P1 if data changes | No fallback for optional field, currently always populated |

Assign confidence:

| Confidence | Criteria |
|------------|----------|
| **High** | Complete proof chain with concrete evidence |
| **Medium** | Proof chain with one inferential step |

Do NOT emit Low confidence findings. If confidence is low, move to the
**Notes** section as an area to investigate.

**Deduplicate by root cause.** If the same missing normalization causes 5
crash sites, report ONE finding with the root cause and list all affected
sites.

---

## Phase 4: Report

### Output format

```markdown
## Bug Hunt Report: <scope>

**Mode:** <quick|boundary|trace>
**Files scanned:** <count>
**Boundaries found:** <count>
**Findings:** <P0 count> crashers, <P1 count> likely bugs, <P2 count> hardening

---

### P0 — Crashers

#### BH-<Type>-<N>: <one-line summary>

**Severity:** P0 | **Confidence:** High | **Type:** <detector category>
**Location:** `<file>:<line>`

**Proof chain:**
1. **Boundary:** `<endpoint/hook>` returns `<type>` — `<file>:<line>`
2. **Transform:** `<function>` guards `<field>` but NOT `<other field>` — `<file>:<line>`
3. **Consumer:** `<component/hook>` accesses `<expression>` — `<file>:<line>`
4. **Crash site:** `<expression>` throws when value is `<null|undefined>` — `<file>:<line>`

**Runtime scenario:** <concrete description of when this happens>

**Fix suggestion:**
```<language>
// In <file>, normalize at the boundary:
<code snippet>
```

**Test suggestion:** Mock `<field>` as `<null|undefined>` in the API response
and assert the component renders without throwing.

---

### P1 — Likely Bugs

<same format per finding>

---

### P2 — Defensive Hardening

<same format per finding>

---

### Notes

<uncertain findings, areas to investigate, patterns observed>
```

### Machine-readable block

After the markdown report, emit a fenced JSON block for composition with
other skills:

````markdown
```json:bug-hunt-findings
{
  "meta": {
    "mode": "<mode>",
    "scope": "<scope>",
    "filesScanned": <N>,
    "boundariesFound": <N>
  },
  "findings": [
    {
      "id": "BH-NullDerefBoundary-001",
      "type": "NullDerefBoundary",
      "severity": "P0",
      "confidence": "High",
      "location": { "file": "<path>", "line": <N> },
      "chain": [
        { "step": "boundary", "file": "<path>", "line": <N>, "detail": "<desc>" },
        { "step": "transform", "file": "<path>", "line": <N>, "detail": "<desc>" },
        { "step": "consumer", "file": "<path>", "line": <N>, "detail": "<desc>" },
        { "step": "crash", "file": "<path>", "line": <N>, "detail": "<desc>" }
      ],
      "fix": "<one-line fix description>",
      "test": "<one-line test description>"
    }
  ]
}
```
````

---

## Stretch goals (opt-in, not implemented in v1)

These are hooks for future enhancement. Do NOT implement them unless the user
explicitly requests.

### PR creation (`--emit pr-plan`)
- Generate a commit plan with files to modify and changes to make
- Does NOT create the PR — outputs the plan for review
- User can then ask Aragorn to implement

### Fix mode (`/bug-hunt-fix`)
- Separate command that takes bug-hunt findings and applies fixes
- Delegates to Aragorn for implementation
- Runs tests after each fix to verify no regressions

---

## Guardrails

1. **Read-only by default.** This skill never modifies code, creates files,
   commits, or pushes. It only reads and reports.
2. **Evidence threshold.** No P0 or P1 finding without a complete proof chain.
   Speculation goes in Notes, not in findings.
3. **Scan radius cap.** Default 30 files. Require explicit opt-in to expand.
   This prevents runaway analysis and keeps findings focused.
4. **Prefer normalization over scattered guards** in fix suggestions. The best
   fix is usually at the boundary (transformResponse, selector), not at every
   consumer.
5. **Don't fabricate.** If you can't find evidence for a link in the proof
   chain, say so. Move the finding to Notes with what you do know.
6. **Respect codebase patterns.** Fix suggestions must match existing
   conventions (e.g., if the codebase uses `?? []` for array defaults, suggest
   that pattern, not a different one).
7. **No scope creep.** Only report bugs within the specified scope. Don't
   follow imports beyond 1 hop unless in Deep Trace mode.

## Error handling

| Error | Action |
|-------|--------|
| Scope resolves to 0 files | "No source files found at `<scope>`. Check the path." |
| Scope exceeds max-files | "Found <N> files, limit is <max>. Narrow scope or use `--max-files <N>`." |
| No boundaries found in scope | "No API boundaries found in scope. This skill works best on code that consumes external data. Try a broader scope or use `--mode trace` on a specific component." |
| No findings | Report "No defensive coding gaps found in <scope>." with a brief summary of what was checked. |

## Reference files

- `references/severity-rubric.md` — Detailed P0/P1/P2 definitions with examples
- `references/fix-patterns.md` — Common fix patterns organized by detector type
- `references/detector-rules.md` — Heuristics for each detector category
- `references/examples.md` — The `averageAssetScores` case as a canonical walkthrough
