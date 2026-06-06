---
description: >-
  Map how the whole project fits together in plain language. Shows the main
  parts, what connects to what, and where things flow. Use this when you want
  the big picture; use /explain for one file or one small piece.
---
The user has invoked `/map-my-app`. They want a plain-language map of how the whole project fits together.

Use the `zoom-out` skill to identify the project, read only what is needed, and explain the main parts and connections.

## Workflow

1. **Identify the project.**
   - If the user named a project, folder, or app, use that.
   - If the target is ambiguous, Gandalf asks the user which project to map before any mapping begins.

2. **Read the big-picture notes first.** Prefer `CONTEXT.md`, README files, package files, app entry files, scripts, and top-level folders.

3. **Map the whole project, not one file.** This command is different from `/explain`: `/explain` explains what one file or small piece does; `/map-my-app` explains how the project's main pieces fit together.

4. **Explain in plain language.** Use headings for the short version, main parts, where things flow, good places to look next, and limits of the map.

## Safety rules

- Read-only: do not write, edit, install, start servers, or change settings.
- Do not call MCP tools.
- Do not output Mermaid, graph syntax, or diagram-language blocks.
- On large projects, focus on the main pieces and say: "I focused on the main pieces, tell me if you want me to go deeper on any of them."
