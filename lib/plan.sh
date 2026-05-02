#!/bin/bash
# Dry-run plan renderer.
#
# Given a tier name + workspace path, prints a human-readable preview of
# what the bootstrap would install, what files it would touch, and where
# the user's workspace would land. Exits without running any modules.
#
# Design intent:
#
#   `--dry-run` is "show me the plan before I commit," modeled on
#   `terraform plan`. The alternative — actually run modules but stub
#   side effects — would mean ~12 surfaces to gate (3 install helpers +
#   9 modules with direct writes), 30+ extra tests, and every future
#   module author would have to remember to gate their writes.
#
#   Plan-and-exit is correct-by-construction: nothing happens after
#   plan rendering, so nothing CAN drift. That's what users actually
#   want from a dry-run anyway.
#
# What the plan covers:
#
#   1. Tier + workspace path (the two "big" decisions)
#   2. Package list grouped by category (formulae / casks / mise / npm)
#   3. Files that would be written (state.sh, Brewfile, AGENTS.md,
#      ghostty config, opencode assets, .app launcher, shell aliases)
#
# What the plan does NOT cover:
#
#   - Provider/OAuth interactivity (opencode `auth login`) — those are
#     prompts inside modules, can't be predicted ahead of time.
#   - Per-package skip vs. install — would require running `brew list`
#     for every package, which is technically a side effect (network/
#     disk read) and slow. Acceptable tradeoff: show "would attempt to
#     install" for everything; user already knows brew skips dupes.
#
# Depends on PACKAGES, PKG_NAMES, PKG_TYPES, PKG_TIERS, PKG_DESCS being
# loaded (via config/packages.sh).

# ── plan_render ───────────────────────────────────────────────────────────
# Args:
#   $1: tier      — essential|recommended|complete|custom
#   $2: workspace — absolute, validated workspace path
#   $3: packages_csv — comma-separated list of package keys (for custom tier);
#                      ignored for non-custom tiers (computed from tier).
#
# Writes plan to stdout. Returns 0.
plan_render() {
  local tier="$1"
  local workspace="$2"
  local packages_csv="${3:-}"

  echo ""
  echo "========================================"
  echo "  📋 Dry-run plan"
  echo "========================================"
  echo ""
  echo "  Tier:      $tier"
  echo "  Workspace: $workspace"
  echo ""

  # Collect package keys for the tier.
  local -a selected_keys=()
  if [ "$tier" = "custom" ]; then
    # Split CSV into keys.
    local IFS=','
    # shellcheck disable=SC2206
    selected_keys=($packages_csv)
  else
    while IFS= read -r key; do
      [ -z "$key" ] && continue
      selected_keys+=("$key")
    done < <(get_tier_packages "$tier")
  fi

  # Group keys by type for readability.
  local -a formulae=() casks=() mise_runtimes=() npm_packages=() zplug_plugins=() system=()
  local key i
  for key in "${selected_keys[@]}"; do
    for i in "${!PACKAGES[@]}"; do
      if [ "${PACKAGES[$i]}" = "$key" ]; then
        case "${PKG_TYPES[$i]}" in
          formula) formulae+=("${PKG_NAMES[$i]}") ;;
          cask) casks+=("${PKG_NAMES[$i]}") ;;
          mise) mise_runtimes+=("${PKG_NAMES[$i]}") ;;
          npm) npm_packages+=("${PKG_NAMES[$i]}") ;;
          zplug) zplug_plugins+=("${PKG_NAMES[$i]}") ;;
          system) system+=("${PKG_NAMES[$i]}") ;;
        esac
        break
      fi
    done
  done

  echo "  Packages to install:"
  if [ ${#system[@]} -gt 0 ]; then
    echo "    System:        ${system[*]}"
  fi
  if [ ${#formulae[@]} -gt 0 ]; then
    echo "    Brew formulae: ${formulae[*]}"
  fi
  if [ ${#casks[@]} -gt 0 ]; then
    echo "    Brew casks:    ${casks[*]}"
  fi
  if [ ${#mise_runtimes[@]} -gt 0 ]; then
    echo "    Mise runtimes: ${mise_runtimes[*]}"
  fi
  if [ ${#zplug_plugins[@]} -gt 0 ]; then
    echo "    Zsh plugins:   ${zplug_plugins[*]}"
  fi
  if [ ${#npm_packages[@]} -gt 0 ]; then
    echo "    NPM globals:   ${npm_packages[*]}"
  fi

  echo ""
  echo "  Files that would be written:"
  echo "    ~/.config/ai-bootstrap/state.sh    (workspace + tier + version + run timestamps)"
  echo "    ~/.config/ai-bootstrap/Brewfile    (full brew snapshot for reproducibility)"

  # Three-tier shell init dotfiles install for ALL tiers (per zsh_init_plan.md
  # §5.1: shell config is foundational, not optional). Conditional sub-files
  # (zsh_plugins, tool_hooks) are mentioned only when their gating package is
  # selected.
  echo "    ~/.zshenv                          (# ai-bootstrap source line for env-tier)"
  echo "    ~/.zprofile                        (# ai-bootstrap source line for profile-tier)"
  echo "    ~/.zshrc                           (# ai-bootstrap source line for rc-tier)"
  echo "    ~/.config/ai-bootstrap/shell/      (three-tier init: env/, lib/, profile/, rc/)"

  # Conditional file writes — these only happen if the relevant package
  # is selected. Check presence in selected_keys.
  if plan_has_key "ghostty" "${selected_keys[@]}"; then
    echo "    ~/.config/ghostty/config           (terminal config)"
    echo "    ~/Applications/Vibe Code.app       (one-click opencode launcher)"
  fi
  if plan_has_key "opencode" "${selected_keys[@]}"; then
    echo "    ~/.config/opencode/                (agents, skills, commands, MCPs, plugins)"
    echo "    ~/AGENTS.md                        (global AGENTS.md template)"
  fi
  if plan_has_key "git" "${selected_keys[@]}"; then
    echo "    ~/.gitconfig                       (git user.name + user.email if unset)"
  fi
  if plan_has_key "zplug" "${selected_keys[@]}"; then
    echo "    ~/.config/ai-bootstrap/shell/rc/zsh_plugins.zsh  (zplug + Spaceship prompt)"
  fi
  if plan_has_key "mise" "${selected_keys[@]}"; then
    echo "    ~/.config/ai-bootstrap/shell/profile/tool_hooks.zsh  (mise activate)"
  fi
  if plan_has_key "mise" "${selected_keys[@]}" || plan_has_key "direnv" "${selected_keys[@]}"; then
    echo "    ~/.config/ai-bootstrap/shell/rc/tool_hooks.zsh       (mise/direnv interactive hooks)"
  fi

  echo ""
  echo "  Nothing has been changed yet. Run without --dry-run to install."
  echo ""

  return 0
}

# ── plan_has_key ──────────────────────────────────────────────────────────
# Helper: true if $1 is one of the remaining args.
plan_has_key() {
  local needle="$1"
  shift
  local k
  for k in "$@"; do
    if [ "$k" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}
