# `opencode/` — design intent and structure

> **Audience:** the human maintaining this directory (most often, future-Hunter), and any AI agent working on this codebase.
>
> **What this is:** the components installed to `~/.config/opencode/` by the `ai-dev-bootstrap-mac` bootstrap. This directory is the source-of-truth; the bootstrap copies/symlinks from here.
>
> **What this is not:** opencode itself. We don't fork or vendor opencode. We configure it.

This README explains *why* the directory looks the way it does — the design choices, the source-vs-docs contradictions worth knowing about, and the patterns to follow when extending it.

---

## 1. What lives here

```
opencode/
├── opencode.json.template      # rendered by bootstrap → ~/.config/opencode/opencode.json
├── AGENTS.md                   # always-on, short, safety-critical rules (every session reads it)
├── instruction/                # long-form, modular, workflow-specific docs (auto-loaded)
│   ├── repo-context.md
│   └── plan-workflow.md        # canonical source for the planning workflow
├── agent/                      # custom agent definitions (Tolkien-named subagents)
│   ├── treebeard.md            # auditor
│   ├── radagast.md             # external-research specialist
│   ├── legolas.md              # codebase discovery specialist
│   └── celebrimbor.md          # autonomous deep-implementation worker
├── command/                    # custom slash commands
├── skill/                      # on-demand skill definitions
├── plugins/                    # opencode plugin packages
├── package.json                # plugin/runtime dependencies (e.g., dcp)
└── package-lock.json
```

The bootstrap installs everything under `~/.config/opencode/`, where opencode looks for it. The `template` extension on `opencode.json.template` exists because the bootstrap renders it (substituting in the user's API keys, paths, etc.) into the final `opencode.json`.

---

## 2. Where things go (decision tree)

When adding a new piece of behavior, ask in this order:

1. **Is it a short, always-on rule that every session must obey?**
   → Add it to `AGENTS.md`. Examples: "never push without confirmation," "use Conventional Commits," "translate jargon at the user boundary."

2. **Is it long-form, workflow-specific, and benefits from being modular and re-quoted?**
   → Add it to a new (or existing) file under `instruction/`. Register the file in `opencode.json.template`'s `instructions[]` so it auto-loads. Example: `instruction/plan-workflow.md` is the long-form companion to AGENTS.md's short workflow rules.

3. **Is it role-specific behavior that only one kind of agent should follow?**
   → Add it to that agent's prompt under `agent/<name>.md`. Examples: treebeard's audit rubric, radagast's source-citation discipline.

4. **Is it on-demand — a workflow the agent should activate when the user asks for X?**
   → Add a skill under `skill/<name>.md` (or `skill/<name>/SKILL.md` for skills with bundled scripts). Skills are pulled in by description-match when the user's request triggers them.

5. **Is it hard enforcement — a rule the agent must not be able to talk itself out of?**
   → Use a `permission` block in `opencode.json.template`. Examples: `permission.edit: ask` for the universal approval gate, `permission.bash` denies for `rm -rf *` and `git push --force`.

The default is the **shortest, most-targeted layer** that achieves the goal. Don't put everything in AGENTS.md just because it's the easiest place to drop text; the file has a length budget (≤250 lines) for a reason — long always-on rules drown out short ones.

---

## 3. Why built-in `plan` is the default agent

Opencode ships with a `plan` agent that is the right answer for our use case, and the v1 design uses it as-is rather than reimplementing.

Three reasons:

1. **Source-level edit denial.** The `plan` agent denies file mutations at the tool level, not just by prompt. The agent code at `packages/opencode/src/agent/agent.ts:127-149` and the write/edit/apply_patch tool implementations under `packages/opencode/src/tool/` reject in-plan mutations even if the model tries. This is structurally safer than a prompt rule.
2. **Explicit Yes/No approval gate via Tab handoff.** When a plan is approved, the user presses **Tab** to switch to the Build agent, which can mutate files (subject to `permission.edit: ask`). The mode switch is user-driven, deliberate, and visible. (See §4 for why we don't use opencode's `plan_exit` tool here.)
3. **One-line config change.** Setting `plan` as the default agent in `opencode.json` is a single field. No fork, no vendoring, no patch.

The custom agents (`treebeard`, `radagast`, `legolas`, `celebrimbor`) are **subagents** — they're invoked by the primary `plan` (or `build`) agent through the `task` tool. They're not user-selectable from the agent picker, which keeps the picker minimal: just `plan` and `build`.

---

## 4. Source-vs-docs contradictions to be aware of

Opencode's documentation and source code disagree in two places that affect this directory's design. **Source is authoritative.**

### 4.1 Bash in plan mode

- **Docs claim** (`packages/web/src/content/docs/agents.mdx:61-66`): the `plan` agent asks before running bash commands.
- **Source says** (`packages/opencode/src/agent/agent.ts:90-107`): the default permission for bash in plan mode is `*: allow` — bash runs unconditionally.

We override this with `agent.plan.permission.bash` in `opencode.json.template`, denying destructive patterns (`rm -rf *`, `git push --force`, etc.) and asking on the rest. Treat the docs as aspirational; trust the source.

### 4.2 `plan_exit` is gated and the handoff target is hardcoded

- **Tool exists** at `packages/opencode/src/tool/plan.ts:33-78` with handoff hardcoded to the `build` agent (`tool/plan.ts:56-64`). Cannot be reconfigured to hand off to a different agent without forking.
- **Tool is not registered** in shipped opencode unless `OPENCODE_EXPERIMENTAL_PLAN_MODE=1` is set. The gating is at `packages/opencode/src/tool/registry.ts:232-233` and the flag is environment-only — there is no `experimental.plan_mode` key in the `opencode.json` config schema (see the enumerated keys at `packages/opencode/src/config/config.ts:247-263`).
- **Two upstream PRs** to promote `plan_exit` out of experimental status (#11811, #12727) closed unmerged. Open hardening issue #9296 affects the handoff path with a model-leak bug.

The v1 design **does not use `plan_exit`**. Plan mode hands off to Build via the user pressing Tab — the documented non-experimental UX (`packages/web/src/content/docs/index.mdx:268-280`). The Plan and Build agent prompts both include explicit Tab-handoff instructions so users discover the flow. See `instruction/plan-workflow.md` §2 step 8, §13 step 4, and §14, plus the Divergence log entry for `T1.4` in the redesign plan.

---

## 5. Agent topology (Option B summary)

**Primaries** (user-selectable from the picker):

- `plan` (default, opencode built-in) — read-only, plans work, delegates via `task` to subagents.
- `build` (opencode built-in) — can edit files, gated by `permission.edit: ask`.

**Subagents** (invoked via `task`, not picker-selectable):

- `treebeard` — auditor. Strong default for every non-trivial plan (see §6).
- `radagast` — external-research and OSS reference specialist. Source-cited reports against pinned commit SHAs.
- `legolas` — codebase discovery specialist. Fast file/call-path lookup.
- `celebrimbor` — autonomous deep-implementation worker for end-to-end execution. Used when the maintainer wants to delegate a well-specified task and walk away.

**Why this shape:** the v0 design had a `gandalf` orchestrator primary that mostly delegated to other primaries. It added a layer with no value — opencode's built-in `plan` already orchestrates via `task`. We dropped `gandalf` and let `plan` orchestrate directly. (T1.4 of the redesign plan, commit `cadc799`.)

---

## 6. The audit-mandatory protocol

Every non-trivial plan is audited by `treebeard` before approval. Audit is a **strong default with a logged-divergence escape**, not a mechanical lock — opencode has no hook to force a tool call. The agent runs the audit by convention; skipping it requires appending a row to the plan's Divergence log explaining why.

Audit format, severity rubric, verdict thresholds, re-audit mode, and the OVER-CORRECTED status are defined in `instruction/plan-workflow.md` §3 / §3a / §3b. AGENTS.md re-quotes the short rule.

The protocol exists because plan-quality bugs are silent: the user approves a plausible-looking plan, the agent executes it, and the breakage shows up two commits later. The audit catches them before approval, when revision is cheap.

---

## 7. Skills as shell-script orchestrators

> **Skills should be thin.**

When a skill needs non-trivial work — a compound git operation, a multi-step API call, anything that benefits from being deterministic — **prefer wrapping a shell script over baking the logic into the skill markdown**. Shell scripts are testable, deterministic, version-controllable, and easy to invoke from any context. The skill's job is to know **when** to invoke and **how** to interpret the output.

Bundle scripts under the skill's directory (`skill/<name>/scripts/`) or in a project-level `scripts/` directory. See `~/code/scripts/agent/` (the maintainer's reference implementation) for examples.

This pattern keeps skill markdown short, auditable, and editable by humans without re-reading 200 lines of embedded logic.

---

## 8. Extension recipes

### Adding a skill

1. Create `skill/<name>/SKILL.md` (or `skill/<name>.md` for a script-less skill).
2. The first line of the description block determines when the skill fires — write it as a clear when-to-use sentence ("Use this skill whenever the user asks to ...").
3. If the skill needs scripts, bundle them under `skill/<name>/scripts/` and reference them by relative path from `SKILL.md`.
4. Test by triggering the skill in a real opencode session — the `skill` tool output should load your `SKILL.md` content.

### Adding an agent

1. Create `agent/<name>.md`.
2. Front matter (YAML or JSON) sets `description`, `mode` (`primary` or `subagent`), `model`, `tools`, `permission`.
3. The body is the system prompt. Keep it focused on this agent's role; offload general rules to `AGENTS.md` (read by all modes) or `instruction/` files.
4. Subagents use `mode: subagent` and are invoked from primaries via the `task` tool.

### Adding an instruction file

1. Create `instruction/<name>.md`.
2. Add the path to `opencode.json.template`'s `instructions[]` array.
3. The file auto-loads into every session. Treat it as a living spec — re-quoted from short summaries in `AGENTS.md`.

### Tightening a permission rule

1. Edit `opencode.json.template`'s `permission` block (top-level for global rules, `agent.<name>.permission` for per-agent overrides).
2. Bash patterns use shell-glob matching: `"git push --force": "deny"`, `"rm -rf *": "deny"`, `"*": "ask"` for the catch-all.
3. Test the new rule in a real session — the `permission` denial UX is what the user will see.

---

## 9. What was removed, and why

Earlier iterations of this directory included pieces that were dropped. They are documented here so a future reader doesn't reintroduce them by accident.

### 9.1 The `gandalf` orchestrator agent

A primary `gandalf` agent that orchestrated work by delegating to other agents. Removed in T1.4 of the redesign (commit `cadc799`). Built-in `plan` already orchestrates via `task` — `gandalf` was a layer with no behavior the built-in didn't already provide. The maintainer's personal `~/.config/opencode/agent/gandalf.md` (separate, not part of the bootstrap install) is retained for their own use.

### 9.2 The `orchestration` plugin

A custom plugin that registered tools to drive multi-step workflows. Removed in T3.1 of the redesign. The same coordination is now handled by the `plan` agent calling `task` for delegation — no plugin needed.

### 9.3 The `orchestration-runtime` instruction file

A long-form instruction file documenting the orchestration plugin's protocol. Removed in T3.2 of the redesign because the plugin it documented was removed in T3.1. The replacement is `instruction/plan-workflow.md` (T2.2), which documents the simpler `plan + task` pattern.

### 9.4 The `/continue`, `/stop`, `/diagnostics` slash commands

Custom slash commands that drove the orchestration plugin's runtime loop. Removed alongside the plugin. The opencode-built-in `task` tool delegation is synchronous from the primary agent's perspective, so there is no runtime loop to start, stop, or inspect.

---

## Cross-references

- Always-on rules: `AGENTS.md`.
- Long-form planning workflow: `instruction/plan-workflow.md`.
- Repo-specific context: `instruction/repo-context.md`.
- The redesign plan that produced this directory's current shape: `~/code/ai-dev-bootstrap-mac/.project-plans/2026-05-04_opencode-config-redesign.md`.
