# Severity Rubric

## P0 — Crasher (Must Fix)

**Definition:** Will crash the application in production given a plausible
runtime scenario. The crash path is reachable through normal user interaction
or normal API behavior.

**Evidence required:**
- Complete proof chain from boundary to crash site
- The boundary value that triggers the crash is plausible (not contrived)
- No guard exists anywhere in the chain

**Examples:**
- `obj.field[key]` where `field` can be `null` from API → TypeError
- `arr.map(fn)` where `arr` can be `undefined` from API → TypeError
- `JSON.parse(str)` where `str` can be `undefined` → SyntaxError
- Component renders `{obj.a.b.c}` where any intermediate can be null

**Fix urgency:** Before next deploy. These are production crash risks.

---

## P1 — Likely Bug (Should Fix)

**Definition:** Will produce incorrect behavior, data corruption, or degraded
UX but will not crash the application. The bug is reachable through normal
usage.

**Evidence required:**
- Proof chain showing incorrect behavior path
- The triggering condition is plausible
- No existing handling produces correct behavior

**Examples:**
- Filter silently returns wrong results because guard returns `[]` instead of
  filtering correctly
- Stale closure captures old value, causing UI to show outdated data
- Race condition between two requests causes data from request A to overwrite
  request B's results
- Missing error boundary causes parent component to show blank instead of
  error state

**Fix urgency:** Current sprint. These degrade user experience.

---

## P2 — Defensive Hardening (Consider)

**Definition:** A defensive coding gap that is not currently causing issues
but could become P0 or P1 if API behavior changes, data volume grows, or
new code paths are added.

**Evidence required:**
- Show the unguarded access pattern
- Explain the scenario where it would become a problem
- Note why it's not currently triggering (e.g., "API always returns this
  field today, but it's not documented as required")

**Examples:**
- Optional field that's always populated today but has no fallback
- Array assumed non-empty that happens to always have items
- Error path that returns `undefined` instead of a meaningful default
- Component that works because parent always provides props, but the type
  allows `undefined`

**Fix urgency:** Next cleanup pass. Low risk today, insurance for tomorrow.
