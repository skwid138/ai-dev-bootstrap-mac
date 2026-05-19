# Disambiguation — verifying shared definitions

False agreement often happens when two people use the same word for different things. Before exploring a design, sharpen the terms that matter.

## What counts as a load-bearing term

A term is load-bearing if a different definition would change the answer.

Examples:

- "User" — human, account, API caller, or customer record?
- "Cancellation" — button click, status change, refund, or contract event?
- "Search" — exact match, full text, semantic search, or scoped filter?
- "Cache" — memory, local disk, browser, CDN, or shared service?

## Protocol

When you spot a load-bearing term:

1. Pause and verify: "When you say X, do you mean A, B, or something else?"
2. Recommend the meaning you think they mean: "I'd guess A because of Y. Right?"
3. Wait for confirmation before moving on.
4. Capture the agreed definition in the conversation so it can be referred back to.

## When the user resists

If the user says "you know what I mean," push once, politely:

> "I want to be sure because the answer changes depending on whether X means A or B. Can you confirm one?"

If they still resist, proceed with a stated assumption:

> "I'll proceed assuming A. If B was right, we may have to back up at the next fork."

## Aliases and renaming

When two words appear to mean the same thing:

1. Pick the clearer word, usually the one used most consistently in code or by domain experts.
2. Flag the other word as an alias to avoid.
3. Use the chosen word consistently for the rest of the conversation.

## Common patterns

- **Person vs account confusion** — "user," "customer," "client," and "account" often differ.
- **Process vs outcome confusion** — "checkout" could mean page, button, order, or full flow.
- **State vs event confusion** — "cancelled" could be a record status or a one-time event.
- **Interface confusion** — "API" could mean a network endpoint or a module's public interface.
- **Scope confusion** — "production" could mean deployed, customer-facing, revenue-impacting, or a specific environment.
