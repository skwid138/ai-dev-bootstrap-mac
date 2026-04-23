# AI Dev Bootstrap for Mac — Implementation Plan

> An interactive shell tool that sets up a Mac for non-technical users to vibe-code apps and automations using agentic coding tools like OpenCode.

---

## Design Principles

1. **Shell-native** — Pure Bash/Zsh with [Gum](https://github.com/charmbracelet/gum) for interactive UI (plain fallback for pre-Homebrew stages)
2. **Idempotent** — Safe to run repeatedly; skips installed packages, updates outdated ones
3. **Tiered** — Three install tiers the user can choose from, plus individual package toggles
4. **Modular** — Each category is a standalone script sourced by the main installer
5. **Opinionated but optional** — Sensible defaults with the ability to customize everything
6. **XDG-compliant** — Dotfiles live in `~/.config/ai-bootstrap/` following modern conventions

---

## Architecture

```
ai-dev-bootstrap-mac/
├── bootstrap.sh              # Entry point (curl-friendly one-liner)
├── lib/
│   ├── common.sh             # Shared helpers: logging, idempotent install, OS checks
│   ├── ui.sh                 # Gum wrappers with plain-text fallbacks
│   └── checks.sh             # Pre-flight checks (macOS version, disk space, arch)
├── modules/
│   ├── 00-xcode-clt.sh       # Xcode Command Line Tools
│   ├── 01-homebrew.sh        # Homebrew install/update
│   ├── 02-gum.sh             # Install Gum (enables interactive UI for remaining steps)
│   ├── 03-terminal.sh        # Ghostty (optional, recommended)
│   ├── 04-git.sh             # Git + GitHub CLI + credential setup
│   ├── 05-editor.sh          # VS Code
│   ├── 06-runtime.sh         # mise + Node.js LTS
│   ├── 07-python.sh          # uv + Python
│   ├── 08-cli-tools.sh       # ripgrep, jq, fd, direnv, tmux, btop, gum
│   ├── 09-opencode.sh        # OpenCode install + multi-provider API key wizard
│   ├── 10-shell-config.sh    # Modular zshrc: init.sh barrel, zplug, spaceship, plugins
│   ├── 11-local-ai.sh        # Ollama or LM Studio (optional, mutually exclusive choice)
│   ├── 12-containers.sh      # OrbStack (optional)
│   └── 13-extras.sh          # Playwright, shfmt, ffmpeg, imagemagick
├── config/
│   ├── tiers.sh              # Tier definitions (essential / recommended / complete)
│   └── packages.sh           # Package registry: name, brew formula, tier, description
├── dotfiles/
│   ├── init.sh               # Barrel file sourced from ~/.zshrc
│   ├── aliases.sh            # Beginner-friendly aliases
│   ├── paths.sh              # PATH additions for installed tools
│   ├── vars.sh               # Environment variables
│   ├── zsh_config.sh         # Case-insensitive completion
│   └── zsh_plugins.sh        # zplug + spaceship + syntax highlighting + autosuggestions
├── tests/
│   ├── test_common.bats      # Unit tests using bats-core
│   ├── test_checks.bats
│   └── test_idempotency.bats
├── PLAN.md                   # This file
└── README.md                 # User-facing docs
```

---

## Install Tiers

### 🟢 Essential (Minimum Viable Setup)
Everything a non-tech person needs to start vibe-coding with OpenCode.

| Package | Type | Purpose |
|---------|------|---------|
| Xcode Command Line Tools | system | Build tools, git |
| Homebrew | system | Package manager |
| Gum | brew | Interactive UI for this tool (and user scripts) |
| Git | brew | Version control (newer than Xcode's) |
| GitHub CLI (gh) | brew | Repo management, auth |
| VS Code | cask | Code editor |
| mise | brew | Runtime version manager (Node, Python, etc.) |
| Node.js LTS | via mise | JavaScript runtime |
| uv | brew | Python package/project manager |
| Python (latest stable) | via uv | Python runtime |
| ripgrep (rg) | brew | Fast search (used by OpenCode/agents) |
| jq | brew | JSON processing |
| OpenCode | brew tap | Agentic coding tool |

### 🔵 Recommended (Essential + Quality of Life)
Adds shell polish, better terminal, and useful dev tools.

| Package | Type | Purpose |
|---------|------|---------|
| *Everything in Essential* | | |
| Ghostty | cask | Modern, fast terminal emulator |
| fd | brew | Better `find` |
| direnv | brew | Per-directory env vars |
| tmux | brew | Terminal multiplexer (used by OpenCode orchestration) |
| btop | brew | System resource monitor |
| zplug | brew | Zsh plugin manager |
| Spaceship prompt | zplug | Clean, informative prompt |
| zsh-syntax-highlighting | zplug | Command highlighting |
| zsh-autosuggestions | zplug | History-based suggestions |

### 🟣 Complete (Recommended + Power User)
Everything, including local AI and containers.

| Package | Type | Purpose |
|---------|------|---------|
| *Everything in Recommended* | | |
| Ollama **or** LM Studio | brew/cask | Local AI models |
| OrbStack | cask | Lightweight Docker/Linux VMs |
| Playwright | npm global | Browser automation/testing |
| shfmt | brew | Shell script formatter |
| ffmpeg | brew | Media processing |
| imagemagick | brew | Image processing |

### Excluded (too specialized for this tool's audience)
These are on Hunter's machine but not relevant for non-tech vibe-coders:
ansible, argocd, acli, automake, cmake, coreutils, findutils, gawk, gnu-sed, go, grep, helm, kubeseal, kustomize, ocrmypdf, pipx, poetry, postgresql, pyenv, redis, sonar-scanner, terraform, zig, cowsay, fortune, lolcat, android-platform-tools, bartender, cursor, dbeaver, docker-desktop, gcloud-cli/sdk, google-chrome, miniconda, ngrok, obsidian, postman, rectangle, shottr, stats, superwhisper, discord

---

## Execution Flow

```
1. bootstrap.sh runs (curl one-liner or git clone + ./bootstrap.sh)
   │
2. Pre-flight checks (macOS ≥ Sequoia 15, Apple Silicon/Intel, disk space)
   │
3. Install Xcode CLT + Homebrew + Gum (plain text UI — no Gum yet)
   │  ← After this point, Gum is available for pretty interactive UI
   │
4. Welcome screen (Gum styled)
   │  Brief explanation of what this tool does and who it's for
   │
5. Tier selection (gum choose)
   │  "🟢 Essential — Just the basics"
   │  "🔵 Recommended — Basics + nice shell & tools"
   │  "🟣 Complete — Everything including local AI"
   │  "🔧 Custom — Pick exactly what you want"
   │
6. If "Custom": show full package list (gum choose --no-limit) pre-checked per tier
   │
7. For each selected module, run in order:
   │  - Check if already installed → skip with message
   │  - Install (with gum spin for progress)
   │  - Verify installation
   │  - Log result (installed / skipped / failed)
   │
8. Shell configuration (if zsh plugins were selected)
   │  - Copy dotfiles to ~/.config/ai-bootstrap/shell/
   │  - Add single guarded source line to ~/.zshrc
   │  - Preserve all existing .zshrc content
   │
9. OpenCode configuration
   │  - Install OpenCode
   │  - Ask: "Do you want to configure an AI provider?" (loop)
   │    - Show provider menu: Copilot / Anthropic / OpenAI / Skip
   │    - For each: show step-by-step instructions for getting API key
   │    - Securely prompt for key, write to env/config
   │    - "Add another provider?" → loop or continue
   │  - Write ~/.config/opencode/opencode.json
   │
10. Summary screen
    │  ✅ Installed: git, gh, mise, node, ...
    │  ⏭️  Skipped: homebrew (already installed), ...
    │  ❌ Failed: (none hopefully)
    │  📋 Next steps: open VS Code, try "opencode" in terminal
```

---

## Key Implementation Details

### Bootstrap One-Liner
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/skwid138/ai-dev-bootstrap-mac/main/bootstrap.sh)"
```
This clones the repo to `~/.config/ai-bootstrap/repo/`, runs the installer, and keeps it for future re-runs.

### Idempotent Install Helper (`lib/common.sh`)
```bash
install_brew_formula() {
  local formula="$1"
  if brew list "$formula" &>/dev/null; then
    log_skip "$formula"
    return 0
  fi
  ui_spin "Installing $formula..." brew install "$formula"
  log_installed "$formula"
}

install_brew_cask() {
  local cask="$1"
  if brew list --cask "$cask" &>/dev/null; then
    log_skip "$cask"
    return 0
  fi
  ui_spin "Installing $cask..." brew install --cask "$cask"
  log_installed "$cask"
}
```

### Gum Fallback (`lib/ui.sh`)
```bash
HAS_GUM=false
command -v gum &>/dev/null && HAS_GUM=true

ui_choose() {
  if $HAS_GUM; then
    gum choose "$@"
  else
    # Plain select fallback
    select opt in "$@"; do echo "$opt"; break; done
  fi
}

ui_confirm() {
  if $HAS_GUM; then
    gum confirm "$1"
  else
    read -p "$1 (y/n) " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]]
  fi
}

ui_spin() {
  local title="$1"; shift
  if $HAS_GUM; then
    gum spin --spinner dot --title "$title" -- "$@"
  else
    echo "$title"
    "$@"
  fi
}
```

### Dotfile Strategy
- Dotfiles installed to `~/.config/ai-bootstrap/shell/` (XDG-compliant)
- `~/.zshrc` gets a single guarded source line appended:
  ```bash
  # AI Dev Bootstrap
  [[ -f ~/.config/ai-bootstrap/shell/init.sh ]] && source ~/.config/ai-bootstrap/shell/init.sh
  ```
- The `init.sh` barrel conditionally sources each file (same pattern as Hunter's `~/code/scripts/init.sh`)
- Existing `.zshrc` content is **never** overwritten — only appended if the line isn't already there

### OpenCode Provider Setup (`modules/09-opencode.sh`)
Interactive loop that lets users configure multiple providers:
```
┌─ Configure AI Providers for OpenCode ─────────────────────┐
│                                                            │
│  OpenCode works with several AI providers.                 │
│  You need at least one to get started.                     │
│                                                            │
│  > GitHub Copilot (free tier available — recommended)      │
│    Anthropic (Claude — best coding model, paid)            │
│    OpenAI (GPT — paid)                                     │
│    Skip for now                                            │
│                                                            │
└────────────────────────────────────────────────────────────┘
```
Each provider shows:
- What it is (1 sentence)
- How to get an API key (step-by-step with URLs)
- Secure input prompt for the key
- Verification that the key works
- "Add another provider?" to loop

### Ghostty Config
Your current Ghostty config is purely theme/colors — no functional settings to carry over. The tool will:
- Install Ghostty if selected
- Leave config vanilla (Ghostty ships with great defaults)
- No theme opinions imposed

---

## File Breakdown & Estimated Effort

| File | Lines (est.) | Complexity | Notes |
|------|-------------|------------|-------|
| `bootstrap.sh` | 100 | Low | Entry point, clone + dispatch |
| `lib/common.sh` | 120 | Medium | Install helpers, logging, idempotency |
| `lib/ui.sh` | 100 | Medium | Gum wrappers + fallbacks |
| `lib/checks.sh` | 60 | Low | OS version, arch, disk |
| `config/tiers.sh` | 40 | Low | Tier → package mapping |
| `config/packages.sh` | 80 | Low | Package registry |
| Each module (×14) | ~40-80 | Low-Med | Install + configure + verify |
| `dotfiles/*` (×6) | ~30 each | Low | Shell config files |
| `tests/*.bats` | 200 | Medium | bats-core tests |
| `README.md` | 150 | Low | User docs |

**Total estimate: ~2,000 lines across ~30 files**

---

## Implementation Order

### Phase 1: Foundation
1. [ ] `lib/common.sh` — helpers, logging, idempotent installers
2. [ ] `lib/ui.sh` — Gum wrappers with plain fallbacks
3. [ ] `lib/checks.sh` — pre-flight checks
4. [ ] `config/packages.sh` — package registry
5. [ ] `config/tiers.sh` — tier definitions
6. [ ] `bootstrap.sh` — entry point with tier selection flow

### Phase 2: Core Modules
7. [ ] `modules/00-xcode-clt.sh`
8. [ ] `modules/01-homebrew.sh`
9. [ ] `modules/02-gum.sh`
10. [ ] `modules/03-terminal.sh` (Ghostty)
11. [ ] `modules/04-git.sh` (Git + gh + credential config)
12. [ ] `modules/05-editor.sh` (VS Code)
13. [ ] `modules/06-runtime.sh` (mise + Node.js LTS)
14. [ ] `modules/07-python.sh` (uv + Python)
15. [ ] `modules/08-cli-tools.sh` (rg, jq, fd, direnv, tmux, btop, gum)
16. [ ] `modules/09-opencode.sh` (install + multi-provider API key wizard)

### Phase 3: Shell Config
17. [ ] `dotfiles/` — all shell config files
18. [ ] `modules/10-shell-config.sh` (zplug, spaceship, plugins, .zshrc wiring)

### Phase 4: Optional Modules
19. [ ] `modules/11-local-ai.sh` (Ollama / LM Studio)
20. [ ] `modules/12-containers.sh` (OrbStack)
21. [ ] `modules/13-extras.sh` (Playwright, shfmt, ffmpeg, imagemagick)

### Phase 5: Testing & Docs
22. [ ] `tests/` — bats-core test suite
23. [ ] `README.md` — installation docs, usage, FAQ

---

## Stretch Goals

- [ ] **Uninstall/reset command** (`./bootstrap.sh --uninstall`) — remove installed packages, restore .zshrc
- [ ] **Update command** (`./bootstrap.sh --update`) — update all managed packages
- [ ] **VS Code extensions** — pre-install recommended extensions for vibe-coding (list TBD by Hunter)
- [ ] **Profile export/import** — save selections to a JSON file, replay on another Mac
- [ ] **Extensive docs** — separate `docs/` directory with guides for each tool
- [ ] **OpenCode project templates** — scaffold starter projects (web app, automation, API)
- [ ] **macOS system preferences** — configure Finder, Dock, screenshots, etc.
- [ ] **Post-install tutorial** — interactive walkthrough of "your first vibe-coded app"
- [ ] **Homebrew Bundle** — generate a `Brewfile` from selections for reproducibility

---

## Decisions Made

| Question | Decision | Rationale |
|----------|----------|-----------|
| Dotfile location | `~/.config/ai-bootstrap/shell/` | XDG Base Directory spec — modern best practice, used by Ghostty, OpenCode, mise, etc. |
| Runtime manager | mise | Multi-runtime (Node, Python, Go, etc.), modern, single tool replaces nvm+pyenv |
| Ghostty config | Vanilla (no custom config shipped) | Your config is purely theme; Ghostty defaults are excellent |
| OpenCode providers | Loop-based multi-provider setup | Users can add Copilot + Anthropic + OpenAI, or just one, or skip |
| VS Code extensions | Stretch goal | Hunter will curate the list later |
| Shell framework | Pure Bash + Gum | Simplest approach; Gum handles all interactive UI after Phase 0 bootstrap |
| macOS version floor | Sequoia (15)+ | Current enough; avoids legacy edge cases |
