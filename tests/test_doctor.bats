#!/usr/bin/env bats
# Tests for scripts/bootstrap-doctor.sh.

setup() {
  BOOTSTRAP_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  DOCTOR="${BOOTSTRAP_DIR}/scripts/bootstrap-doctor.sh"
  FIXTURE="${BATS_TEST_TMPDIR}/repo"
  export BOOTSTRAP_DIR DOCTOR FIXTURE

  make_valid_fixture
}

make_valid_fixture() {
  mkdir -p \
    "${FIXTURE}/.github/workflows" \
    "${FIXTURE}/config" \
    "${FIXTURE}/dotfiles/env" \
    "${FIXTURE}/dotfiles/lib" \
    "${FIXTURE}/dotfiles/profile" \
    "${FIXTURE}/dotfiles/rc" \
    "${FIXTURE}/lib" \
    "${FIXTURE}/modules" \
    "${FIXTURE}/opencode/agent" \
    "${FIXTURE}/opencode/instruction" \
    "${FIXTURE}/scripts/lib" \
    "${FIXTURE}/tests"

  touch \
    "${FIXTURE}/README.md" \
    "${FIXTURE}/LICENSE" \
    "${FIXTURE}/bootstrap.sh" \
    "${FIXTURE}/install.sh" \
    "${FIXTURE}/.github/workflows/ci.yml"

  cat >"${FIXTURE}/scripts/lib/common.sh" <<'EOF'
#!/usr/bin/env bash
die_missing_dep() {
  printf 'Missing dependency: %s\n' "$*" >&2
  exit 3
}
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die_missing_dep "'$1' is required but not found."
}
EOF

  cat >"${FIXTURE}/lib/common.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
EOF
  touch "${FIXTURE}/tests/test_common.bats"

  cat >"${FIXTURE}/modules/00-one.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
EOF

  cat >"${FIXTURE}/config/packages.sh" <<'EOF'
#!/usr/bin/env bash
PACKAGE_MODULES=("modules/00-one.sh")
EOF
  cat >"${FIXTURE}/config/tiers.sh" <<'EOF'
#!/usr/bin/env bash
# no additional module refs
EOF

  cat >"${FIXTURE}/dotfiles/init_env.zsh" <<'EOF'
_AI_BOOTSTRAP_SHELL_DIR="${HOME}/.config/ai-bootstrap/shell"
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/lib/path_helpers.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/lib/path_helpers.zsh"
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/env/vars.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/env/vars.zsh"
EOF
  cat >"${FIXTURE}/dotfiles/init_profile.zsh" <<'EOF'
_AI_BOOTSTRAP_SHELL_DIR="${HOME}/.config/ai-bootstrap/shell"
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/init_env.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/init_env.zsh"
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/profile/tool_hooks.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/profile/tool_hooks.zsh"
EOF
  cat >"${FIXTURE}/dotfiles/init_rc.zsh" <<'EOF'
_AI_BOOTSTRAP_SHELL_DIR="${HOME}/.config/ai-bootstrap/shell"
[[ -f "${_AI_BOOTSTRAP_SHELL_DIR}/rc/aliases.zsh" ]] \
  && source "${_AI_BOOTSTRAP_SHELL_DIR}/rc/aliases.zsh"
EOF
  touch \
    "${FIXTURE}/dotfiles/lib/path_helpers.zsh" \
    "${FIXTURE}/dotfiles/env/vars.zsh" \
    "${FIXTURE}/dotfiles/profile/tool_hooks.zsh" \
    "${FIXTURE}/dotfiles/rc/aliases.zsh"

  cat >"${FIXTURE}/opencode/opencode.json.template" <<'EOF'
{
  "instructions": ["instruction/repo-context.md"],
  "agent": {"gandalf": "agent/gandalf.md"}
}
EOF
  touch \
    "${FIXTURE}/opencode/instruction/repo-context.md" \
    "${FIXTURE}/opencode/agent/gandalf.md"
}

run_doctor() {
  BOOTSTRAP_DOCTOR_REPO_ROOT="$FIXTURE" run "$DOCTOR" "$@"
}

@test "bootstrap-doctor: --help exits 0 and prints usage" {
  run "$DOCTOR" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: bootstrap-doctor"* ]]
}

@test "bootstrap-doctor: valid repo emits JSON summary with no failures" {
  run_doctor --json
  [ "$status" -eq 0 ]
  json_output="$output"

  echo "$json_output" | jq empty

  run bash -c "jq -r '.ok' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run bash -c "jq -r '.summary.fail' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "bootstrap-doctor: missing jq exits 3" {
  stub_dir="${BATS_TEST_TMPDIR}/no-jq-path"
  mkdir -p "$stub_dir"
  ln -s "$(command -v bash)" "${stub_dir}/bash"
  ln -s "$(command -v dirname)" "${stub_dir}/dirname"

  PATH="$stub_dir" BOOTSTRAP_DOCTOR_REPO_ROOT="$FIXTURE" run "$DOCTOR" --json
  [ "$status" -eq 3 ]
  [[ "$output" == *"Missing dependency"* ]]
  [[ "$output" == *"jq"* ]]
}

@test "bootstrap-doctor: missing lib test fails except version.sh warns" {
  rm -f "${FIXTURE}/tests/test_common.bats"
  cat >"${FIXTURE}/lib/version.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
EOF

  run_doctor --json
  [ "$status" -eq 1 ]
  json_output="$output"

  run bash -c "jq -r '.checks[] | select(.name == \"lib/common.sh test\") | .status' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "fail" ]

  run bash -c "jq -r '.checks[] | select(.name == \"lib/version.sh test\") | .status' <<<\"\$1\"" _ "$json_output"
  [ "$status" -eq 0 ]
  [ "$output" = "warn" ]
}

@test "bootstrap-doctor: set -e in lib or modules fails" {
  cat >"${FIXTURE}/modules/00-one.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
EOF

  run_doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗"* ]]
  [[ "$output" == *"no set -e"* ]]
}

@test "bootstrap-doctor: missing module referenced from config fails" {
  rm -f "${FIXTURE}/modules/00-one.sh"

  run_doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"module ref: 00-one.sh"* ]]
  [[ "$output" == *"missing"* ]]
}

@test "bootstrap-doctor: missing dotfile referenced by init barrel fails" {
  rm -f "${FIXTURE}/dotfiles/env/vars.zsh"

  run_doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"dotfile ref: env/vars.zsh"* ]]
  [[ "$output" == *"missing"* ]]
}

@test "bootstrap-doctor: missing opencode template reference fails" {
  rm -f "${FIXTURE}/opencode/instruction/repo-context.md"

  run_doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"opencode ref: instruction/repo-context.md"* ]]
  [[ "$output" == *"missing"* ]]
}

@test "bootstrap-doctor: missing required repo-level file fails" {
  rm -f "${FIXTURE}/LICENSE"

  run_doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"repo file: LICENSE"* ]]
  [[ "$output" == *"missing"* ]]
}
