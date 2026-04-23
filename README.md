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
| **Essential** | 13 | Minimum setup for AI‑assisted dev | Xcode CLT, Homebrew, Git, VS Code, Node, Python, OpenCode |
| **Recommended** | +10 | Quality‑of‑life upgrades | Ghostty, tmux, direnv, zplug, Spaceship prompt, zsh plugins |
| **Complete** | +7 | Power‑user extras | Ollama or LM Studio, OrbStack, Playwright, ffmpeg |

Want more control? Choose **Custom** in the installer and pick exactly what you want.

## 📋 What Gets Installed

<details>
<summary><strong>Essential (13 packages)</strong></summary>

- **Xcode Command Line Tools** — Build tools and system git
- **Homebrew** — Package manager
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

## 🐚 Shell Configuration

This project uses a modular dotfile setup stored in:

```
~/.config/ai-bootstrap/shell/
```

Your existing `~/.zshrc` is never replaced. A single, guarded line is appended so you can remove it at any time:

```bash
# AI Dev Bootstrap
[[ -f ~/.config/ai-bootstrap/shell/init.sh ]] && source ~/.config/ai-bootstrap/shell/init.sh
```

The shell setup includes **zplug**, the **Spaceship** prompt, and quality‑of‑life plugins like **syntax highlighting** and **autosuggestions**.

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
├── tests/
├── PLAN.md
└── README.md
```

## 📄 License

MIT
