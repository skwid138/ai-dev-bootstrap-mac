# AI Dev Bootstrap for Mac

Set up your Mac for vibe-coding with AI in minutes.

## ✨ What is this?

AI Dev Bootstrap for Mac is an interactive installer that prepares a brand‑new or existing Mac for building apps and automations with AI coding tools like OpenCode. It’s designed for non‑technical users, with guided prompts and safe defaults. You can run it multiple times — it only installs what’s missing and skips what you already have.

## ⚡ Quick Start

You have two ways to install. Pick whichever you prefer — they end up at the same place.

**One‑liner (recommended):**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/skwid138/ai-dev-bootstrap-mac/main/install.sh)"
```

This downloads a small bootstrapper that clones the repo into `~/code/ai-dev-bootstrap-mac` and then runs the installer. Requires `git` (which ships with the Xcode Command Line Tools — the bootstrapper will prompt to install them if missing).

To pass flags through the one‑liner, add `-s --` and your flags after the closing paren:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/skwid138/ai-dev-bootstrap-mac/main/install.sh)" -s -- --dry-run
```

**Or clone the repo yourself:**

```bash
git clone https://github.com/skwid138/ai-dev-bootstrap-mac.git ~/code/ai-dev-bootstrap-mac
~/code/ai-dev-bootstrap-mac/bootstrap.sh
```

Either way, the repo lives at `~/code/ai-dev-bootstrap-mac` afterward and you can re‑run `bootstrap.sh` (or just `./bootstrap.sh --launcher-only`) any time.

## 📦 Install Tiers

| Tier | Packages | What you get | Key tools |
| --- | --- | --- | --- |
| **Essential** | 14 | Minimum setup for AI‑assisted dev | Xcode CLT, Homebrew, Bash 5, Git, VS Code, Node, Python, OpenCode |
| **Recommended** | +10 | Quality‑of‑life upgrades | Ghostty, tmux, direnv, zplug, Spaceship prompt, zsh plugins |
| **Complete** | +7 | Power‑user extras | Ollama or LM Studio, OrbStack, Playwright, ffmpeg |

Want more control? Choose **Custom** in the installer and pick exactly what you want.

## 📋 What Gets Installed

<details>
<summary><strong>Essential (14 packages)</strong></summary>

- **Xcode Command Line Tools** — Build tools and system git
- **Homebrew** — Package manager
- **Bash** — Modern bash 5.x (macOS ships 3.2)
- **Gum** — Interactive terminal UI
- **Git** — Version control
- **GitHub CLI (gh)** — GitHub auth and repo tools
- **VS Code** — Code editor
- **mise** — Runtime version manager
- **Node.js LTS** — JavaScript runtime (via mise)
- **uv** — Python package manager
- **Python** — Python runtime (via uv)
- **ripgrep (rg)** — Fast file search
- **jq** — JSON processor
- **OpenCode** — AI coding tool

</details>

<details>
<summary><strong>Recommended (Essential + 10)</strong></summary>

- **Ghostty** — Modern terminal emulator
- **fd** — Friendly `find` replacement
- **direnv** — Per‑folder environment variables
- **tmux** — Terminal multiplexer
- **btop** — System resource monitor
- **zplug** — Zsh plugin manager
- **Spaceship prompt** — Clean, informative prompt
- **zsh-syntax-highlighting** — Command highlighting
- **zsh-autosuggestions** — History‑based suggestions
- **(All Essential packages)**

</details>

<details>
<summary><strong>Complete (Recommended + 7)</strong></summary>

- **Ollama** — Local AI models
- **LM Studio** — Local AI desktop app
- **OrbStack** — Lightweight containers & Linux VMs
- **Playwright** — Browser automation
- **shfmt** — Shell formatter
- **ffmpeg** — Media processing
- **ImageMagick** — Image processing
- **(All Recommended packages)**

</details>

## 🧭 How It Works

1. **Preflight checks** for macOS version, architecture, and disk space.
2. **Tier selection** (Essential, Recommended, Complete, or Custom).
3. **Idempotent installs** — already‑installed tools are skipped.
4. **Shell configuration** with a clean, modular dotfile setup.
5. **OpenCode provider setup** with guided API key prompts.
6. **Summary** of what was installed, skipped, or failed.

## 💬 What Working With OpenCode Looks Like

The bootstrap configures OpenCode to behave like a careful project manager — not a code-spitting machine. The goal: you describe what you want in plain English, the AI figures out whether it's a small thing or a big thing, and you stay in the driver's seat for every change.

**For small, obvious requests** ("fix this typo", "rename this variable") the AI confirms it understood you, shows the change it wants to make, and waits for your "yes" before touching the file. No ceremony — just a quick approval before any edit lands.

**For bigger requests** ("build me a Mac app that reminds me to drink water") the AI takes a slower path:

1. **Asks clarifying questions** — usually multiple-choice, with a recommended default — so it understands what you actually want.
2. **Writes a plan** in plain language to a file under `.project-plans/` so you can read it, push back, and resume the work later if needed.
3. **Has a second AI audit the plan** for risks, missing pieces, and bad assumptions. The audit findings are shown to you (even if there were none).
4. **Asks if you want to build it** before writing any code.
5. **Builds in small, reviewable steps** instead of dropping a wall of code at once.

You can approve, push back, or change direction at any step. Destructive commands (`rm -rf`, force-pushing to git, system-level tools) are blocked at the OpenCode permission layer regardless — so even an over-eager AI can't accidentally wreck your machine.

If you want the deep technical details of how this is wired up, see [`opencode/README.md`](opencode/README.md) inside this repo.

## 🐷 Just Vibes Launcher

If you install the **Recommended** tier (or higher), the bootstrap drops a one‑click app called **Just Vibes** into your `~/Applications` folder.

Open it from Spotlight, Launchpad, or Finder — drag it to your Dock for one‑click access. It opens Ghostty in your saved workspace folder and starts OpenCode automatically. No commands to remember.

> **Fresh every time.** Just Vibes always opens a single window with a single tab running OpenCode, regardless of what Ghostty had open last time. macOS would normally restore your previous Ghostty windows on launch; Just Vibes suppresses that just for itself so the experience stays predictable. One side effect: if you open extra tabs inside a Just Vibes window and then quit Ghostty (`Cmd+Q`), those extra tabs won't come back the next time you click Just Vibes. Manual Spotlight/Dock launches of Ghostty are unaffected — they restore normally.

> **Branded identity, two things to quit.** Just Vibes shows up as **Just Vibes** (with a piggy-bank icon) in your Dock, Cmd-Tab switcher, and Activity Monitor — distinct from Ghostty. The launcher and the terminal are two separate processes by design: this is what lets the launcher have its own identity. The trade-off is that quitting Just Vibes (`Cmd+Q` from its Cmd-Tab card or right-click → Quit on the Dock tile) does **not** quit the Ghostty window it spawned, and vice versa. Quit them separately.

> **Cmd-Tab focuses the terminal.** When Just Vibes is already running, Cmd-Tabbing to its card (or clicking its Dock tile) brings the most recently spawned Ghostty terminal window forward — no need to Cmd-Tab past Just Vibes to find Ghostty's card. The first time this happens after install, macOS may show a one-time **Accessibility** prompt asking to allow Just Vibes to control "System Events"; click **Allow**. Saying no is fine — Cmd-Tabbing to Just Vibes will just launch a fresh terminal instead of focusing the existing one.
>
> Want to disable PID tracking entirely (and always get a fresh terminal on Cmd-Tab)? Set this in your shell:
>
> ```bash
> export JUST_VIBES_TRACK_GHOSTTY_PID=0
> ```

> Want a plain shell instead? Open **Terminal** or **Ghostty** directly. Just Vibes is purely a convenience launcher; it doesn't change anything else on your system.

## 🐚 Shell Configuration

This project uses a modular dotfile setup stored in:

```
~/.config/ai-bootstrap/shell/
```

Your existing `~/.zshenv`, `~/.zprofile`, and `~/.zshrc` are never replaced. Three small, guarded blocks are appended (one per file) so you can remove them at any time:

```bash
# ai-bootstrap
[[ -f ~/.config/ai-bootstrap/shell/init_env.zsh ]] && source ~/.config/ai-bootstrap/shell/init_env.zsh

# ai-bootstrap
[[ -f ~/.config/ai-bootstrap/shell/init_profile.zsh ]] && source ~/.config/ai-bootstrap/shell/init_profile.zsh

# ai-bootstrap
[[ -f ~/.config/ai-bootstrap/shell/init_rc.zsh ]] && source ~/.config/ai-bootstrap/shell/init_rc.zsh
```

### Shell init layers

Zsh runs three different startup files depending on how a shell is opened, and each one has a different job. The bootstrap mirrors that split so the right things load at the right time:

- **`init_env.zsh`** (sourced from `~/.zshenv`) — runs in **every** zsh, including non‑interactive scripts. Sets up `PATH` and other environment variables. Stays silent and fast so background scripts and editor integrations aren't slowed down.
- **`init_profile.zsh`** (sourced from `~/.zprofile`) — runs in **login** shells (your first shell after logging in, or `ssh` sessions). Re‑applies `PATH` after macOS's `path_helper` runs, and activates tools like `mise` that need login‑shell context.
- **`init_rc.zsh`** (sourced from `~/.zshrc`) — runs in **interactive** shells (any terminal you actually type into). Loads zsh plugins (`zplug`), the **Spaceship** prompt, syntax highlighting, autosuggestions, and quality‑of‑life aliases.

Each block is sentinel‑guarded against double‑sourcing and uses idempotent `PATH` manipulation, so re‑running the bootstrap or having extra dotfiles around won't break anything.

## 🛠 Troubleshooting

**A CLI tool stopped working after `brew upgrade` (or after a long time without re‑running bootstrap).** Run:

```bash
~/code/ai-dev-bootstrap-mac/bootstrap.sh --refresh-paths
```

This re‑bakes Homebrew's prefix paths into your shell config without touching anything else.

**Want to check whether your paths are stale without making changes?**

```bash
~/code/ai-dev-bootstrap-mac/bootstrap.sh --check-paths
```

Exits `0` if paths are healthy, non‑zero if they look stale.

## 🔁 Re‑running

Safe to run again anytime. The installer skips what you already have and can add new tools later (for example, upgrading from Essential to Recommended).

## ✅ Requirements

- **macOS 15 (Sequoia) or newer**
- **Apple Silicon or Intel**

## 🧪 Running Tests

```bash
brew install bats-core && bats tests/
```

## 🗂️ Project Structure

```
ai-dev-bootstrap-mac/
├── bootstrap.sh          # Main entry point — the installer
├── install.sh            # One-liner bootstrapper (curl target)
├── lib/                  # Shared shell helpers
├── modules/              # Install modules (one per tool/feature)
├── config/               # Package definitions and tier mappings
├── dotfiles/             # Modular zsh configuration files
├── ghostty/              # Ghostty terminal config and themes
├── launcher/             # Just Vibes app bundle and build scripts
├── opencode/             # OpenCode AI config (agents, skills, commands)
├── scripts/              # Helper scripts for OpenCode self-maintenance
├── tests/                # Bats test suite
├── CONTRIBUTING.md       # Development guide and quality gates
└── README.md
```

## 🎨 Credits

- Just Vibes app icon: [Lucide](https://lucide.dev) `piggy-bank` (ISC License). See [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).

## 📄 License

MIT
