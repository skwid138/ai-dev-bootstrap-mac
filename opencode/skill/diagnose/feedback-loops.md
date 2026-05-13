# Feedback Loops

A feedback loop is a fast, repeatable pass/fail signal. It answers: "does the bug still happen?" Good diagnosis starts here.

## Ten ways to build one

Try these roughly in order:

1. **Failing test** at the seam (connection point) that reaches the bug: unit, integration, or end-to-end.
2. **HTTP script** against a dev server, using a captured request or small fixture.
3. **CLI invocation** with fixture input, comparing output to what should happen.
4. **Headless browser or browser automation** for UI bugs: drive the page and assert on DOM, console, or network behavior.
5. **Replay a captured trace**: saved request, event log, or payload replayed through the code path.
6. **Throwaway harness**: a tiny script that calls the suspected code path with one clear input.
7. **Property or fuzz loop** for "sometimes wrong" output. Anything beyond about 100 iterations needs long-running command discipline.
8. **Bisection harness** when the bug appeared between two known versions. Estimate range × per-step cost before running.
9. **Differential loop**: run the same input through old vs new code, or config A vs config B, and compare.
10. **Human-in-the-loop script** as a last resort: give the user exact steps to click or record, then use the captured result.

## Improve the loop itself

Once you have a loop, ask:

- **Can it be faster?** Cache setup, skip unrelated initialization, narrow the command.
- **Can it be sharper?** Assert the exact failure mode, not just "didn't crash."
- **Can it be more deterministic?** Pin time, seed randomness, isolate files, freeze network.

A slow or flaky loop taxes every later step. Improve it before relying on it.

## Intermittent bugs

For intermittent bugs, the goal is a higher reproduction rate, not a perfect reproduction. Loop the trigger, add stress, narrow timing windows, and collect enough failures to compare hypotheses.

If raising the reproduction rate requires broad loops or heavy tooling, explain the cost and ask before running.

## When no loop is possible

Stop and say so explicitly. List what you tried and ask for one useful missing piece:

- Access to the environment where it happens.
- A captured artifact: log dump, trace, HAR file, core dump, screen recording, or exact input.
- Permission for someone with write access to add temporary instrumentation.

Do not continue with confident-sounding guesses when there is no feedback loop.
