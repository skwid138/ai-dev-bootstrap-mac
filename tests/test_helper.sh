#!/usr/bin/env bash

setup_test_env() {
  BOOTSTRAP_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export BOOTSTRAP_DIR

  TMP_DIR="$(mktemp -d)"
  export TMP_DIR

  SELECTED_PACKAGES=()
  export SELECTED_PACKAGES

  # Source libraries and config for tests.
  # shellcheck source=lib/ui.sh
  source "${BOOTSTRAP_DIR}/lib/ui.sh"
  # shellcheck source=lib/common.sh
  source "${BOOTSTRAP_DIR}/lib/common.sh"
  # shellcheck source=lib/checks.sh
  source "${BOOTSTRAP_DIR}/lib/checks.sh"
  # shellcheck source=config/packages.sh
  source "${BOOTSTRAP_DIR}/config/packages.sh"
  # shellcheck source=config/tiers.sh
  source "${BOOTSTRAP_DIR}/config/tiers.sh"
}

teardown_test_env() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "${TMP_DIR}" ]; then
    rm -rf "${TMP_DIR}"
  fi
}
