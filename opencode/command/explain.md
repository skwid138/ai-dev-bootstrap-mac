---
description: >-
  Explain what a piece of code does, in plain language a non-technical user
  can follow. Argument is optional — if omitted, explains the most recently
  edited file or the file currently open. Use this when you want to
  understand something without needing to ask "what does this mean?" line
  by line.
---
The user has invoked `/explain`. They want a plain-language walkthrough of code.

## Workflow

1. **Identify the target.**
   - If the user passed an argument (file path, function name, line range, or directory), use that.
   - If no argument, explain the most recently modified file in the current project (`git log -1 --name-only --pretty=format:""` or equivalent), or ask the user to specify if that's ambiguous.

2. **Read the code.** Don't skim. Read enough to give a real explanation.

3. **Explain in this structure:**

   ```
   ## What it does (one sentence)
   <plain-language summary, no jargon>

   ## How it works (3-7 bullet points)
   - <step 1 of what the code does, in order>
   - <step 2>
   - ...

   ## When it runs
   <under what circumstances this code is triggered>

   ## What it depends on
   <other files, libraries, services, env vars it needs to work>

   ## Things to know
   <anything surprising, fragile, or important — e.g. "this fails silently if
   the API returns null", "the timeout is hardcoded at 30s", or "if you change
   this, also update X">
   ```

## Style rules

- **No jargon without definition.** First time you say "API", "callback", "promise", "regex" — define it in the same sentence in plain words.
- **Short sentences.** One idea per sentence. The reader should be able to read it once and get it.
- **Concrete over abstract.** "This adds 1 to a counter every time the user clicks the button" beats "This increments state on event."
- **Honest about complexity.** If a section is genuinely hard, say "this part is tricky — here's why" rather than glossing over.

## When the code is too long

If the file or scope is more than ~200 lines, ask the user to narrow it: "This file is X lines long. Want me to focus on a specific function, or give you a high-level overview of all of it?"

## When the code is bad

If the code is genuinely broken or smells dangerous, say so at the end in a "Concerns" section. Don't pretend it's fine. Suggest concrete improvements but don't apply them — `/explain` is read-only.
