# Remote Access helper aliases.
# Loaded only when this file has been installed by the Tailscale add-on module.

[[ ! -f "${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opensession.sh" ]] || alias opensession="${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opensession.sh"
[[ ! -f "${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opencode-web.sh" ]] || alias opencode-web="${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opencode-web.sh"
[[ ! -f "${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opencode-attach.sh" ]] || alias opencode-attach="${AI_BOOTSTRAP_WORKSPACE}/scripts/personal/opencode-attach.sh"
