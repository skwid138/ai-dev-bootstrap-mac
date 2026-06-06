# Canonical Example: Missing Items Crash

This example shows the kind of crash this skill is designed to catch in a small
mixed project: an HTML page with JavaScript and a Python helper.

---

## The bug

**Symptom:** The page crashes or stays blank when a web service returns a
successful reply that does not include an `items` list.

**Root cause:** The Python helper passes along the reply without guaranteeing an
`items` list, and the HTML script reads the first item directly.

---

## Why tests missed it

1. **Sample data was too neat:** The test fixture always included
   `{"items": [{"title": "Example"}]}`.
2. **The missing-field path was never exercised:** No test used `{}`,
   `{"items": null}`, invalid JSON, or a failed request.
3. **The bug is missing code:** There is no guard to mutate or assert against;
   the unsafe path is just direct access to a value that real data may omit.

---

## The evidence chain

### 1. Outside data

**File:** `helpers/load_feed.py:8-12`

```python
def load_feed(url):
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    return response.json()
```

The helper checks that the request succeeded, but it does not check whether the
parsed JSON contains an `items` list.

### 2. Missing guard

**File:** `web/index.html:24-29`

```html
<script>
  const response = await fetch("/feed.json")
  const data = await response.json()
  document.querySelector("#title").textContent = data.items[0].title
</script>
```

The script does not check `response.ok`, whether JSON parsing succeeded, whether
`items` exists, or whether the list has at least one item.

### 3. Failure site

**File:** `web/index.html:27`

```javascript
data.items[0].title
```

If the reply is `{}` or `{"items": null}`, this throws because `items` is not a
usable list.

---

## The fix

**Preferred fix — make the web reply safe before use:**

```javascript
const response = await fetch("/feed.json")
if (!response.ok) throw new Error("Feed request failed")

const data = await response.json()
const items = Array.isArray(data.items) ? data.items : []
document.querySelector("#title").textContent = items[0]?.title ?? "No items yet"
```

**Alternative fix — make the helper guarantee a list:**

```python
def load_feed(url):
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    data = response.json()
    data["items"] = data.get("items") or []
    return data
```

The best location depends on where the project expects data to be cleaned. If
several files use the same feed, prefer the helper so every caller gets the same
safe shape.

---

## Bug hunt finding format

This is how bug-hunter would report this finding:

```markdown
#### BH-MissingValueCrash-001: Feed page assumes the reply always has items

**Severity:** Will crash | **Confidence:** High | **Type:** MissingValueCrash
**Location:** `web/index.html:27`

**Evidence chain:**
1. **Outside data:** `/feed.json` can return parsed JSON without an `items` list
   — `helpers/load_feed.py:8-12`
2. **Missing guard:** the page parses the reply without checking status, parse
   failure, list shape, or empty list — `web/index.html:24-27`
3. **Use site:** the page reads `data.items[0].title` — `web/index.html:27`
4. **Failure:** when `items` is missing or `null`, the direct access throws and
   the title never renders — `web/index.html:27`

**Runtime scenario:** The service returns `{}` during an empty-feed day. The
page tries to read the first item and stops before showing the user a helpful
message.

**Fix suggestion:** Check `response.ok`, ensure `items` is an array, and show a
friendly empty-state title when it has no first item.

**Test suggestion:** Serve `{}`, `{"items": null}`, and `{"items": []}` from
`/feed.json`; the page should show "No items yet" instead of throwing.
```

---

## Coverage example for a mixed project

For a folder containing:

```text
web/index.html
helpers/load_feed.py
settings.json
dist/app.min.js
README.md
```

The report header must say:

```text
Files read: 2 — web/index.html, helpers/load_feed.py
Files I could not inspect: 2 — settings.json, README.md
Files skipped as dependencies/generated/minified: 1 — dist/app.min.js
Verdict: I read 2 files. I could not inspect these 2 files: settings.json, README.md. In what I read, I found 1 crash risk.

For data/config files: I didn't inspect these; a typo in them can still break things.
```

The key point: the report never implies uninspected files are safe.

---

## Key takeaways for detector design

1. **MissingValueCrash found this.** The strongest signal is direct use of an
   outside value without a status, parse, shape, or empty-list guard.
2. **Sample data can be misleading.** Tests with neat samples do not prove real
   replies are complete.
3. **Fix near intake when possible.** If several files use the same outside
   data, clean it once near the file read or web reply.
4. **Multiple failure sites from one root cause should be deduplicated.** Report
   the missing guard once and list all affected lines.
5. **Coverage is part of the result.** A no-finding report must still say which
   files were not inspected.
