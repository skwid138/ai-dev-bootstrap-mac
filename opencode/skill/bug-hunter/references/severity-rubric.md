# Severity Rubric

## Will crash

**Definition:** A normal user action can make the program throw an error, exit
early, hang without recovery, or leave the user stuck.

**Evidence required:**
- Complete evidence chain from outside data to failure site.
- The bad value is plausible in normal use, not contrived.
- No guard exists anywhere on the reachable path.

**Examples:**
- Python: `payload["user"]["name"]` when `user` can be missing.
- Python: `items[0]` when a web reply can return an empty list.
- Shell: `open "$project_dir"` when `project_dir` came from failed command
  output and may be empty.
- Shell: a pipeline fails but the next command still uses the missing file.
- JavaScript: `data.items[0].title` when `items` can be `null` or absent.
- JavaScript: `JSON.parse(text)` where `text` can be blank or invalid.

**Fix urgency:** Fix before the user relies on this path.

---

## Wrong results

**Definition:** The program can finish but show, save, delete, send, or decide
the wrong thing during normal use.

**Evidence required:**
- Evidence chain showing the incorrect behavior path.
- The triggering condition is plausible.
- No existing handling produces the correct behavior.

**Examples:**
- A missing lookup silently becomes an empty list, causing real items to be
  omitted from a report.
- A failed command prints an error message that gets saved as if it were real
  data.
- Two overlapping saves finish out of order, so older data overwrites newer
  data.
- A blank environment variable causes a script to write into the wrong folder.

**Fix urgency:** Fix in the current round of work if this path matters to the
user.

---

## Could break later

**Definition:** A missing guard is not proven to fail today, but it can become a
crash or wrong result if outside data changes, a sample file changes, or a new
caller reuses the code.

**Evidence required:**
- Show the unchecked use pattern.
- Explain the normal scenario where it would become a problem.
- State why it is not proven to fail today.

**Examples:**
- A key is always present in today's sample JSON, but the code has no fallback
  and the field is not guaranteed by the source.
- A list is always non-empty today, but empty is a normal future state.
- A helper can return `None`, but current callers happen to pass only happy-path
  inputs.
- A command output is unquoted and works for today's path, but would fail when a
  future path contains spaces.

**Fix urgency:** Fix when touching the code or before expanding the workflow.
