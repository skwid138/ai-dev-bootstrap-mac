#!/bin/bash
# Tier definitions mapping tier names to package lists.
# Depends on config/packages.sh being sourced first.

# Return package keys for a given tier.
# "recommended" includes essential, "complete" includes recommended.
get_tier_packages() {
  local tier="$1"
  local i

  for i in "${!PACKAGES[@]}"; do
    case "$tier" in
      essential)
        if [ "${PKG_TIERS[$i]}" = "essential" ]; then
          echo "${PACKAGES[$i]}"
        fi
        ;;
      recommended)
        if [ "${PKG_TIERS[$i]}" = "essential" ] || [ "${PKG_TIERS[$i]}" = "recommended" ]; then
          echo "${PACKAGES[$i]}"
        fi
        ;;
      complete)
        echo "${PACKAGES[$i]}"
        ;;
    esac
  done
}

# Human-readable tier descriptions.
get_tier_description() {
  local tier="$1"
  case "$tier" in
    essential)
      echo "Just the basics — everything you need to start vibe-coding"
      ;;
    recommended)
      echo "Basics + a polished shell, better terminal, and handy dev tools"
      ;;
    complete)
      echo "Everything including local AI, containers, and media tools"
      ;;
  esac
}
