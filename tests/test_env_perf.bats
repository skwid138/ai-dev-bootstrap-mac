#!/usr/bin/env bats
# Performance budget for env-tier (init_env.zsh).
#
# The env tier runs in EVERY shell zsh starts — login, non-login, scripts,
# subshells. Tool launchers (JustVibes, opencode, GUI integrations) spawn
# many short-lived shells per second; a 50ms cost per spawn is a multi-second
# UX regression.
#
# Methodology:
#   - Spawn a fresh `zsh -c` subshell with HOME=$SANDBOX.
#   - The subshell uses zsh's high-resolution $EPOCHREALTIME (zsh/datetime
#     module) to bracket the source call.
#   - Repeat N times, take the median to reduce CI jitter (mean is too
#     sensitive to GHA noisy-neighbor outliers).
#
# Tunables (env vars):
#   BATS_SKIP_PERF=1                  → skip this entire file (CI runners
#                                       under heavy load, slow VMs).
#   BATS_PERF_BUDGET_P50_MS=<int>     → override budget (default 50ms).
#   BATS_PERF_RUNS=<int>              → override sample count (default 25).
#
# Why a budget at all? §6.1 lists this file as the regression guard for the
# env-tier silence + speed contract. A future PR adding `mise activate` or
# `eval $(direnv hook zsh)` to env-tier would blow this budget by 10–100x.

bats_require_minimum_version 1.5.0

setup() {
  if [ "${BATS_SKIP_PERF:-0}" = "1" ]; then
    skip "env-tier perf budget skipped via BATS_SKIP_PERF=1"
  fi

  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR

  SANDBOX="$(mktemp -d)"
  export SANDBOX
  export HOME="$SANDBOX"

  BREW_PREFIX="$SANDBOX/brew"
  mkdir -p "$BREW_PREFIX/bin" "$BREW_PREFIX/sbin"
  export BREW_PREFIX

  install_dir="$HOME/.config/ai-bootstrap/shell"
  mkdir -p "$install_dir"/{env,lib,profile,rc}
  cp "$BOOTSTRAP_DIR/dotfiles/init_env.zsh" "$install_dir/init_env.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/lib/path_helpers.zsh" "$install_dir/lib/path_helpers.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/env/vars.zsh" "$install_dir/env/vars.zsh"
  cp "$BOOTSTRAP_DIR/dotfiles/env/paths.zsh" "$install_dir/env/paths.zsh"
  sed -i.bak "s|__BREW_PREFIX__|${BREW_PREFIX}|g" "$install_dir/env/paths.zsh"
  rm -f "$install_dir/env/paths.zsh.bak"
}

teardown() {
  if [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ]; then
    rm -rf "$SANDBOX"
  fi
}

# Median calculator: prints the median of stdin (one float per line) in ms,
# rounded to integer. Pure bash; no jq/python dependency.
median_ms() {
  local sorted
  sorted=$(sort -n)
  local n
  n=$(printf '%s\n' "$sorted" | wc -l | tr -d ' ')
  local mid=$((n / 2))
  printf '%s\n' "$sorted" | awk -v m="$mid" -v n="$n" '
    NR == m + 1 && (n % 2 == 1) { printf "%d\n", $1 + 0.5; exit }
    NR == m && (n % 2 == 0) { a = $1; next }
    NR == m + 1 && (n % 2 == 0) { printf "%d\n", (a + $1) / 2 + 0.5; exit }
  '
}

@test "env-tier source cost: median across N runs is under budget" {
  local runs="${BATS_PERF_RUNS:-25}"
  local budget_ms="${BATS_PERF_BUDGET_P50_MS:-50}"

  local times_ms=()
  local i
  for i in $(seq 1 "$runs"); do
    # Each iteration is a fresh subshell — no cross-iteration cache effects
    # leak in (modulo OS-level filesystem caching, which is the realistic
    # production state anyway since shells spawn frequently).
    local t
    t=$(zsh -c "
      zmodload zsh/datetime
      HOME='$HOME'
      local start=\$EPOCHREALTIME
      source '$HOME/.config/ai-bootstrap/shell/init_env.zsh'
      local end=\$EPOCHREALTIME
      # Print elapsed in ms as integer.
      printf '%d\n' \$(( (end - start) * 1000 ))
    ") || {
      echo "iteration $i failed" >&2
      return 1
    }
    times_ms+=("$t")
  done

  # Compute median.
  local p50
  p50=$(printf '%s\n' "${times_ms[@]}" | median_ms)

  echo "env-tier source: runs=$runs budget=${budget_ms}ms p50=${p50}ms" >&3
  echo "samples (ms): ${times_ms[*]}" >&3

  # Assert under budget.
  [ "$p50" -lt "$budget_ms" ]
}

@test "env-tier source cost: max single sample under 3x budget (jitter guard)" {
  # Catch pathological outliers (e.g. a `sleep` accidentally added to env-tier)
  # that could pass the median check if only one of N runs is slow.
  local runs="${BATS_PERF_RUNS:-25}"
  local budget_ms="${BATS_PERF_BUDGET_P50_MS:-50}"
  local max_budget_ms=$((budget_ms * 3))

  local max=0
  local i t
  for i in $(seq 1 "$runs"); do
    t=$(zsh -c "
      zmodload zsh/datetime
      HOME='$HOME'
      local start=\$EPOCHREALTIME
      source '$HOME/.config/ai-bootstrap/shell/init_env.zsh'
      local end=\$EPOCHREALTIME
      printf '%d\n' \$(( (end - start) * 1000 ))
    ")
    if [ "$t" -gt "$max" ]; then
      max="$t"
    fi
  done

  echo "env-tier source max sample: ${max}ms (max-budget=${max_budget_ms}ms)" >&3
  [ "$max" -lt "$max_budget_ms" ]
}
