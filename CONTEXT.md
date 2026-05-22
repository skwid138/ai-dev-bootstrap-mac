# AI Dev Bootstrap Mac

A macOS installer that sets up a complete AI-assisted development environment. Targets non-technical users who want to build things with AI without learning programming.

## Target User

A **non-technical creative** — someone who wants to build small apps, automate Mac tasks, prototype ideas, and troubleshoot system issues using AI as their engineering team. They have no interest in learning programming terminology or understanding how things work under the hood. They care about outcomes, not process.

Think: a product owner whose entire engineering team is OpenCode. They don't need to know how the bread is made — they just want it to taste good.

## Design Priorities (in order)

1. **Cannot cause harm.** The system must prevent destructive or irreversible actions. No footguns, no "are you sure?" as the only guardrail. If something could break their Mac or lose data, the agent refuses or creates an undo path automatically.
2. **Never leave them stuck or confused.** No jargon. No scary language. If a question must be asked, explain why it matters using plain language or analogies. If they don't understand a question, that's a failure of the question, not of them.
3. **Understand before acting.** The agent must fully comprehend what the user wants before doing anything. Probe intent thoroughly — but ask questions a non-technical person can answer. Flesh out wants and needs completely, then the agent makes technical decisions autonomously.
4. **Hide the machinery.** Technical details (git, PATH, shell config, dependencies, build steps) stay invisible. The user sees results, not process. Progress updates should describe what's happening in human terms, not technical ones.
5. **Agent makes engineering decisions.** Once intent is clear, the agent chooses the implementation approach, tools, patterns, and trade-offs without asking. Only surface choices that genuinely require user preference (visual style, behavior, naming things they'll see).
6. **Safe re-runs.** Running the installer or any tool again should be safe and fix problems, not create new ones.

## Language

**Bootstrap / Installer**:
The shell-based setup orchestrator that installs tools, configures the shell, and deploys OpenCode assets.
_Avoid_: setup script, provisioner

**Tier**:
A named package selection level — Essential, Recommended, Complete, or Custom. Each tier is a superset of the previous.
_Avoid_: profile, level, mode

**Module**:
A numbered shell script (00–13) that installs one logical group of tools. Modules execute in numeric order.
_Avoid_: step, stage, phase

**Phase 0**:
Modules 00–02 (Xcode CLT, Homebrew, gum). Failures here are fatal — nothing downstream can work without them.
_Avoid_: critical modules

**Phase 1+**:
Modules 03–13. Failures are recorded but non-fatal; the installer continues and reports failures in the summary.

**State file**:
`~/.config/ai-bootstrap/state.sh` — persists tier, workspace, brew prefix, and timestamps as `export KEY='value'` lines. Sourced by the launcher and shell config. Must pass validation before sourcing.
_Avoid_: config file, settings

**Workspace**:
The user's chosen project directory (default `~/code`). Cannot contain spaces or single quotes. Stored in the state file.

**JustVibes**:
The `.app` launcher that opens Ghostty + OpenCode in one click. Built by `launcher/build.sh`, installed to `/Applications` or `~/Applications`.
_Avoid_: the app, launcher app

**OpenCode**:
The AI coding assistant configured by this bootstrap. Config lives at `~/.config/opencode/`.

**Curated assets**:
The `agent/`, `skill/`, `command/`, and `instruction/` directories deployed from `opencode/` in this repo to `~/.config/opencode/`. Tracked by a `.managed-files` manifest for stale cleanup.
_Avoid_: OpenCode config (ambiguous with opencode.json)

**opencode.json**:
The rendered OpenCode configuration file. Always overwritten on re-run (with `.bak.<timestamp>` backup). Contains model provider, MCP servers, and plugin config.

**Helper scripts**:
Shell scripts deployed from `scripts/` to `$WORKSPACE/scripts/`. Used by OpenCode skills at runtime (e.g., dependency checks, bootstrap doctor).

**Add-on module**:
A module excluded from all tier expansions. Only runs when explicitly requested via `--module <name>`. Has its own preflight checks and can trigger the full installer if dependencies are missing. Example: `14-tailscale.sh`.
_Avoid_: bonus module, optional module, extra

**Breadcrumb**:
A file written to `~/.config/ai-bootstrap/` by an add-on module when it cannot proceed due to missing dependencies and the user chooses "Run full installer." The bootstrap checks for pending breadcrumbs at completion and offers to continue with the add-on setup. Cleaned up after use or decline.
_Avoid_: flag file, marker

## Relationships

- A **Tier** determines which **Modules** run and which packages are installed.
- **Phase 0** modules must succeed before **Phase 1+** modules execute.
- The **State file** is written by the installer and consumed by **JustVibes** and shell config.
- **Curated assets** are managed by a manifest; **opencode.json** is rendered separately.
- **Helper scripts** are optional; declining the overwrite prompt preserves existing scripts without removing curated assets.
- **Add-on modules** are excluded from **Tier** expansion; they run only via explicit `--module` flag.
- A **Breadcrumb** bridges an interrupted **Add-on module** run to the **Bootstrap** completion, enabling seamless continuation.

## Example dialogue

> **Dev:** "If module 08 fails, does the whole install stop?"
> **Domain expert:** "No — it's Phase 1+, so the failure is recorded and the summary shows it failed. Only Phase 0 failures abort."

> **Dev:** "What happens to opencode.json on re-run?"
> **Domain expert:** "It's backed up to `.bak.<timestamp>` then overwritten with the latest rendered config."

## Flagged ambiguities

- "config" was used to mean both **opencode.json** (rendered settings) and **curated assets** (agent/skill/command/instruction dirs) — resolved: these are distinct concepts with different update mechanisms.
- "launcher" was used to mean both the **JustVibes** `.app` bundle and the `launcher/` source directory — resolved: "JustVibes" for the installed app, "launcher/" for the build source.
