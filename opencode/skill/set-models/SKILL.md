# Skill: set-models

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

## For users without OpenCode Go

Do not recommend provider-specific model names. Give role-based guidance instead:

- Coordinator: choose a balanced, reliable model with strong instruction following.
- Builder: choose a high-quality coding model with dependable tool use.
- Reviewer: choose a careful reasoning model that is good at finding risks.
- Explorer: choose a fast model that can scan many files and summarize clearly.
- Researcher: choose a model with strong long-context reading and source synthesis.
- Compactor: choose a fast, inexpensive model that preserves important details.

Explain that these are characteristics to look for, not a required shopping list.

## Research summary (2026-05-22)

- Kimi-family models use `thinking.type` to turn reasoning on or off.
- DeepSeek V4-family models use `thinking.type`; high-effort reasoning uses the camel-case `reasoningEffort` key.
- Qwen 3.6-family models use `enable_thinking`.
- MiniMax M2.5 and M2.7 do not need extra reasoning configuration for this workflow.
- The eco profile keeps the team usable with more rate-limit headroom while preserving stronger choices for coordination, building, and review roles.
