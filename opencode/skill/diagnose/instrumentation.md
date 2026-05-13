# Instrumentation

Instrumentation means adding or using probes that show what the program is doing. Good probes produce signal without creating noise.

## Tag temporary debug logs

Use a unique prefix per investigation, for example `[DEBUG-a4f2]`.

Why:

- Cleanup is one search.
- Real project logs are not accidentally removed.
- Two investigations do not collide.

Before handoff, search for the tag and remove every temporary probe that is not part of the final regression test.

## One variable at a time

Each probe should test one prediction from one hypothesis. A probe can be useful for more than one hypothesis, but it should be designed for a clear reason.

Avoid "log the whole subsystem and see what looks odd." That produces too much output and makes the conclusion weak.

## Tool preference

1. **Debugger or REPL inspection** when the language and environment support it.
2. **Existing observability** such as structured logs, traces, metrics, and test output.
3. **Targeted temporary logs** at seams (connection points) that distinguish hypotheses.

## Performance probes

Logs are usually the wrong tool for performance bugs because they change timing and hide CPU/memory details.

Instead:

1. Baseline first: timing harness, browser performance trace, profiler, query plan, or similar.
2. Change one variable.
3. Measure again.
4. Compare to the baseline.

Common performance seams to measure:

- Hot loops: wall time per iteration and allocations.
- Database queries: query plan, query count, payload size.
- Network calls: count, latency, payload size.
- Render paths: layout/paint counts and long tasks.
- Startup paths: module load and initialization time.

Profilers and heap snapshots can be expensive. Explain, estimate, and ask before running them.

## State mutation is out of bounds

This skill does not restart services, reset databases, change config, or modify production state. If a probe needs one of those actions:

1. Stop.
2. Explain exactly what change is needed and why.
3. Let the user decide whether to do it themselves, open a write-capable session, or skip that path.

## Cleanup checklist

Before declaring the diagnosis complete:

- [ ] Temporary `[DEBUG-...]` instrumentation removed.
- [ ] Throwaway harnesses deleted or clearly marked as disposable scratch.
- [ ] Captured fixtures either preserved as test fixtures or removed.
- [ ] No probe-only changes left in the working tree.
