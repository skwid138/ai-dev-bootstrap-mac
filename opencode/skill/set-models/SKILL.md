---
name: set-models
description: >-
  Choose and apply a curated OpenCode Go model profile (Default, Eco, or Reset).
  Use when the user wants to "change my models", "update my models", "improve
  the AI team", "make the AI better", "lower cost", "I'm hitting rate limits",
  "use cheaper models", or "reset models to the installer default".
---

# Set Models

Help the user choose and apply a curated OpenCode Go model profile. Keep the conversation plain-language and outcome-focused; avoid exposing JSON, provider settings, or shell details unless the user asks.

## When to use

Use this skill when the user wants to improve, change, lower cost for, or reset the models used by their AI team.

Do not create a slash command. Use the helper script directly after checking that it exists.

## First: detect the current state

Read `AI_BOOTSTRAP_CURATED_MODELS` from the environment if it is present.

1. If `AI_BOOTSTRAP_CURATED_MODELS` has a non-empty value, tell the user their curated model tier is active. Offer to keep it, switch tiers, or reset to installer defaults.
2. If `AI_BOOTSTRAP_CURATED_MODELS` exists but is empty, the installer may have been re-run. Check the current OpenCode config for `opencode-go/` model entries. If they are present, offer to re-record the tier by applying a profile; otherwise ask whether they want to turn on the curated OpenCode Go profiles.
3. If the key is absent, treat this as a pre-feature install. Ask whether they use OpenCode Go before offering the curated profiles.

## Pre-flight before calling the script

Before running anything, verify both files are available in the workspace:

- `scripts/agent/set-models.sh`
- `scripts/model-profiles.json`

If either file is missing, stop and explain that the bootstrap assets need to be refreshed before model profiles can be applied.

## Tier choices

- **Default**: best overall quality for the AI team. Use this when the user wants the strongest day-to-day experience.
- **Eco**: rate-limit-friendly and economical. Use this when the user is running into usage limits or wants a lighter setup.
- **Reset**: removes curated model choices and returns OpenCode to the installer default behavior.

When the user chooses a tier, run one of:

```bash
$AI_BOOTSTRAP_WORKSPACE/scripts/agent/set-models.sh default
$AI_BOOTSTRAP_WORKSPACE/scripts/agent/set-models.sh eco
$AI_BOOTSTRAP_WORKSPACE/scripts/agent/set-models.sh reset
```

After it succeeds, summarize in plain language what changed and whether the user should restart OpenCode.

## Council models

The default and eco profiles also configure models for the council review plugin. When applied, the council will use multiple OpenCode Go models to provide independent review perspectives.

After applying a profile, the council is ready to use — Gandalf will automatically prefer `council_review` over solo Saruman when the models are configured.

Resetting clears the council models back to an empty list, which disables the council (the plugin will error until models are reconfigured).

## For users without OpenCode Go

Do not recommend provider-specific model names. Give role-based guidance instead:

- Coordinator: choose a balanced, reliable model with strong instruction following.
- Builder: choose a high-quality coding model with dependable tool use.
- Reviewer: choose a careful reasoning model that is good at finding risks.
- Explorer: choose a fast model that can scan many files and summarize clearly.
- Researcher: choose a model with strong long-context reading and source synthesis.
- Compactor: choose a fast, inexpensive model that preserves important details.

Explain that these are characteristics to look for, not a required shopping list.

## Research summary (2026-08-20)

- OpenCode Go config uses lowercase `opencode-go/<model-id>` IDs; display-name casing is not valid in profiles.
- Default profile: root/small, Legolas, and compaction use MiMo V2.5; Gandalf/Aragorn and one council slot use GPT 5.6 Luna; Saruman uses MiMo V2.5 Pro; Radagast uses DeepSeek V4 Flash.
- Default council: GLM 5.3, MiniMax M3, and GPT 5.6 Luna.
- Eco profile: root/small/Radagast and one council slot use DeepSeek V4 Flash with the 2026-08-31 ZDR review guard; Gandalf/Aragorn and one council slot use MiniMax M3; Saruman/council use MiMo V2.5 Pro; Legolas/compaction use MiMo V2.5.
- Reasoning options stay profile-specific: GPT 5.6 Luna uses `reasoningEffort`; DeepSeek V4 Flash and MiniMax M3 use `thinking.type` where configured; MiMo compaction disables `thinking.type`.
- If DeepSeek ZDR lapses, use the profile's privacy-safe MiMo fallback note rather than introducing unverified or stale model IDs.
