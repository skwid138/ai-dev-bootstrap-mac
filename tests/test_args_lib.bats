#!/usr/bin/env bats
# Tests for lib/args.sh — argument parsing for bootstrap.sh.
#
# Tests the parser in isolation: fed argv arrays, asserts which env vars
# get exported and what return code comes back. Doesn't run the actual
# bootstrap (that's an integration concern).
#
# bats `run` quirk: when calling a shell function, environment vars set
# *before* `run` are visible to the function, but exports set *inside*
# the function are only visible to the test if we re-source / re-check
# in the test body. We use the latter pattern: call args_parse directly
# (not via run) so its exports are visible.

bats_require_minimum_version 1.5.0

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export BOOTSTRAP_DIR
  # shellcheck source=../lib/args.sh
  source "${BOOTSTRAP_DIR}/lib/args.sh"

  # Wipe any pre-existing flags so each test starts clean.
  unset BOOTSTRAP_DRY_RUN
  unset BOOTSTRAP_NONINTERACTIVE
  unset AI_BOOTSTRAP_NONINTERACTIVE
  unset BOOTSTRAP_LAUNCHER_ONLY
  unset BOOTSTRAP_CHECK_PATHS
  unset BOOTSTRAP_REFRESH_PATHS
  unset BOOTSTRAP_UPDATE
  unset BOOTSTRAP_LIST_MODULES
  unset BOOTSTRAP_MODULE_ONLY
}

teardown() {
  unset BOOTSTRAP_DRY_RUN
  unset BOOTSTRAP_NONINTERACTIVE
  unset AI_BOOTSTRAP_NONINTERACTIVE
  unset BOOTSTRAP_LAUNCHER_ONLY
  unset BOOTSTRAP_CHECK_PATHS
  unset BOOTSTRAP_REFRESH_PATHS
  unset BOOTSTRAP_UPDATE
  unset BOOTSTRAP_LIST_MODULES
  unset BOOTSTRAP_MODULE_ONLY
}

@test "args_parse: no flags leaves all env vars unset" {
  args_parse
  [ -z "${BOOTSTRAP_DRY_RUN:-}" ]
  [ -z "${BOOTSTRAP_NONINTERACTIVE:-}" ]
}

@test "args_parse: --dry-run sets BOOTSTRAP_DRY_RUN=1" {
  args_parse --dry-run
  [ "$BOOTSTRAP_DRY_RUN" = "1" ]
}

@test "args_parse: --dry-run also sets BOOTSTRAP_NONINTERACTIVE (implied)" {
  # Dry-run can't prompt the user, so it implies non-interactive. This
  # contract is what makes the control flow simple ('if dry-run skip
  # Phase 0' + 'if non-interactive use defaults' compose).
  args_parse --dry-run
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
  [ "$AI_BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: --non-interactive sets BOOTSTRAP_NONINTERACTIVE=1" {
  args_parse --non-interactive
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: --non-interactive does NOT imply --dry-run" {
  # Non-interactive runs actually do install — only dry-run is a no-op.
  args_parse --non-interactive
  [ -z "${BOOTSTRAP_DRY_RUN:-}" ]
}

@test "args_parse: --non-interactive sets legacy AI_BOOTSTRAP_NONINTERACTIVE alias" {
  # Backward compat: bootstrap.sh used to check AI_BOOTSTRAP_NONINTERACTIVE
  # in the workspace prompt. Both vars are kept in sync.
  args_parse --non-interactive
  [ "$AI_BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: pre-existing AI_BOOTSTRAP_NONINTERACTIVE env triggers non-interactive" {
  # Lets users set the env var in their shell profile / CI yaml without
  # passing the flag. Equivalent to passing --non-interactive.
  export AI_BOOTSTRAP_NONINTERACTIVE=1
  args_parse
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: combined --dry-run --non-interactive works" {
  args_parse --dry-run --non-interactive
  [ "$BOOTSTRAP_DRY_RUN" = "1" ]
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: --help returns 1" {
  run args_parse --help
  [ "$status" -eq 1 ]
}

@test "bootstrap.sh: --help exits 0" {
  run "${BOOTSTRAP_DIR}/bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"AI Dev Bootstrap for Mac"* ]]
}

@test "args_parse: -h returns 1" {
  run args_parse -h
  [ "$status" -eq 1 ]
}

@test "args_parse: unknown flag returns 2" {
  run args_parse --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown flag: --bogus"* ]]
}

@test "args_parse: unknown flag after a valid flag still returns 2" {
  run args_parse --dry-run --bogus
  [ "$status" -eq 2 ]
}

@test "args_print_help: emits usage" {
  run args_print_help
  [ "$status" -eq 0 ]
  [[ "$output" == *"AI Dev Bootstrap for Mac"* ]]
  [[ "$output" == *"--dry-run"* ]]
  [[ "$output" == *"--non-interactive"* ]]
  [[ "$output" == *"--launcher-only"* ]]
  [[ "$output" == *"--check-paths"* ]]
  [[ "$output" == *"--refresh-paths"* ]]
  [[ "$output" == *"--list-modules"* ]]
  [[ "$output" == *"--module"* ]]
  [[ "$output" == *"--help"* ]]
}

# ── --launcher-only ───────────────────────────────────────────────────────

@test "args_parse: --launcher-only sets BOOTSTRAP_LAUNCHER_ONLY=1" {
  args_parse --launcher-only
  [ "$BOOTSTRAP_LAUNCHER_ONLY" = "1" ]
}

@test "args_parse: --launcher-only implies non-interactive" {
  # No prompts in launcher-only mode — workspace is read from state.sh
  # (or defaults), tier doesn't apply.
  args_parse --launcher-only
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
  [ "$AI_BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: --launcher-only does NOT imply --dry-run" {
  # Launcher-only actually rebuilds the .app — that's its whole point.
  # Only --dry-run is fully side-effect-free.
  args_parse --launcher-only
  [ -z "${BOOTSTRAP_DRY_RUN:-}" ]
}

@test "args_parse: --launcher-only --dry-run composes (rebuild preview)" {
  # The two together let users preview a launcher rebuild without
  # actually doing it. Useful sanity check.
  args_parse --launcher-only --dry-run
  [ "$BOOTSTRAP_LAUNCHER_ONLY" = "1" ]
  [ "$BOOTSTRAP_DRY_RUN" = "1" ]
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

# ── --check-paths (Phase 4.5) ─────────────────────────────────────────────

@test "args_parse: --check-paths sets BOOTSTRAP_CHECK_PATHS=1" {
  args_parse --check-paths
  [ "$BOOTSTRAP_CHECK_PATHS" = "1" ]
}

@test "args_parse: --check-paths implies non-interactive" {
  # Read-only check; nothing to prompt for.
  args_parse --check-paths
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
  [ "$AI_BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: --check-paths does NOT imply --dry-run" {
  # The check is already side-effect-free — --dry-run is a no-op
  # but we don't auto-set it.
  args_parse --check-paths
  [ -z "${BOOTSTRAP_DRY_RUN:-}" ]
}

@test "args_parse: --check-paths --dry-run composes (no-op but allowed)" {
  # An agent that always passes --dry-run for safety should not error.
  args_parse --check-paths --dry-run
  [ "$BOOTSTRAP_CHECK_PATHS" = "1" ]
  [ "$BOOTSTRAP_DRY_RUN" = "1" ]
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

# ── --refresh-paths (Phase 4.5) ───────────────────────────────────────────

@test "args_parse: --refresh-paths sets BOOTSTRAP_REFRESH_PATHS=1" {
  args_parse --refresh-paths
  [ "$BOOTSTRAP_REFRESH_PATHS" = "1" ]
}

@test "args_parse: --refresh-paths implies non-interactive" {
  args_parse --refresh-paths
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
  [ "$AI_BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: --refresh-paths does NOT imply --dry-run" {
  # Refresh actually rewrites files — that's its whole point.
  args_parse --refresh-paths
  [ -z "${BOOTSTRAP_DRY_RUN:-}" ]
}

@test "args_parse: --refresh-paths --dry-run composes (refresh preview)" {
  args_parse --refresh-paths --dry-run
  [ "$BOOTSTRAP_REFRESH_PATHS" = "1" ]
  [ "$BOOTSTRAP_DRY_RUN" = "1" ]
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: --update sets BOOTSTRAP_UPDATE=1" {
  args_parse --update
  [ "$BOOTSTRAP_UPDATE" = "1" ]
}

@test "args_parse: --update implies non-interactive" {
  args_parse --update
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
  [ "$AI_BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

# ── --list-modules / --module ──────────────────────────────────────────────

@test "args_parse: --list-modules sets BOOTSTRAP_LIST_MODULES=1" {
  args_parse --list-modules
  [ "$BOOTSTRAP_LIST_MODULES" = "1" ]
}

@test "args_parse: --list-modules implies non-interactive" {
  args_parse --list-modules
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
  [ "$AI_BOOTSTRAP_NONINTERACTIVE" = "1" ]
}

@test "args_parse: --module without argument returns 2" {
  run args_parse --module
  [ "$status" -eq 2 ]
  [[ "$output" == *"--module requires a module name argument"* ]]
  [[ "$output" == *"--list-modules"* ]]
}

@test "args_parse: --module git sets BOOTSTRAP_MODULE_ONLY=git" {
  args_parse --module git
  [ "$BOOTSTRAP_MODULE_ONLY" = "git" ]
}

@test "args_parse: --module implies non-interactive" {
  args_parse --module git
  [ "$BOOTSTRAP_NONINTERACTIVE" = "1" ]
  [ "$AI_BOOTSTRAP_NONINTERACTIVE" = "1" ]
}
