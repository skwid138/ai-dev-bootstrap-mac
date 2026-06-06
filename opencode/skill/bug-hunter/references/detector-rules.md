# Detector Rules

Heuristics for each detector category. These rules define what counts as
evidence and what should be left as a note.

---

## MissingValueCrash

**What to look for:**
1. Python values from `requests`, `urllib`, file reads, `json.load`, plist reads,
   environment variables, or command output used without checking status,
   parse success, missing keys, `None`, empty lists, or empty strings.
2. Shell values from command substitution, `jq`, `grep`, environment variables,
   positional arguments, temp files, or pipelines used without checking exit
   status, emptiness, quoting, or unset variables.
3. JavaScript values from `fetch`, `axios`, `JSON.parse`, form fields, local
   storage, query strings, or file input used without checking failed replies,
   parse errors, missing properties, `null`, `undefined`, or empty arrays.
4. The gap: outside data is used in a way that can throw, exit, or stop the
   user's task, and no guard exists on the path.

**Strong evidence (High confidence):**
- Nearby code guards one field from the same outside source but not the field
  that later crashes.
- Code directly does nested access such as `payload["user"]["name"]`,
  `data.user.name`, `items[0].title`, or `result.strip()` where the earlier
  value can be missing.
- A command's output is used as a path or argument without checking that the
  command succeeded and printed a usable value.
- Multiple files use the same unchecked value.

**Weak evidence (move to Notes):**
- The value is only used after a guard elsewhere, but the control flow is hard
  to prove.
- The value appears to come from a fixed local constant, not outside data.
- The only evidence is a name like `required_*` with no examples or callers.

**False positive signals (skip):**
- The value is constructed locally and cannot be missing on the observed path.
- The code has a nearby early return, default, exception handler with safe
  fallback, status check, or key-existence check that covers the use.
- The failing operation is intentionally allowed to stop a private developer
  tool and the script prints a clear recovery message first.

---

## RuntimeShapeMismatch

**What to look for:**
1. Comments, examples, annotations, sample files, or variable names say a value
   should be a string, list, object, or number, but outside data can differ.
2. JSON/plist/YAML sample files where a field is optional in one sample and
   required by code in another place.
3. Python functions that return either a value or `None`/`False`/`{}` on error,
   with callers assuming only the success shape.
4. Shell helpers that print a value on success but print nothing or an error
   message on failure, with callers assuming the success shape.
5. JavaScript code that assumes a parsed value is an object/list without checking
   the parsed result.

**Strong evidence:**
- A parser or helper has an explicit failure return, and a caller does nested
  access without checking for that failure return.
- One sample file omits a key that code reads as required.
- A web status check is missing before parsing the body as the expected shape.
- Neighboring guards show the author knew the outside source can be incomplete.

**Weak evidence:**
- The value is documented by the same project as always present and all samples
  agree.
- The source is generated locally immediately before use.

---

## GuardGap

**What to look for:**
1. A value is guarded in one code path but not another.
2. Same key/property accessed with a safe fallback in one place and directly in
   another.
3. A function handles a bad input but its caller does not check the function's
   bad-output path.
4. A shell script checks one command's status but ignores a similar command
   whose output is used later.
5. JSON parsing is guarded in one helper but open-coded without a guard in a
   sibling helper.

**Strong evidence:**
- Same value, same file or feature, guarded on one line and unguarded on another.
- Same outside source has both a checked parse path and an unchecked parse path.
- A helper returns an empty default on failure, but a caller treats that default
  as real data and proceeds to write or delete something.

**Weak evidence:**
- The guarded and unguarded paths use different data sources.
- The unguarded path is only reachable after the guarded path succeeds.

---

## HiddenAssumption

**What to look for:**
1. `items[0]`, `parts[1]`, or equivalent without a length check.
2. `Object.keys(obj)[0]`, first-line parsing, or first-match logic without an
   empty check.
3. `split(delimiter)[1]` assuming the delimiter exists.
4. `.find(...)`, `.match(...)`, command substitution, or `grep` output used as
   if a match always exists.
5. Destructuring or unpacking with no defaults where outside data might not have
   those keys or positions.

**Strong evidence:**
- The array/object/string comes from outside data.
- No upstream check guarantees non-emptiness or a successful match.
- The access runs during normal user actions, not only in unreachable setup
  code.

**Weak evidence:**
- The array is constructed locally with fixed items.
- There is an earlier empty-state check on all paths.

---

## AsyncFailure

**What to look for:**
1. JavaScript promises or `async` functions with no error handling around a web
   request, parse, timeout, or save operation.
2. Python async tasks, subprocess calls, or network calls with no timeout,
   exception handling, or return-code check.
3. Shell background jobs, pipelines, or command groups where a failed earlier
   command does not stop later commands from using missing output.
4. Concurrent requests where an older result can overwrite a newer one.
5. Timers, callbacks, or long-running tasks that can update stale state after
   the user has moved on.

**Strong evidence:**
- A fire-and-forget task can fail without a visible error or fallback.
- A subprocess result is used without checking its exit code.
- Two normal user actions can start overlapping work, and the later result is
  not protected from being overwritten.
- A network call has no timeout and no recovery path.

**Weak evidence:**
- The operation is local, quick, and guarded by a surrounding helper that handles
  failures.
- The code intentionally logs and exits with a clear message in a private tool.

---

## General rules

### What counts as a guard
- Python: `if value is None`, `if key in data`, `dict.get` with a safe default,
  `try/except` with a real fallback, status-code checks, timeouts, length
  checks, `Path.exists()` before required reads, and early returns with clear
  messages.
- Shell: `set -u`, `set -e`, `set -o pipefail`, explicit `$?` checks, `|| exit`,
  `[[ -n "$value" ]]`, quoted variables, default expansion such as
  `${name:-default}`, and checks before using paths or destructive arguments.
- JavaScript: optional chaining, nullish coalescing, `if (value == null)`,
  `Array.isArray`, key checks, `try/catch` around parsing with fallback, status
  checks before parsing replies, timeouts, and cancellation/stale-result checks.

### What does not count as a guard
- A comment that says the value is always present.
- An annotation or cast that affects editor help but not runtime behavior.
- Being inside a catch block that only logs and then continues with bad data.
- A default that hides failure and causes wrong results later.
- A wrapper that catches an error but leaves the user with no clear next step.

### Evidence requirements by severity
- **Will crash:** all four links required: outside data, missing guard, use site,
  and reachable failure.
- **Wrong results:** at least three links required; one inference is allowed if
  it is clearly labeled.
- **Could break later:** at least two links required: unchecked use plus a
  plausible normal scenario.
