# Fix Patterns

Common fix patterns organized by detector type. Always prefer the pattern that
matches the project you are reading.

---

## MissingValueCrash — Check and default where data enters

The best fix is usually near the file read, web reply, command output, or user
input. Clean the value once so later code can stay simple.

### Python

```python
# BEFORE — assumes the reply is successful and complete
data = requests.get(url).json()
first_title = data["items"][0]["title"]

# AFTER — checks status, shape, and empty list before use
response = requests.get(url, timeout=10)
response.raise_for_status()
data = response.json()
items = data.get("items") or []
if not items:
    return "No items found"
first_title = items[0].get("title", "Untitled")
```

### Shell

```bash
# BEFORE — uses possibly-empty command output as a path
project_dir=$(jq -r '.workspace' "$state_file")
open "$project_dir"

# AFTER — stops with a clear message if the value is missing
project_dir=$(jq -r '.workspace // empty' "$state_file")
if [[ -z "$project_dir" ]]; then
  printf '%s\n' "I could not find the workspace path."
  exit 1
fi
open "$project_dir"
```

### JavaScript / HTML script

```javascript
// BEFORE — assumes the web reply has a non-empty list
const data = await response.json()
document.querySelector("#title").textContent = data.items[0].title

// AFTER — checks reply and shape before use
if (!response.ok) throw new Error("The request failed")
const data = await response.json()
const items = Array.isArray(data.items) ? data.items : []
document.querySelector("#title").textContent = items[0]?.title ?? "No title yet"
```

---

## RuntimeShapeMismatch — Make runtime expectations honest

When code expects a shape, make that expectation true at runtime or handle the
alternate shape explicitly.

### Python

```python
# BEFORE — returns different shapes without making callers handle them
def load_user(path):
    if not path.exists():
        return None
    return json.loads(path.read_text())

name = load_user(path)["name"]

# AFTER — caller handles the missing-user path
user = load_user(path)
if user is None:
    return "No saved user yet"
name = user.get("name", "Unknown")
```

### Shell

```bash
# BEFORE — helper may print nothing, caller assumes a value
token=$(read_token)
curl -H "Authorization: Bearer $token" "$url"

# AFTER — empty output stops before making a bad request
token=$(read_token)
if [[ -z "$token" ]]; then
  printf '%s\n' "I could not find the saved sign-in token."
  exit 1
fi
curl -H "Authorization: Bearer $token" "$url"
```

---

## GuardGap — Extend the existing safe pattern

When one path already handles missing data, reuse that same pattern everywhere
the same value is used.

```python
# BEFORE — one path guards tags, another assumes tags exists
tags = payload.get("tags") or []
visible_tags = [tag for tag in tags if tag.get("visible")]

tag_names = [tag["name"] for tag in payload["tags"]]

# AFTER — both paths use the same guarded value
tags = payload.get("tags") or []
visible_tags = [tag for tag in tags if tag.get("visible")]
tag_names = [tag.get("name", "Unnamed") for tag in tags]
```

---

## HiddenAssumption — Name and handle the empty case

```javascript
// BEFORE — assumes the split always has two parts
const project = location.hash.split("/")[1]
loadProject(project)

// AFTER — handles a missing part before loading
const project = location.hash.split("/")[1]
if (!project) {
  showMessage("Choose a project first")
  return
}
loadProject(project)
```

```bash
# BEFORE — assumes grep found a match
app_path=$(grep '^APP=' "$state_file" | cut -d= -f2-)
open "$app_path"

# AFTER — checks the match before use
app_path=$(grep '^APP=' "$state_file" | cut -d= -f2-)
if [[ -z "$app_path" ]]; then
  printf '%s\n' "I could not find the app path."
  exit 1
fi
open "$app_path"
```

---

## AsyncFailure — Add error handling, timeout, and stale-result protection

### JavaScript

```javascript
// BEFORE — request failure becomes an unhandled promise rejection
saveSettings(settings)

// AFTER — user gets a clear failure path
try {
  await saveSettings(settings)
  showMessage("Saved")
} catch (error) {
  showMessage("I could not save that. Try again in a moment.")
}
```

### Python

```python
# BEFORE — can hang forever or crash without a helpful message
data = requests.get(url).json()

# AFTER — bounded wait plus clear recovery path
try:
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    data = response.json()
except (requests.RequestException, ValueError):
    return "I could not load that data right now."
```

### Shell

```bash
# BEFORE — later commands run even if download failed
curl -o "$file" "$url"
open "$file"

# AFTER — stops before using a missing or partial file
if ! curl -fL -o "$file" "$url"; then
  printf '%s\n' "I could not download the file."
  exit 1
fi
open "$file"
```

---

## Fix suggestion rules

- Prefer one guard at data intake over many scattered checks later.
- Preserve the project's existing style and helper functions.
- Do not hide a real failure by returning an empty value unless the user-facing
  behavior remains correct.
- Give a test or manual check that uses the bad value: missing key, empty list,
  invalid JSON, failed command, timeout, or blank environment variable.
- Keep the suggestion small enough for Aragorn to implement safely after the
  user reviews the report.
