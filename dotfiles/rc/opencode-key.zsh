# OpenCode Go/Zen API key — loaded from macOS Keychain on interactive shell start.
#
# Why inline `security` instead of keychain_get from scripts/lib/keychain.sh:
# This file runs in every interactive shell. It must not depend on workspace
# scripts being deployed, must not source a chain of helpers, and must be a
# silent no-op when the Keychain entry is absent.
#
# Latency note: `security find-generic-password` returns instantly when the
# login Keychain is unlocked (always true after macOS login). No measurable
# shell startup cost.

if _oc_key="$(security find-generic-password -s 'opencode-api-key' -a "$USER" -w 2>/dev/null)"; then
  export OPENCODE_API_KEY="$_oc_key"
fi
unset _oc_key
