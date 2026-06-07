---
name: handoff
description: >-
  Save or resume plain-language progress notes for a project. Use when the user
  asks to "save progress", "leave a handoff", "pick this up later", "resume",
  "what was I doing", or wants a concise note for the next session.
---

# Handoff

Create and find short progress notes that help the user continue later without
remembering every detail.

This skill may write only when the user invokes `/save-progress` and Gandalf has
shown a plain-language preview and received confirmation. `/resume` is read-only:
it lists and summarizes saved notes without changing files.

## What a saved note must include

Use clear headings and short bullets:

- `## What was done`
- `## What's left`
- `## Decisions made`
- `## Watch out for`
- `## Useful places`
- `## Suggested skills`

Always include `## Suggested skills`. If there are no useful suggestions, write
`None` under that heading.

Use plain language. Avoid unexplained engineering words. Keep exact file paths
only when they help a future session find the work.

## Shared project-folder rule for `/save-progress` and `/resume`

Use this same rule for both commands so a note saved from a folder is findable
from that same folder later:

1. If the current folder is inside a project with change history, use that
   project's top folder.
2. Otherwise use the saved Bootstrap workspace. Resolve it in this order:
   `AI_BOOTSTRAP_WORKSPACE`, then `~/.config/ai-bootstrap/state.sh`, then
   `~/code`.
3. Never use an empty workspace value.
4. For messages to the user, show only the project folder name, not the full
   absolute path.

For folders without change history, say plainly that notes will be saved in the
main workspace area. Do not tell the user to run technical setup commands.

## `/save-progress` workflow

1. Gather the useful facts from the current conversation: what was done, what is
   left, decisions, watch-outs, useful places, and suggested skills.
2. Redact secrets while composing. Use placeholders like `[REDACTED_API_KEY]`,
   `[REDACTED_TOKEN]`, or `[REDACTED_PRIVATE_KEY]` instead of any real secret.
3. Show Gandalf a plain-language preview. Gandalf asks the user to confirm before
   any file is written.
4. After confirmation, run the co-located redaction helper over the fully
   composed note before writing anything to disk.

### Required second redaction layer

The second redaction layer is mandatory and fail-closed:

- Locate the already rendered literal bash allowlist entry in
  `~/.config/opencode/opencode.jsonc` that ends with
  `/skill/handoff/redact-secrets.sh *`.
- Invoke that exact absolute script path, with the `redact` subcommand, over the
  fully composed text before writing. Do not use `~`, environment variables, or a
  relative path for this invocation.
- Capture the helper's standard output. The exact bytes saved as the note must
  be that scrubbed output, not the pre-scrub composed draft.
- Never discard the scrubbed output and write the original draft. Never write the
  unredacted draft and then scrub the file afterward.
- If the helper is missing, fails, or the invocation is denied, refuse to write.
  Tell the user: "I could not safely check this note for secrets, so I did not
  save it. Please restart OpenCode or rerun the installer, then try again."

The first layer helps avoid secrets while writing. The helper is the verifiable
net. `/save-progress` must never save with only the first layer.

### Save location and file names

Save to this direct folder under the resolved project root:

```text
.project-plans/<date>_<subject>.handoff.md
```

Use today's date and a short lowercase subject. If the same filename already
exists, append a number such as `_2`, `_3`, and so on. Never silently overwrite a
saved note.

Use this filename-selection recipe exactly. `plans_dir` is the resolved root's
direct `.project-plans` folder, and `subject_slug` is the short lowercase
subject:

```bash
base="${plans_dir}/${date_slug}_${subject_slug}"
candidate="${base}.handoff.md"
counter=2

while [ -e "$candidate" ]; do
  candidate="${base}_${counter}.handoff.md"
  counter=$((counter + 1))
done

printf '%s\n' "$candidate"
```

Write only to the selected `candidate`, and only with the scrubbed output from
the helper.

On every successful save, make sure `.project-plans/` appears in that root's
`.gitignore`. Add it if missing. Do not duplicate it.

## `/resume` workflow

1. Resolve the project root using the same shared rule above.
2. Look only for `*.handoff.md` files directly inside that root's
   `.project-plans/` folder. Do not search subfolders; archived notes are left
   out by design.
3. Sort matches newest first.

Use this listing recipe exactly. `plans_dir` is the resolved root's direct
`.project-plans` folder:

```bash
notes=()

for note in "$plans_dir"/*.handoff.md; do
  [ -f "$note" ] || continue
  notes+=("$note")
done

[ "${#notes[@]}" -eq 0 ] || ls -1t "${notes[@]}"
```

4. If none exist, say: "No saved progress notes for this project yet."
5. If one note exists, summarize it and offer to continue from it.
6. If multiple notes exist, Gandalf shows a chooser with friendly labels made
   from the date and subject. Do not show raw filenames unless needed for a
   future agent.

## Safety and coverage contract

- Say which project folder name was used.
- Say whether a note was saved, not saved, or only previewed.
- Say if redaction failed and therefore no write happened.
- Do not claim all secrets are impossible; say the helper checked common secret
  shapes and the user should avoid pasting private values into notes.
