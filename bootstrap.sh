#!/bin/bash
set -euo pipefail

# ── Locate project root ──────────────────────────────────────────────
BOOTSTRAP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export BOOTSTRAP_DIR

# ── Source libraries ──────────────────────────────────────────────────
source "${BOOTSTRAP_DIR}/lib/ui.sh"
source "${BOOTSTRAP_DIR}/lib/checks.sh"
source "${BOOTSTRAP_DIR}/config/packages.sh"
source "${BOOTSTRAP_DIR}/config/tiers.sh"
source "${BOOTSTRAP_DIR}/lib/common.sh"
source "${BOOTSTRAP_DIR}/lib/workspace.sh"
source "${BOOTSTRAP_DIR}/lib/state.sh"
source "${BOOTSTRAP_DIR}/lib/brewfile.sh"
source "${BOOTSTRAP_DIR}/lib/args.sh"
source "${BOOTSTRAP_DIR}/lib/plan.sh"
source "${BOOTSTRAP_DIR}/lib/launcher.sh"
source "${BOOTSTRAP_DIR}/lib/summary.sh"
source "${BOOTSTRAP_DIR}/lib/paths_check.sh"
source "${BOOTSTRAP_DIR}/lib/breadcrumb.sh"

# ── Parse flags ───────────────────────────────────────────────────────
# args_parse exports BOOTSTRAP_DRY_RUN, BOOTSTRAP_NONINTERACTIVE, and
# BOOTSTRAP_LAUNCHER_ONLY. Returns 1 for --help, 2 for unknown flag.
args_rc=0
args_parse "$@" || args_rc=$?
if [ "$args_rc" -ne 0 ]; then
  args_print_help
  if [ "$args_rc" = "1" ]; then
    exit 0
  fi
  exit 2
fi

# ── Module registry ───────────────────────────────────────────────────
# Hardcoded by design: module-only mode should expose a stable, documented
# interface instead of discovering arbitrary shell files at runtime.
bootstrap_module_names() {
  cat <<'EOF'
xcode-clt
homebrew
gum
bash
terminal
git
editor
runtime
python
cli-tools
opencode
shell-config
local-ai
containers
extras
tailscale
EOF
}

resolve_module_file() {
  local module_name="$1"

  case "$module_name" in
    xcode-clt) echo "00-xcode-clt.sh" ;;
    homebrew) echo "01-homebrew.sh" ;;
    gum) echo "02-gum.sh" ;;
    bash) echo "02a-bash.sh" ;;
    terminal) echo "03-terminal.sh" ;;
    git) echo "04-git.sh" ;;
    editor) echo "05-editor.sh" ;;
    runtime) echo "06-runtime.sh" ;;
    python) echo "07-python.sh" ;;
    cli-tools) echo "08-cli-tools.sh" ;;
    opencode) echo "09-opencode.sh" ;;
    shell-config) echo "10-shell-config.sh" ;;
    local-ai) echo "11-local-ai.sh" ;;
    containers) echo "12-containers.sh" ;;
    extras) echo "13-extras.sh" ;;
    tailscale) echo "14-tailscale.sh" ;;
    *) return 1 ;;
  esac
}

is_addon_module() {
  local module_name="$1"

  case "$module_name" in
    tailscale) return 0 ;;
    *) return 1 ;;
  esac
}

bootstrap_handle_pending_breadcrumbs() {
  local pending_modules=()
  local module_name

  while IFS= read -r module_name; do
    [ -n "$module_name" ] || continue
    pending_modules+=("$module_name")
  done <<<"$(breadcrumb_pending || true)"

  [ "${#pending_modules[@]}" -gt 0 ] || return 0

  for module_name in "${pending_modules[@]}"; do
    if ! is_addon_module "$module_name"; then
      log_warn "Skipping unknown add-on breadcrumb: $module_name"
      breadcrumb_clear "$module_name"
      continue
    fi

    if ui_confirm "Continue setting up $module_name now?"; then
      local addon_rc
      set +e
      "${BOOTSTRAP_DIR}/bootstrap.sh" --module "$module_name"
      addon_rc=$?
      set -e
      if [ "$addon_rc" -ne 0 ]; then
        return "$addon_rc"
      fi
      breadcrumb_clear "$module_name"
    else
      breadcrumb_clear "$module_name"
    fi
  done
}

reconstruct_selected_packages_for_tier() {
  local tier="$1"

  SELECTED_PACKAGES=()
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    SELECTED_PACKAGES+=("$pkg")
  done <<<"$(get_tier_packages "$tier")"
  export SELECTED_PACKAGES
}

# ── Update fast path ──────────────────────────────────────────────────
# Refresh managed bootstrap assets without running the full installer. This
# is intentionally state-driven and non-interactive: the user's previous tier
# and workspace decide what is refreshed, and custom-tier installs are refused
# because their package selections are not persisted in state.sh.
if [ -n "${BOOTSTRAP_UPDATE:-}" ]; then
  # shellcheck source=lib/opencode.sh
  source "${BOOTSTRAP_DIR}/lib/opencode.sh"
  # shellcheck source=lib/common.sh
  source "${BOOTSTRAP_DIR}/lib/common.sh"
  # shellcheck source=lib/launcher.sh
  source "${BOOTSTRAP_DIR}/lib/launcher.sh"

  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required for --update, but it is not available. Re-run the full bootstrap to repair your install."
    exit 1
  fi

  state_path="$HOME/.config/ai-bootstrap/state.sh"
  if [ ! -f "$state_path" ]; then
    log_error "No state.sh found at $state_path"
    log_error "Run the full bootstrap first; --update only works after a previous install."
    exit 1
  fi

  if ! state_validate_sourceable_file "$state_path"; then
    log_error "Could not read saved bootstrap state. Re-run the full bootstrap to repair."
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$state_path"

  if [ "${AI_BOOTSTRAP_TIER:-}" = "custom" ]; then
    log_error "--update does not support custom-tier installs."
    log_error "Re-run the full installer so you can choose packages again."
    exit 1
  fi

  case "${AI_BOOTSTRAP_TIER:-}" in
    essential | recommended | complete) ;;
    *)
      log_error "AI_BOOTSTRAP_TIER='${AI_BOOTSTRAP_TIER:-}' is not a valid tier."
      log_error "Re-run the full bootstrap to repair your saved state."
      exit 1
      ;;
  esac

  export BOOTSTRAP_NONINTERACTIVE=1
  export AI_BOOTSTRAP_NONINTERACTIVE=1

  reconstruct_selected_packages_for_tier "$AI_BOOTSTRAP_TIER"
  SELECTED_TIER="$AI_BOOTSTRAP_TIER"
  OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
  WORKSPACE_PATH="$AI_BOOTSTRAP_WORKSPACE"
  BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export SELECTED_TIER OPENCODE_CONFIG_DIR WORKSPACE_PATH AI_BOOTSTRAP_WORKSPACE BOOTSTRAP_DIR BREW_PREFIX

  existing_model=""
  if [ -f "$OPENCODE_CONFIG_DIR/opencode.json" ]; then
    existing_model=$(jq -r '.model // empty' "$OPENCODE_CONFIG_DIR/opencode.json" 2>/dev/null || true)
  fi

  log_info "Updating OpenCode assets and helper scripts..."
  opencode_deploy_assets "${BOOTSTRAP_DIR}/opencode" "$OPENCODE_CONFIG_DIR"
  opencode_deploy_scripts "${BOOTSTRAP_DIR}/scripts" "$AI_BOOTSTRAP_WORKSPACE/scripts"
  opencode_render_config \
    "${BOOTSTRAP_DIR}/opencode/opencode.json.template" \
    "$OPENCODE_CONFIG_DIR/opencode.json" \
    "$existing_model"

  if [ -f "${BOOTSTRAP_DIR}/modules/10-shell-config.sh" ]; then
    # shellcheck source=modules/10-shell-config.sh
    source "${BOOTSTRAP_DIR}/modules/10-shell-config.sh"
  else
    log_error "modules/10-shell-config.sh not found at ${BOOTSTRAP_DIR}/modules/10-shell-config.sh"
    exit 1
  fi

  if launcher_needs_rebuild; then
    launcher_build >/dev/null
    log_installed "Just Vibes.app refreshed"
  else
    log_skip "Just Vibes.app is already current"
  fi

  state_write "$state_path" "$AI_BOOTSTRAP_WORKSPACE" "$AI_BOOTSTRAP_TIER" "$BOOTSTRAP_DIR"
  log_installed "Bootstrap assets updated. Quit and reopen Just Vibes to use the latest OpenCode configuration."
  exit 0
fi

# ── List-modules fast path ────────────────────────────────────────────
# Print canonical module names without reading state or touching the user's
# machine. This must run before preflight and all installer modules.
if [ -n "${BOOTSTRAP_LIST_MODULES:-}" ]; then
  bootstrap_module_names
  exit 0
fi

# ── Module-only fast path ─────────────────────────────────────────────
# Re-run exactly one named module. Standard modules read persisted
# tier/workspace and reconstruct SELECTED_PACKAGES for modules that gate
# sub-work via is_selected. Add-on modules can run without state and own their
# prerequisite checks. Then source the requested module directly and exit with
# that module's status.
if [ -n "${BOOTSTRAP_MODULE_ONLY:-}" ]; then
  state_path="$HOME/.config/ai-bootstrap/state.sh"
  module_is_addon=false
  if is_addon_module "$BOOTSTRAP_MODULE_ONLY"; then
    module_is_addon=true
  fi

  if ! $module_is_addon && [ ! -f "$state_path" ]; then
    log_error "No state.sh found at $state_path"
    log_error "Run the full bootstrap first; --module only works after a previous install."
    exit 1
  fi

  if ! $module_is_addon; then
    if ! MODULE_TIER=$(state_read_field "$state_path" "AI_BOOTSTRAP_TIER"); then
      log_error "Could not read AI_BOOTSTRAP_TIER from $state_path"
      log_error "state.sh may be corrupted. Re-run the full bootstrap to repair."
      exit 1
    fi

    if ! MODULE_WORKSPACE=$(state_read_field "$state_path" "AI_BOOTSTRAP_WORKSPACE"); then
      log_error "Could not read AI_BOOTSTRAP_WORKSPACE from $state_path"
      log_error "state.sh may be corrupted. Re-run the full bootstrap to repair."
      exit 1
    fi

    case "$MODULE_TIER" in
      essential | recommended | complete) ;;
      custom)
        log_error "error: --module requires a standard tier (essential, recommended, or complete)."
        exit 2
        ;;
      *)
        log_error "AI_BOOTSTRAP_TIER='$MODULE_TIER' is not a valid tier."
        log_error "Valid values: essential, recommended, complete."
        exit 2
        ;;
    esac

    reconstruct_selected_packages_for_tier "$MODULE_TIER"
    SELECTED_TIER="$MODULE_TIER"
    WORKSPACE_PATH="$MODULE_WORKSPACE"
    export AI_BOOTSTRAP_TIER="$MODULE_TIER"
    export AI_BOOTSTRAP_WORKSPACE="$MODULE_WORKSPACE"
  fi

  if ! module_file=$(resolve_module_file "$BOOTSTRAP_MODULE_ONLY"); then
    log_error "Unknown module: $BOOTSTRAP_MODULE_ONLY"
    log_error "Run with --list-modules to see available names."
    exit 2
  fi

  module_path="${BOOTSTRAP_DIR}/modules/${module_file}"
  if [ ! -f "$module_path" ]; then
    log_error "Module file not found: modules/${module_file}"
    exit 1
  fi

  set +e
  # shellcheck disable=SC1090
  source "$module_path"
  module_rc=$?
  set -e
  exit "$module_rc"
fi

# ── Launcher-only fast path ───────────────────────────────────────────
# Skip preflight, Phase 0, tier selection, workspace prompt, and all
# modules. Just rebuild ~/Applications/Just Vibes.app and exit. Useful
# when:
#   * The user accidentally deleted their launcher and wants it back.
#   * A dev is iterating on launcher/launch.sh and wants a fast rebuild
#     without re-running everything.
#   * Manually testing the .app bundle in isolation.
#
# Workspace resolution: read from existing state.sh if present (so the
# rebuilt launcher points at the same workspace as the user's previous
# bootstrap), else fall back to ~/code. The launcher script itself
# re-reads state.sh at click-time, so this is mostly belt-and-suspenders.
if [ -n "${BOOTSTRAP_LAUNCHER_ONLY:-}" ]; then
  build_script="${BOOTSTRAP_DIR}/launcher/build.sh"
  dest_dir=$(launcher_resolve_dest)
  app_path="$dest_dir/Just Vibes.app"

  if [ -n "${BOOTSTRAP_DRY_RUN:-}" ]; then
    echo ""
    echo "========================================"
    echo "  📋 Dry-run plan (launcher only)"
    echo "========================================"
    echo ""
    echo "  Would (re)build: $app_path"
    echo "  From:            $build_script"
    echo ""
    echo "  Nothing has been changed yet. Run without --dry-run to rebuild."
    echo ""
    exit 0
  fi

  log_info "Launcher-only mode: rebuilding $app_path"
  if launcher_install "$build_script" "$dest_dir" >/dev/null; then
    log_installed "Just Vibes.app rebuilt at $app_path"
    # Friendly heads-up if we landed in ~/Applications instead of the
    # standard /Applications. This only happens on locked-down Macs;
    # the message tells the user where to find it without requiring
    # them to know about ~/Applications as a separate folder.
    if [ "$dest_dir" = "$HOME/Applications" ]; then
      log_info "Note: /Applications is read-only on this Mac, so we"
      log_info "installed to ~/Applications instead. Spotlight, LaunchPad,"
      log_info "and Finder will all find it there."
    fi
    log_info "Open it from Spotlight, LaunchPad, or Finder."
    exit 0
  else
    log_error "Launcher rebuild failed"
    exit 1
  fi
fi

# ── Check-paths fast path ─────────────────────────────────────────────
# Read-only staleness check on the baked Homebrew prefix. Designed to be
# agent-pollable: prints a single status line on stdout (`fresh` /
# `stale: ...` / `error: ...`), exits 0/1/2. See plan §3.8 (rev-7) and
# lib/paths_check.sh for the full contract.
#
# Composes with --dry-run: a check is already side-effect-free, so the
# dry-run flag is a no-op here. We honor it (no output difference) so
# `--check-paths --dry-run` doesn't surprise an agent that always passes
# --dry-run for safety.
if [ -n "${BOOTSTRAP_CHECK_PATHS:-}" ]; then
  paths_check_run
  exit $?
fi

# ── Refresh-paths fast path ───────────────────────────────────────────
# Re-runs modules/10-shell-config.sh only with a freshly-resolved
# Homebrew prefix. Skips all other modules. ~1-2 seconds. The module is
# idempotent — re-emitting already-baked content is a no-op.
#
# Tier and workspace come from the persisted state.sh. If state.sh
# doesn't exist, we error out: refresh has no meaning before a first
# install, and trying to invent defaults would silently rewrite the
# user's shell config based on assumptions.
#
# Custom-tier users get a clean error: state.sh records
# AI_BOOTSTRAP_TIER='custom' but does NOT persist the per-package
# selections. Reconstructing SELECTED_PACKAGES would require either
# re-prompting (defeats --non-interactive) or treating "custom" as
# "all packages" (would silently install conditional sub-files the user
# explicitly opted out of). Better to refuse and tell them to re-run
# the full installer.
#
# Composes with --dry-run: prints what the module would do without
# actually re-running it.
if [ -n "${BOOTSTRAP_REFRESH_PATHS:-}" ]; then
  state_path="$HOME/.config/ai-bootstrap/state.sh"

  if [ ! -f "$state_path" ]; then
    log_error "No state.sh found at $state_path"
    log_error "Run the full bootstrap first; --refresh-paths only works after a previous install."
    exit 1
  fi

  # Read tier from state.sh.
  if ! REFRESH_TIER=$(state_read_field "$state_path" "AI_BOOTSTRAP_TIER"); then
    log_error "Could not read AI_BOOTSTRAP_TIER from $state_path"
    log_error "state.sh may be corrupted. Re-run the full bootstrap to repair."
    exit 1
  fi

  if [ "$REFRESH_TIER" = "custom" ]; then
    log_error "--refresh-paths does not support custom-tier installs."
    log_error "state.sh persists the tier name but not the package list, so we"
    log_error "cannot reconstruct your selection. Re-run ./bootstrap.sh to refresh."
    exit 1
  fi

  # Reconstruct SELECTED_PACKAGES from tier.
  SELECTED_PACKAGES=()
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    SELECTED_PACKAGES+=("$pkg")
  done <<<"$(get_tier_packages "$REFRESH_TIER")"
  export SELECTED_PACKAGES

  if [ -n "${BOOTSTRAP_DRY_RUN:-}" ]; then
    echo ""
    echo "========================================"
    echo "  📋 Dry-run plan (refresh paths)"
    echo "========================================"
    echo ""
    echo "  Would re-run: modules/10-shell-config.sh"
    echo "  Tier:         $REFRESH_TIER"
    echo "  This would re-resolve \`brew --prefix\` and re-bake it into"
    echo "  ~/.config/ai-bootstrap/shell/env/paths.zsh, then re-emit the"
    echo "  three-tier source lines into ~/.zshenv, ~/.zprofile, ~/.zshrc"
    echo "  (idempotent — duplicates are filtered)."
    echo ""
    echo "  Nothing has been changed yet. Run without --dry-run to refresh."
    echo ""
    exit 0
  fi

  log_info "Refreshing baked Homebrew prefix (tier: $REFRESH_TIER)..."
  if [ -f "${BOOTSTRAP_DIR}/modules/10-shell-config.sh" ]; then
    # shellcheck source=modules/10-shell-config.sh
    source "${BOOTSTRAP_DIR}/modules/10-shell-config.sh"
    log_installed "Shell config refreshed. Quit and reopen Just Vibes, or open a new terminal window. (If you must keep this terminal, run: source ~/.zshenv ~/.zprofile ~/.zshrc)"
    exit 0
  else
    log_error "modules/10-shell-config.sh not found at ${BOOTSTRAP_DIR}/modules/10-shell-config.sh"
    exit 1
  fi
fi

# ── Pre-flight ────────────────────────────────────────────────────────
# Skipped in dry-run: pre-flight does environment checks (macOS version,
# disk space) that are fine to run, but it also writes nothing — keeping
# everything before the plan-render side-effect-free is simpler than
# auditing each pre-flight check.
if [ -z "${BOOTSTRAP_DRY_RUN:-}" ]; then
  run_preflight
fi

# ── Phase 0: Bootstrap prerequisites (plain UI — no Gum yet) ─────────
# Skipped in dry-run. These modules install xcode-clt, brew, and gum,
# which are real side effects.
if [ -z "${BOOTSTRAP_DRY_RUN:-}" ]; then
  echo ""
  echo "========================================"
  echo "  AI Dev Bootstrap for Mac"
  echo "  Setting up prerequisites..."
  echo "========================================"
  echo ""

  # Xcode CLT
  if [ -f "${BOOTSTRAP_DIR}/modules/00-xcode-clt.sh" ]; then
    source "${BOOTSTRAP_DIR}/modules/00-xcode-clt.sh"
  fi

  # Homebrew
  if [ -f "${BOOTSTRAP_DIR}/modules/01-homebrew.sh" ]; then
    source "${BOOTSTRAP_DIR}/modules/01-homebrew.sh"
  fi

  # Gum
  if [ -f "${BOOTSTRAP_DIR}/modules/02-gum.sh" ]; then
    source "${BOOTSTRAP_DIR}/modules/02-gum.sh"
  fi

  # Re-detect Gum now that it should be installed.
  if command -v gum >/dev/null 2>&1; then
    HAS_GUM=true
  fi
fi

# ── Welcome ───────────────────────────────────────────────────────────
ui_header "🚀 AI Dev Bootstrap for Mac"
echo ""
log_info "This tool sets up your Mac for building apps and automations"
log_info "with AI-powered coding tools like OpenCode."
echo ""

# ── Tier selection ────────────────────────────────────────────────────
if [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
  # Non-interactive mode: default to recommended. Loud log so the user
  # is never surprised about what got installed in CI / unattended runs.
  # AI_BOOTSTRAP_TIER env var lets headless callers (notably the GHA
  # e2e-launcher workflow) pick a specific tier without an interactive
  # prompt. Validate against the known tier names; reject `custom` because
  # custom-tier requires per-package selection that has no env-var
  # equivalent today (matches the --refresh-paths constraint at line 137).
  if [ -n "${AI_BOOTSTRAP_TIER:-}" ]; then
    case "$AI_BOOTSTRAP_TIER" in
      essential | recommended | complete)
        SELECTED_TIER="$AI_BOOTSTRAP_TIER"
        ;;
      custom)
        log_error "AI_BOOTSTRAP_TIER='custom' is not supported in non-interactive mode."
        log_error "Custom tier requires interactive package selection."
        exit 1
        ;;
      *)
        log_error "AI_BOOTSTRAP_TIER='$AI_BOOTSTRAP_TIER' is not a valid tier."
        log_error "Valid values: essential, recommended, complete."
        exit 1
        ;;
    esac
    log_info "Non-interactive: using tier '$SELECTED_TIER' from AI_BOOTSTRAP_TIER"
  else
    SELECTED_TIER="recommended"
    log_info "Non-interactive: using default tier '$SELECTED_TIER'"
  fi
else
  log_info "Choose an install tier:"
  echo ""

  TIER=$(ui_choose \
    "🟢 Essential — $(get_tier_description essential)" \
    "🔵 Recommended — $(get_tier_description recommended)" \
    "🟣 Complete — $(get_tier_description complete)" \
    "🔧 Custom — Pick exactly what you want")

  # Extract tier key from selection.
  case "$TIER" in
    *Essential*) SELECTED_TIER="essential" ;;
    *Recommended*) SELECTED_TIER="recommended" ;;
    *Complete*) SELECTED_TIER="complete" ;;
    *Custom*) SELECTED_TIER="custom" ;;
    *) SELECTED_TIER="essential" ;;
  esac
fi

# ── Build selected package list ───────────────────────────────────────
SELECTED_PACKAGES=()

if [ "$SELECTED_TIER" = "custom" ]; then
  # Build display labels for all packages.
  LABELS=()
  for i in "${!PACKAGES[@]}"; do
    LABELS+=("${PKG_NAMES[$i]} — ${PKG_DESCS[$i]}")
  done

  CHOSEN=$(ui_choose_multi "${LABELS[@]}")

  # Map chosen labels back to package keys.
  while IFS= read -r label; do
    [ -z "$label" ] && continue
    for i in "${!PACKAGES[@]}"; do
      if [[ "$label" == "${PKG_NAMES[$i]}"* ]]; then
        SELECTED_PACKAGES+=("${PACKAGES[$i]}")
        break
      fi
    done
  done <<<"$CHOSEN"
else
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    SELECTED_PACKAGES+=("$pkg")
  done <<<"$(get_tier_packages "$SELECTED_TIER")"
fi

# ── Workspace anchor ─────────────────────────────────────────────────
# Where the user keeps their code projects. Asked once, persisted to
# ~/.config/ai-bootstrap/state.sh, referenced by aliases (cdc), the
# .app launcher (Phase E), and any future module that needs it.
WORKSPACE_DEFAULT=$(workspace_default_path)
WORKSPACE_PATH=""

if [ -n "${BOOTSTRAP_NONINTERACTIVE:-}" ]; then
  # Non-interactive: skip the prompt entirely, default to ~/code with a
  # loud log so the user knows what was assumed.
  WORKSPACE_PATH="$WORKSPACE_DEFAULT"
  log_info "Non-interactive: using default workspace '$WORKSPACE_PATH'"
else
  echo ""
  ui_header "📁 Workspace"
  echo ""
  log_info "Pick a directory to keep your code projects in. We'll create it"
  log_info "if it doesn't exist, and the 'cdc' shortcut will jump there."
  workspace_prompt_note "$WORKSPACE_DEFAULT"
  echo ""

  while [ -z "$WORKSPACE_PATH" ]; do
    user_input=$(ui_input "Workspace directory [$WORKSPACE_DEFAULT]:")

    if [ -z "$user_input" ]; then
      candidate="$WORKSPACE_DEFAULT"
    else
      candidate=$(workspace_expand_path "$user_input")
    fi

    if workspace_validate_path "$candidate"; then
      WORKSPACE_PATH="$candidate"
    else
      log_warn "Try again, or just press Enter to use $WORKSPACE_DEFAULT."
    fi
  done
fi

# ── Dry-run plan & exit ──────────────────────────────────────────────
# In dry-run mode, we have everything we need to show the plan: tier,
# workspace, and (for custom tier) the package list. Render and exit.
# Nothing has been written to disk yet — the workspace dir hasn't been
# created, state.sh hasn't been touched, no installs have run.
if [ -n "${BOOTSTRAP_DRY_RUN:-}" ]; then
  # For non-custom tiers, plan_render computes packages from tier.
  # For custom tiers in non-interactive mode there's no way to specify
  # packages on the command line yet, so the tier defaults to
  # 'recommended' and custom isn't reachable. Pass empty CSV.
  plan_render "$SELECTED_TIER" "$WORKSPACE_PATH" ""
  exit 0
fi

if workspace_ensure_dir "$WORKSPACE_PATH"; then
  log_installed "Workspace: $WORKSPACE_PATH"
else
  log_error "Could not create workspace directory: $WORKSPACE_PATH. Choose a folder you can write to, like ~/code, then run this installer again."
fi

if workspace_write_state "$HOME/.config/ai-bootstrap/state.sh" "$WORKSPACE_PATH"; then
  log_installed "Workspace path saved to ~/.config/ai-bootstrap/state.sh"
else
  log_error "Could not save the workspace setting. Check permissions for ~/.config/ai-bootstrap, then run this installer again."
fi

export AI_BOOTSTRAP_WORKSPACE="$WORKSPACE_PATH"

# ── Run modules for selected packages ────────────────────────────────
# Map package keys to module scripts.
module_display_name() {
  local module_file="$1"

  case "$module_file" in
    02a-bash.sh) echo "Bash" ;;
    03-terminal.sh) echo "Ghostty" ;;
    04-git.sh) echo "Git and GitHub CLI" ;;
    05-editor.sh) echo "VS Code" ;;
    06-runtime.sh) echo "JavaScript runtime" ;;
    07-python.sh) echo "Python runtime" ;;
    08-cli-tools.sh) echo "CLI tools" ;;
    09-opencode.sh) echo "OpenCode" ;;
    10-shell-config.sh) echo "Shell configuration" ;;
    11-local-ai.sh) echo "Local AI tools" ;;
    12-containers.sh) echo "Containers" ;;
    13-extras.sh) echo "Extras" ;;
    *)
      local name="${module_file%.sh}"
      case "$name" in
        [0-9][0-9]-*) name="${name#??-}" ;;
        [0-9][0-9][a-z]-*) name="${name#???-}" ;;
      esac
      echo "${name//-/ }"
      ;;
  esac
}

run_module_isolated() {
  local module_file="$1"
  local module_path="${BOOTSTRAP_DIR}/modules/${module_file}"

  if [ ! -f "$module_path" ]; then
    return 0
  fi

  local module_rc
  set +e
  # shellcheck disable=SC1090
  source "$module_path"
  module_rc=$?
  set -e

  if [ "$module_rc" -ne 0 ]; then
    local module_name
    module_name="$(module_display_name "$module_file")"
    log_error "Module failed: $module_name (exit $module_rc)"
    RESULTS_FAILED+=("$module_name")
  fi

  return 0
}

run_module_if_selected() {
  local module_file="$1"
  shift
  local required_packages=("$@")

  local dominated=false
  for pkg in "${required_packages[@]}"; do
    for sel in "${SELECTED_PACKAGES[@]}"; do
      if [ "$sel" = "$pkg" ]; then
        dominated=true
        break 2
      fi
    done
  done

  if $dominated && [ -f "${BOOTSTRAP_DIR}/modules/${module_file}" ]; then
    run_module_isolated "$module_file"
  fi
}

# Modules 00-02 already ran above. Run the rest in order.
# 02a (bash) is foundational — installs Homebrew bash 5.x so downstream
# tooling and the user's own shell sessions get a modern bash. macOS
# ships 3.2; see zsh_init_plan.md Phase 7.5 and modules/02a-bash.sh.
run_module_if_selected "02a-bash.sh" "bash"
run_module_if_selected "03-terminal.sh" "ghostty"
run_module_if_selected "04-git.sh" "git" "gh"
run_module_if_selected "05-editor.sh" "vscode"
run_module_if_selected "06-runtime.sh" "mise" "node_lts"
run_module_if_selected "07-python.sh" "uv" "python"
run_module_if_selected "08-cli-tools.sh" "ripgrep" "jq" "fd" "direnv" "tmux" "btop"
run_module_if_selected "09-opencode.sh" "opencode"
# 10-shell-config.sh runs UNCONDITIONALLY (per zsh_init_plan.md §5.1 / rev-3 C1):
# previously gated on zplug-tier packages, which left Essential-tier users
# without working PATH config. Per-tool conditionals now live inside the module.
run_module_isolated "10-shell-config.sh"
run_module_if_selected "11-local-ai.sh" "ollama" "lm_studio"
run_module_if_selected "12-containers.sh" "orbstack"
run_module_if_selected "13-extras.sh" "playwright" "shfmt" "ffmpeg" "imagemagick"

# ── Summary ───────────────────────────────────────────────────────────
echo ""
ui_header "📋 Installation Summary"
echo ""

if [ ${#RESULTS_INSTALLED[@]} -gt 0 ]; then
  log_installed "Installed (${#RESULTS_INSTALLED[@]}): ${RESULTS_INSTALLED[*]}"
fi

if [ ${#RESULTS_SKIPPED[@]} -gt 0 ]; then
  log_skip "Already installed (${#RESULTS_SKIPPED[@]}): ${RESULTS_SKIPPED[*]}"
fi

if [ ${#RESULTS_FAILED[@]} -gt 0 ]; then
  log_error "Failed (${#RESULTS_FAILED[@]}): ${RESULTS_FAILED[*]}"
fi

# ── Brewfile snapshot ────────────────────────────────────────────────
# Dump the user's full brew state to ~/.config/ai-bootstrap/Brewfile so
# they can replay this setup on a new Mac with `brew bundle`. Includes
# everything they have brewed, not just what bootstrap installed — the
# point is reproducibility of the user's machine, not auditing what we
# touched.
brewfile_path="$HOME/.config/ai-bootstrap/Brewfile"
summary_brewfile_path=""
if brewfile_dump "$brewfile_path" >/dev/null; then
  summary_brewfile_path="$brewfile_path"
  log_installed "Brewfile saved to $brewfile_path"
else
  # Non-fatal — the bootstrap still succeeded; the user just doesn't get
  # a portable record this run. Most likely cause: brew not on PATH, which
  # only happens if the homebrew module was skipped/failed.
  log_warn "Could not save Brewfile (brew not available?); skipping"
fi

# ── State snapshot ───────────────────────────────────────────────────
# Re-write state.sh with the full set of run metadata (workspace, tier,
# version, first/last-run timestamps). The early workspace_write_state
# call earlier in this script already wrote the workspace anchor; this
# call layers tier/version/timestamps on top and preserves first-run-at
# across re-runs.
state_path="$HOME/.config/ai-bootstrap/state.sh"
if state_write "$state_path" "$WORKSPACE_PATH" "$SELECTED_TIER" "$BOOTSTRAP_DIR"; then
  log_installed "State saved to $state_path"
else
  log_warn "Could not update state file at $state_path"
fi

if [ -z "${BOOTSTRAP_DRY_RUN:-}" ]; then
  summary_launcher_path=""
  if [ "${launcher_result:-}" = "installed" ] && [ -n "${LAUNCHER_DEST:-}" ]; then
    summary_launcher_path="${LAUNCHER_DEST:-}/Just Vibes.app"
  fi

  if [ ${#RESULTS_FAILED[@]} -gt 0 ]; then
    summary_print_failure \
      "$WORKSPACE_PATH" \
      "$SELECTED_TIER" \
      "$summary_brewfile_path" \
      "$summary_launcher_path" \
      "${RESULTS_FAILED[@]}"
    exit 1
  fi

  bootstrap_handle_pending_breadcrumbs

  summary_print \
    "$WORKSPACE_PATH" \
    "$SELECTED_TIER" \
    "$summary_brewfile_path" \
    "$summary_launcher_path"
fi
