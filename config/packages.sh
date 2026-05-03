#!/bin/bash
# Package registry using parallel arrays (bash 3.2 compatible).
#
# This file MUST stay bash-3.2-compatible: bootstrap.sh is invoked via
# curl-pipe (`/bin/bash -c "$(curl ... bootstrap.sh)"`, see README) on
# unprovisioned macs where Homebrew bash 5.x does NOT yet exist. The
# bootstrap registers `bash` as an essential package (see Phase 7.5
# in zsh_init_plan.md) so that *after* bootstrap, the user has bash
# 5.x available; the bootstrap codebase itself does not depend on it.
# No associative arrays, no `mapfile`, no `${var,,}`-style expansions.

PACKAGES=()
PKG_NAMES=()
PKG_TYPES=()
PKG_IDS=()
PKG_TIERS=()
PKG_DESCS=()

register_package() {
  local key="$1"
  local name="$2"
  local type="$3"
  local id="$4"
  local tier="$5"
  local desc="$6"

  PACKAGES+=("$key")
  PKG_NAMES+=("$name")
  PKG_TYPES+=("$type")
  PKG_IDS+=("$id")
  PKG_TIERS+=("$tier")
  PKG_DESCS+=("$desc")
}

# Essential tier packages.
register_package "xcode" "Xcode Command Line Tools" "system" "xcode-clt" "essential" "Build tools and git"
register_package "homebrew" "Homebrew" "system" "homebrew" "essential" "Package manager"
register_package "bash" "Bash" "formula" "bash" "essential" "Modern bash 5.x (macOS ships 3.2)"
register_package "gum" "Gum" "formula" "gum" "essential" "Interactive UI for installers"
register_package "git" "Git" "formula" "git" "essential" "Version control"
register_package "gh" "GitHub CLI" "formula" "gh" "essential" "GitHub repo and auth tools"
register_package "vscode" "VS Code" "cask" "visual-studio-code" "essential" "Code editor"
register_package "mise" "mise" "formula" "mise" "essential" "Runtime version manager"
register_package "node_lts" "Node.js LTS" "mise" "node@lts" "essential" "JavaScript runtime"
register_package "uv" "uv" "formula" "uv" "essential" "Python package manager"
register_package "python" "Python" "mise" "python@latest" "essential" "Python runtime"
register_package "ripgrep" "ripgrep (rg)" "formula" "ripgrep" "essential" "Fast search tool"
register_package "jq" "jq" "formula" "jq" "essential" "JSON processor"
register_package "opencode" "OpenCode" "formula" "opencode" "essential" "Agentic coding tool"

# Recommended tier packages.
register_package "ghostty" "Ghostty" "cask" "ghostty" "recommended" "Modern terminal emulator"
register_package "fd" "fd" "formula" "fd" "recommended" "Friendly find replacement"
register_package "direnv" "direnv" "formula" "direnv" "recommended" "Per-directory env vars"
register_package "tmux" "tmux" "formula" "tmux" "recommended" "Terminal multiplexer"
register_package "btop" "btop" "formula" "btop" "recommended" "Resource monitor"
register_package "zplug" "zplug" "formula" "zplug" "recommended" "Zsh plugin manager"
register_package "spaceship" "Spaceship prompt" "zplug" "spaceship" "recommended" "Clean zsh prompt"
register_package "zsh_syntax" "zsh-syntax-highlighting" "zplug" "zsh-syntax-highlighting" "recommended" "Command highlighting"
register_package "zsh_autosuggestions" "zsh-autosuggestions" "zplug" "zsh-autosuggestions" "recommended" "History-based suggestions"

# Complete tier packages.
register_package "ollama" "Ollama" "formula" "ollama" "complete" "Local AI models"
register_package "lm_studio" "LM Studio" "cask" "lm-studio" "complete" "Local AI desktop app"
register_package "orbstack" "OrbStack" "cask" "orbstack" "complete" "Lightweight containers"
register_package "playwright" "Playwright" "npm" "playwright" "complete" "Browser automation"
register_package "shfmt" "shfmt" "formula" "shfmt" "complete" "Shell formatter"
register_package "ffmpeg" "ffmpeg" "formula" "ffmpeg" "complete" "Media processing"
register_package "imagemagick" "ImageMagick" "formula" "imagemagick" "complete" "Image processing"
