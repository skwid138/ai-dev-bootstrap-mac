#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -uo pipefail
fi

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"

usage() {
  cat <<'EOF'
Usage:
  chrome_mcp.sh [options]

Options:
  -F, --foreground           Run Chrome directly in the terminal.
  -D, --detached             Launch Chrome as a normal macOS app (default).
  -v, --verbose              Enable Chrome logging.
  -U, --url URL              Open Chrome to a specific URL.
  -T, --new-tab              Open URL in a new tab when practical.
  -W, --new-window           Open URL in a new window.
  -C, --check                Exit 0 only when this helper's Chrome is running.
  -K, --kill                 Stop only this helper's matching Chrome instance.
  -p, --port PORT            Remote debugging port (default: 9222).
  -u, --user-data-dir PATH   Chrome profile directory.
                              Default: /tmp/chrome-devtools-mcp-auth
  -h, --help                 Show this help.

Exit codes:
  0   Success / matching Chrome is running (--check)
  1   Matching Chrome is not running (--check) or Chrome did not become ready
  2   Usage error
  3   Google Chrome is not installed in /Applications
EOF
}

escape_applescript_string() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

matching_instance_pids() {
  local port_flag="--remote-debugging-port=${PORT}"
  local profile_flag="--user-data-dir=${USER_DATA_DIR}"

  # shellcheck disable=SC2009 # Need both-flags AND-match; pgrep ERE risks matching unrelated Chrome.
  ps ax -ww -o pid= -o command= \
    | grep -F -- "$port_flag" \
    | grep -F -- "$profile_flag" \
    | while read -r pid _; do
      case "$pid" in
        '' | *[!0-9]*) continue ;;
      esac
      printf '%s\n' "$pid"
    done
}

matching_instance_running() {
  [ -n "$(matching_instance_pids)" ]
}

devtools_endpoint_ready() {
  curl -fsS "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1
}

any_devtools_endpoint_on_port() {
  curl -fsS --max-time 1 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1
}

port_has_listener() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi

  any_devtools_endpoint_on_port
}

stop_matching_instances() {
  local pids="$1"
  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    kill "$pid" 2>/dev/null || true
  done <<<"$pids"
}

wait_for_devtools() {
  local elapsed=0
  while [ "$elapsed" -lt "$WAIT_SECONDS" ]; do
    if matching_instance_running && devtools_endpoint_ready; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

refuse_if_port_owned_elsewhere() {
  if matching_instance_running; then
    return 0
  fi

  if port_has_listener; then
    printf 'Chrome debugging port %s is already in use, but not by this helper. I will not attach to it.\n' "$PORT" >&2
    return 1
  fi

  return 0
}

open_url_in_new_tab_applescript() {
  local escaped_url
  escaped_url="$(escape_applescript_string "$1")"

  osascript <<EOF
tell application "$CHROME_APP"
  activate
  if (count of windows) = 0 then
    make new window
  end if
  tell front window
    set newTab to make new tab at end of tabs with properties {URL:"$escaped_url"}
    set active tab index to (count of tabs)
  end tell
end tell
EOF
}

# If the script is being sourced (e.g. by bats), stop here.
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # shellcheck disable=SC2317  # `return` may fail outside sourced context; fallback intentional
  return 0 2>/dev/null || true
fi

CHROME_APP="Google Chrome"
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PORT="9222"
USER_DATA_DIR="/tmp/chrome-devtools-mcp-auth"
MODE="detached"
VERBOSE=0
URL=""
OPEN_TARGET="default" # default | tab | window
ACTION="run"          # run | check | kill
WAIT_SECONDS=15

while [[ $# -gt 0 ]]; do
  case "$1" in
    -F | --foreground)
      MODE="foreground"
      shift
      ;;
    -D | --detached)
      MODE="detached"
      shift
      ;;
    -v | --verbose)
      VERBOSE=1
      shift
      ;;
    -U | --url)
      [[ $# -ge 2 ]] || die_usage "Missing value for $1"
      URL="$2"
      shift 2
      ;;
    -C | --check)
      ACTION="check"
      shift
      ;;
    -K | --kill)
      ACTION="kill"
      shift
      ;;
    -T | --new-tab)
      [[ "$OPEN_TARGET" == "window" ]] && die_usage "Cannot use --new-tab and --new-window together"
      OPEN_TARGET="tab"
      shift
      ;;
    -W | --new-window)
      [[ "$OPEN_TARGET" == "tab" ]] && die_usage "Cannot use --new-tab and --new-window together"
      OPEN_TARGET="window"
      shift
      ;;
    -p | --port)
      [[ $# -ge 2 ]] || die_usage "Missing value for $1"
      PORT="$2"
      shift 2
      ;;
    -u | --user-data-dir)
      [[ $# -ge 2 ]] || die_usage "Missing value for $1"
      USER_DATA_DIR="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$ACTION" in
  check)
    if matching_instance_running && devtools_endpoint_ready; then
      exit 0
    fi
    exit 1
    ;;
  kill)
    pids="$(matching_instance_pids)"
    if [ -z "$pids" ]; then
      warn "No matching Chrome helper instance found"
      exit 0
    fi
    stop_matching_instances "$pids"
    info "Stopped the Chrome helper instance on port ${PORT}"
    exit 0
    ;;
esac

if [[ ! -x "$CHROME_BIN" ]]; then
  die_missing_dep "Google Chrome is not installed at /Applications/Google Chrome.app. Install Chrome, then try /check-my-site again."
fi

if ! refuse_if_port_owned_elsewhere; then
  exit 1
fi

COMMON_ARGS=(
  "--remote-debugging-port=${PORT}"
  "--user-data-dir=${USER_DATA_DIR}"
)

if [[ "$VERBOSE" -eq 1 ]]; then
  if [[ "$MODE" == "foreground" ]]; then
    COMMON_ARGS+=("--enable-logging=stderr" "--log-level=0" "--v=1")
  else
    COMMON_ARGS+=("--enable-logging" "--log-level=0" "--v=1")
  fi
fi

if [[ "$OPEN_TARGET" == "window" ]]; then
  COMMON_ARGS+=("--new-window")
fi

if matching_instance_running; then
  info "Matching Chrome helper instance is already running on port ${PORT}"
  if [[ "$OPEN_TARGET" == "tab" && -n "$URL" ]]; then
    open_url_in_new_tab_applescript "$URL"
  elif [[ -n "$URL" ]]; then
    open -na "$CHROME_APP" "$URL" --args "${COMMON_ARGS[@]}"
  fi

  if wait_for_devtools; then
    exit 0
  fi
  warn "Matching Chrome helper instance looked stale; restarting it"
  stop_matching_instances "$(matching_instance_pids)"
  sleep 1
fi

if [[ "$MODE" == "foreground" ]]; then
  info "Starting Chrome in foreground mode on port ${PORT}"
  info "Profile: ${USER_DATA_DIR}"
  if [[ -n "$URL" ]]; then
    exec "$CHROME_BIN" "${COMMON_ARGS[@]}" "$URL"
  fi
  exec "$CHROME_BIN" "${COMMON_ARGS[@]}"
fi

info "Starting Chrome in detached mode on port ${PORT}"
info "Profile: ${USER_DATA_DIR}"

if [[ "$OPEN_TARGET" == "tab" && -n "$URL" ]]; then
  warn "No matching Chrome helper instance found; opening a new window instead"
fi

if [[ -n "$URL" ]]; then
  info "Opening URL: ${URL}"
  open -na "$CHROME_APP" "$URL" --args "${COMMON_ARGS[@]}"
else
  open -na "$CHROME_APP" --args "${COMMON_ARGS[@]}"
fi

if wait_for_devtools; then
  exit 0
fi

printf 'Chrome opened, but it was not ready for checking within %s seconds.\n' "$WAIT_SECONDS" >&2
exit 1
