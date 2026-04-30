## Repo-Level Context Discovery

When starting work in a project, check for the following files at the project root and read them if they exist. These contain project-specific conventions, coding standards, and domain knowledge that should inform your work.

### Agent conventions

If an `AGENTS.md` file exists at the project root, read it. It contains project-level agent guidelines including:
- Coding conventions and standards for the project
- Available skills and their locations
- Git workflow and commit rules
- File boundaries (files not to modify)
- Testing patterns and tooling

### Skill files

If a `.agents/skills/` directory exists at the project root, scan it for `SKILL.md` files in subdirectories (e.g., `.agents/skills/testing/SKILL.md`). Each skill file contains domain-specific patterns, conventions, and code examples relevant to that area of the codebase.

Read any skill files that are relevant to the current task before beginning work.

### When to skip

If these files do not exist, proceed normally — not all projects use this convention. Do not ask the user about these files; silently check and use them if present.
