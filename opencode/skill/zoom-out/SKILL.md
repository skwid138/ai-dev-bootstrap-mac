---
name: zoom-out
description: >-
  Map how a whole project fits together in plain language. Use when the user
  asks to "map my app", "map my project", "show me how this fits together",
  "what are the main parts", or wants to understand how the pieces connect
  before changing anything.
---

# Zoom Out

Create a plain-language map of the project or app so the user can understand the big picture before asking for changes.

**This skill is read-only.** Read files, search names, and inspect existing project notes. Do not write files, edit files, run setup commands, install tools, start servers, change settings, call MCP tools, or run destructive commands. This skill only explains what is already there.

## Project selection guard

Only Gandalf may ask the user questions. If the request could mean more than one project or folder:

1. Stop before mapping.
2. Identify the likely project choices using read-only checks.
3. Return those choices to Gandalf.
4. Gandalf confirms the project with the user in plain language before mapping begins.

Do not rely on Legolas, Aragorn, or any other helper to ask the user. Helpers return options or blockers to Gandalf.

If the current project is clear, proceed without asking.

## What to read first

1. Look for `CONTEXT.md`, README files, package files, app entry files, scripts, and top-level folders.
2. If `CONTEXT.md` exists, prefer the words it uses for the project's important concepts.
3. If no glossary exists, infer names cautiously and say they are your best guess.
4. Read enough connecting files to understand how the main parts fit together. Do not try to read every file unless the project is small.

## Scale cap

For large projects, focus on the main pieces instead of dumping a full file tree.

Use this sentence near the end when you intentionally cap the scope:

> I focused on the main pieces, tell me if you want me to go deeper on any of them.

Prefer about 5-8 main pieces. Mention only lower-level files when they help explain the big picture.

## Output format

Use plain terms such as **main parts**, **what connects to what**, and **where things flow**. Do not use unexplained engineering labels.

Never output raw Mermaid, graph syntax, DOT syntax, or any other diagram language. If structure helps, use a simple indented list or short prose.

Produce:

```text
## The short version
<2-4 sentences explaining what this project is and how it is organized.>

## Main parts
- <Plain name for part 1> — <what it does for the user or project>
  - Connects to: <other main parts, in plain language>
  - Where it lives: <path or small set of paths>
- <Plain name for part 2> — <what it does>

## Where things flow
1. <User action, command, or event starts here.>
2. <The next main part handles it.>
3. <The result ends up here.>

## Good places to look next
- <Path or area> — <why this is the best next place to inspect.>

## Limits of this map
<What was not read, what was inferred, and whether the map focused on the main pieces.>
```

## Behavioral rules

### Always

- Stay read-only.
- Confirm the project through Gandalf when the project is ambiguous.
- Use `CONTEXT.md` terms when they exist.
- Translate file and folder names into everyday meaning.
- Keep exact paths when they help the user or a future agent find the place being described.
- State uncertainty plainly.
- Cap large projects to the main pieces and say so.

### Never

- Never write, edit, or create files.
- Never call MCP tools.
- Never run destructive commands or commands that change project state.
- Never output raw diagram syntax.
- Never dump an exhaustive tree for a large project.
- Never make a helper ask the user which project to map.
