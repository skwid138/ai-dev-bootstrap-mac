# AI Dev Bootstrap for Mac

Set up your Mac for vibe-coding with AI in minutes.

## ✨ What is this?

AI Dev Bootstrap for Mac is an interactive installer that prepares a brand‑new or existing Mac for building apps and automations with AI coding tools like OpenCode. It’s designed for non‑technical users, with guided prompts and safe defaults. You can run it multiple times — it only installs what’s missing and skips what you already have.

## ⚡ Quick Start

**One‑liner (recommended):**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/skwid138/ai-dev-bootstrap-mac/main/bootstrap.sh)"
```

**Or clone the repo:**

```bash
git clone https://github.com/skwid138/ai-dev-bootstrap-mac.git
cd ai-dev-bootstrap-mac
./bootstrap.sh
```

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

## 🐷 Vibe Code Launcher

If you install the **Recommended** tier (or higher), the bootstrap drops a one‑click app called **Vibe Code** into your `~/Applications` folder.

Open it from Spotlight, Launchpad, or Finder — drag it to your Dock for one‑click access. It opens Ghostty in your saved workspace folder and starts OpenCode automatically. No commands to remember.

> **Fresh every time.** Vibe Code always opens a single window with a single tab running OpenCode, regardless of what Ghostty had open last time. macOS would normally restore your previous Ghostty windows on launch; Vibe Code suppresses that just for itself so the experience stays predictable. One side effect: if you open extra tabs inside a Vibe Code window and then quit Ghostty (`Cmd+Q`), those extra tabs won't come back the next time you click Vibe Code. Manual Spotlight/Dock launches of Ghostty are unaffected — they restore normally.

> Want a plain shell instead? Open **Terminal** or **Ghostty** directly. Vibe Code is purely a convenience launcher; it doesn't change anything else on your system.

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
├── bootstrap.sh
├── lib/
├── modules/
├── config/
├── dotfiles/
├── ghostty/
├── launcher/
├── opencode/
├── tests/
├── PLAN.md
└── README.md
```

## 🎨 Credits

- Vibe Code app icon: [Lucide](https://lucide.dev) `piggy-bank` (ISC License). See [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).

## 📄 License

MIT
