#!/usr/bin/env bash
set -uo pipefail

# bootstrap-doctor — audit repository invariants assumed by the bootstrap.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${BOOTSTRAP_DOCTOR_REPO_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# shellcheck source=./scripts/lib/common.sh
source "${REPO_ROOT}/scripts/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: bootstrap-doctor [options]

Audit bootstrap repo invariants.

Options:
  --json              Output structured JSON instead of human-readable text.
  -h, --help          Show this help.

Exit codes:
  0   All invariant checks passed (warnings may be present).
  1   One or more invariant checks failed.
  2   Usage error.
  3   Missing dependency (jq is required).
EOF
}

JSON=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --json)
      JSON=1
      shift
      ;;
    -*)
      die_usage "unknown flag: $1"
      ;;
    *)
      die_usage "unexpected argument: $1"
      ;;
  esac
done

if declare -F require_cmd >/dev/null 2>&1; then
  require_cmd "jq"
elif ! command -v jq >/dev/null 2>&1; then
  if declare -F die_missing_dep >/dev/null 2>&1; then
    die_missing_dep "'jq' is required but not found."
  else
    printf 'Missing dependency: %s\n' "'jq' is required but not found." >&2
    exit 3
  fi
fi

CHECKS_JSON_FILE="$(mktemp "${TMPDIR:-/tmp}/bootstrap-doctor.XXXXXX")"
trap 'rm -f "$CHECKS_JSON_FILE"' EXIT

PASS_CHECKS=()
FAIL_CHECKS=()
WARN_CHECKS=()

record() {
  local category="$1"
  local name="$2"
  local status="$3"
  local detail="${4:-}"
  local symbol=""

  case "$status" in
    pass)
      PASS_CHECKS+=("${category}:${name}")
      symbol="✓"
      ;;
    fail)
      FAIL_CHECKS+=("${category}:${name}")
      symbol="✗"
      ;;
    warn)
      WARN_CHECKS+=("${category}:${name}")
      symbol="!"
      ;;
    *)
      status="fail"
      detail="invalid status '${status}' for ${category}:${name}"
      FAIL_CHECKS+=("${category}:${name}")
      symbol="✗"
      ;;
  esac

  jq -n \
    --arg category "$category" \
    --arg name "$name" \
    --arg status "$status" \
    --arg detail "$detail" \
    '{category: $category, name: $name, status: $status, detail: $detail}' \
    >>"$CHECKS_JSON_FILE"

  if [[ "$JSON" -eq 0 ]]; then
    if [[ -n "$detail" ]]; then
      printf '  %s %-42s %s\n' "$symbol" "$name" "$detail"
    else
      printf '  %s %s\n' "$symbol" "$name"
    fi
  fi
}

section() {
  [[ "$JSON" -eq 1 ]] && return 0
  printf '\n%s:\n' "$1"
}

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

check_bash_syntax_for_glob() {
  local category="$1"
  local label="$2"
  local pattern="$3"
  local file output saw_file=0

  section "$label syntax"
  for file in $pattern; do
    [[ -f "$file" ]] || continue
    saw_file=1
    if output="$(bash -n "$file" 2>&1)"; then
      record "$category" "${file#"$REPO_ROOT/"} syntax" "pass"
    else
      record "$category" "${file#"$REPO_ROOT/"} syntax" "fail" "$output"
    fi
  done

  if [[ "$saw_file" -eq 0 ]]; then
    record "$category" "${label} syntax" "fail" "no files matched ${pattern#"$REPO_ROOT/"}"
  fi
}

check_no_set_e() {
  local file matches saw_file=0

  section "strict mode policy"
  for file in "$REPO_ROOT"/lib/*.sh "$REPO_ROOT"/modules/*; do
    [[ -f "$file" ]] || continue
    saw_file=1
    matches="$(grep -nE '^[[:space:]]*set[[:space:]].*-[A-Za-z]*e[A-Za-z]*|^[[:space:]]*set[[:space:]]+-o[[:space:]]+errexit' "$file" 2>/dev/null || true)"
    if [[ -n "$matches" ]]; then
      record "strict-mode" "${file#"$REPO_ROOT/"} no set -e" "fail" "${matches%%$'\n'*}"
    else
      record "strict-mode" "${file#"$REPO_ROOT/"} no set -e" "pass"
    fi
  done

  if [[ "$saw_file" -eq 0 ]]; then
    record "strict-mode" "lib/modules no set -e" "fail" "no lib or module files found"
  fi
}

collect_module_refs() {
  local cfg ref base
  local refs=()

  for cfg in "$REPO_ROOT/config/packages.sh" "$REPO_ROOT/config/tiers.sh"; do
    [[ -f "$cfg" ]] || continue
    while IFS= read -r ref; do
      [[ -n "$ref" ]] || continue
      base="$(basename "$ref")"
      array_contains "$base" "${refs[@]}" || refs+=("$base")
    done < <(grep -Eoh 'modules/[[:alnum:]_.-]+\.sh|[0-9][0-9][[:alnum:]]?-[[:alnum:]_-]+\.sh' "$cfg" 2>/dev/null || true)
  done

  printf '%s\n' "${refs[@]}"
}

check_module_refs() {
  local ref saw_ref=0

  section "module references"
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    saw_ref=1
    if [[ -f "$REPO_ROOT/modules/$ref" ]]; then
      record "module-refs" "module ref: $ref" "pass" "modules/$ref"
    else
      record "module-refs" "module ref: $ref" "fail" "missing modules/$ref"
    fi
  done < <(collect_module_refs)

  if [[ "$saw_ref" -eq 0 ]]; then
    record "module-refs" "config module refs" "pass" "no module filenames referenced"
  fi
}

declare -A TEST_OVERRIDES=(
  [args]="test_args_lib.bats"
  [brewfile]="test_brewfile_lib.bats"
  [checks]="test_checks.bats"
  [common]="test_common.bats"
  [ghostty]="test_ghostty_lib.bats"
  [git]="test_git_lib.bats"
  [launcher]="test_launcher_lib.bats"
  [opencode]="test_opencode_lib.bats"
  [paths_check]="test_check_paths.bats"
  [plan]="test_plan_lib.bats"
  [state]="test_state_lib.bats"
  [ui]="test_ui.bats"
  [workspace]="test_workspace_lib.bats"
  [summary]="test_summary_lib.bats"
)

expected_lib_test() {
  local base="$1"
  if [[ -n "${TEST_OVERRIDES[$base]:-}" ]]; then
    printf '%s\n' "${TEST_OVERRIDES[$base]}"
  else
    printf 'test_%s.bats\n' "$base"
  fi
}

check_lib_tests() {
  local file base expected

  section "library tests"
  for file in "$REPO_ROOT"/lib/*.sh; do
    [[ -f "$file" ]] || continue
    base="$(basename "$file" .sh)"
    expected="$(expected_lib_test "$base")"
    if [[ -f "$REPO_ROOT/tests/$expected" ]]; then
      record "lib-tests" "lib/${base}.sh test" "pass" "tests/$expected"
    elif [[ "$base" == "version" ]]; then
      record "lib-tests" "lib/${base}.sh test" "warn" "no tests/$expected (accepted for version.sh)"
    else
      record "lib-tests" "lib/${base}.sh test" "fail" "missing tests/$expected"
    fi
  done
}

check_dotfile_refs() {
  local barrel line rel saw_ref=0

  section "dotfile references"
  for barrel in "$REPO_ROOT"/dotfiles/init_*.zsh; do
    [[ -f "$barrel" ]] || continue
    while IFS= read -r line; do
      if [[ "$line" =~ \$\{_AI_BOOTSTRAP_SHELL_DIR\}/([^\"\)]+) ]]; then
        rel="${BASH_REMATCH[1]}"
        [[ "$rel" == *"*"* ]] && continue
        saw_ref=1
        if [[ -f "$REPO_ROOT/dotfiles/$rel" ]]; then
          record "dotfiles" "dotfile ref: $rel" "pass" "${barrel#"$REPO_ROOT/"}"
        else
          record "dotfiles" "dotfile ref: $rel" "fail" "missing dotfiles/$rel (${barrel#"$REPO_ROOT/"})"
        fi
      fi
    done < <(grep -E '^[[:space:]]*(&&[[:space:]]*)?source[[:space:]]+"' "$barrel" 2>/dev/null || true)
  done

  if [[ "$saw_ref" -eq 0 ]]; then
    record "dotfiles" "init barrel refs" "warn" "no init barrel source refs found"
  fi
}

template_json_strings() {
  local template="$1"

  case "$template" in
    *.jsonc.template)
      sed 's|//.*||' "$template" | jq -r '.. | strings?' 2>/dev/null
      ;;
    *)
      jq -r '.. | strings?' "$template" 2>/dev/null
      ;;
  esac
}

check_opencode_template_refs() {
  local template ref normalized saw_template=0 saw_ref=0

  section "opencode template references"
  for template in "$REPO_ROOT"/opencode/*.template; do
    [[ -f "$template" ]] || continue
    saw_template=1

    if template_json_strings "$template" >/dev/null; then
      record "opencode" "${template#"$REPO_ROOT/"} parse" "pass"
    else
      record "opencode" "${template#"$REPO_ROOT/"} parse" "fail" "template is not parseable JSON/JSONC"
      continue
    fi

    while IFS= read -r ref; do
      [[ -n "$ref" ]] || continue
      [[ "$ref" == http://* || "$ref" == https://* ]] && continue
      [[ "$ref" == @* ]] && continue
      [[ "$ref" == \$* ]] && continue
      [[ "$ref" != */* ]] && continue
      normalized="${ref#./}"
      [[ "$normalized" == .opencode/* ]] && continue
      saw_ref=1
      if [[ -f "$REPO_ROOT/opencode/$normalized" ]]; then
        record "opencode" "opencode ref: $normalized" "pass" "${template#"$REPO_ROOT/"}"
      else
        record "opencode" "opencode ref: $normalized" "fail" "missing opencode/$normalized (${template#"$REPO_ROOT/"})"
      fi
    done < <(template_json_strings "$template")
  done

  if [[ "$saw_template" -eq 0 ]]; then
    record "opencode" "opencode templates" "fail" "no opencode/*.template files found"
  elif [[ "$saw_ref" -eq 0 ]]; then
    record "opencode" "opencode template refs" "pass" "no local file refs found"
  fi
}

check_repo_files() {
  local required file
  required=(
    "README.md"
    "LICENSE"
    "bootstrap.sh"
    "install.sh"
    "config/packages.sh"
    "config/tiers.sh"
    "scripts/lib/common.sh"
    ".github/workflows/ci.yml"
  )

  section "repo files"
  for file in "${required[@]}"; do
    if [[ -f "$REPO_ROOT/$file" ]]; then
      record "repo-files" "repo file: $file" "pass"
    else
      record "repo-files" "repo file: $file" "fail" "missing $file"
    fi
  done
}

if [[ "$JSON" -eq 0 ]]; then
  printf 'bootstrap-doctor: auditing %s\n' "$REPO_ROOT"
fi

check_bash_syntax_for_glob "syntax" "lib" "$REPO_ROOT/lib/*.sh"
check_bash_syntax_for_glob "syntax" "modules" "$REPO_ROOT/modules/*"
check_no_set_e
check_module_refs
check_lib_tests
check_dotfile_refs
check_opencode_template_refs
check_repo_files

PASS_COUNT="${#PASS_CHECKS[@]}"
FAIL_COUNT="${#FAIL_CHECKS[@]}"
WARN_COUNT="${#WARN_CHECKS[@]}"
OK="true"
[[ "$FAIL_COUNT" -gt 0 ]] && OK="false"

if [[ "$JSON" -eq 1 ]]; then
  jq -n \
    --slurpfile checks "$CHECKS_JSON_FILE" \
    --argjson pass "$PASS_COUNT" \
    --argjson fail "$FAIL_COUNT" \
    --argjson warn "$WARN_COUNT" \
    --argjson ok "$OK" \
    '{version: 1, ok: $ok, summary: {pass: $pass, fail: $fail, warn: $warn}, checks: $checks}'
else
  printf '\nsummary: %s pass, %s fail, %s warn\n' "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT"
  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    printf 'result: FAIL\n'
  else
    printf 'result: OK\n'
  fi
fi

[[ "$FAIL_COUNT" -eq 0 ]] || exit 1
