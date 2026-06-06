#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  redact-secrets.sh redact [file|-]

Reads text from a file or stdin and writes scrubbed text to stdout.
EOF
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

if [ "${1:-}" != "redact" ]; then
  usage >&2
  exit 2
fi

input="${2:--}"

if [ "$input" = "-" ]; then
  perl -0pe '
    s{-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----}{[REDACTED_PRIVATE_KEY]}gs;
    s{\b(?:AKIA|ASIA)[A-Z0-9]{16}\b}{[REDACTED_AWS_ACCESS_KEY]}g;
    s{\bBearer\s+[A-Za-z0-9._~+/=-]{16,}\b}{Bearer [REDACTED_BEARER_TOKEN]}gi;
    s{\b((?:api[_-]?key|access[_-]?token|refresh[_-]?token|auth[_-]?token|secret|client[_-]?secret|password)\s*[:=]\s*)["'"'"']?[A-Za-z0-9._~+/=-]{16,}["'"'"']?}{${1}[REDACTED_SECRET]}gi;
    s{\b((?:API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|AUTH_TOKEN|SECRET|CLIENT_SECRET|PASSWORD)\s*=\s*)["'"'"']?[A-Za-z0-9._~+/=-]{16,}["'"'"']?}{${1}[REDACTED_SECRET]}g;
    s{\b([a-z][a-z0-9+.-]*://)([^/\s:@]+):([^/\s@]+)@}{${1}[REDACTED_URL_CREDENTIALS]@}gi;
  '
else
  if [ ! -f "$input" ]; then
    printf 'redact-secrets.sh: file not found: %s\n' "$input" >&2
    exit 1
  fi
  perl -0pe '
    s{-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----.*?-----END [A-Z0-9 ]*PRIVATE KEY-----}{[REDACTED_PRIVATE_KEY]}gs;
    s{\b(?:AKIA|ASIA)[A-Z0-9]{16}\b}{[REDACTED_AWS_ACCESS_KEY]}g;
    s{\bBearer\s+[A-Za-z0-9._~+/=-]{16,}\b}{Bearer [REDACTED_BEARER_TOKEN]}gi;
    s{\b((?:api[_-]?key|access[_-]?token|refresh[_-]?token|auth[_-]?token|secret|client[_-]?secret|password)\s*[:=]\s*)["'"'"']?[A-Za-z0-9._~+/=-]{16,}["'"'"']?}{${1}[REDACTED_SECRET]}gi;
    s{\b((?:API_KEY|ACCESS_TOKEN|REFRESH_TOKEN|AUTH_TOKEN|SECRET|CLIENT_SECRET|PASSWORD)\s*=\s*)["'"'"']?[A-Za-z0-9._~+/=-]{16,}["'"'"']?}{${1}[REDACTED_SECRET]}g;
    s{\b([a-z][a-z0-9+.-]*://)([^/\s:@]+):([^/\s@]+)@}{${1}[REDACTED_URL_CREDENTIALS]@}gi;
  ' "$input"
fi
