# CONTEXT.md Format

## Purpose

CONTEXT.md is the project's domain glossary. It captures the agreed meaning of terms so that all agents and humans use the same vocabulary consistently.

## Structure

```markdown
# Context

## Terms

### <Term>

<Plain-language definition. One to three sentences. What it means in THIS project, not what it means generically.>

### <Another Term>

<Definition.>
```

## Rules

- One term per heading.
- Definitions should be understandable by someone unfamiliar with the codebase.
- Use concrete examples when a term is ambiguous ("Order means a customer's purchase request, not the sort order of a list").
- Keep entries short. If a term needs a paragraph, it's probably two terms.
- Alphabetical order within the Terms section.
- No implementation details. Describe the concept, not the code that implements it.
