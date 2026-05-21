#!/usr/bin/env bats
# CLI / arg-parsing tests for scripts/agent/permission-audit.sh.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/agent/permission-audit.sh"
  STUBDIR="$(mktemp -d)"
}

teardown() {
  [[ -d "$STUBDIR" ]] && rm -rf "$STUBDIR"
}

write_python_arg_stub() {
  cat >"$STUBDIR/python3" <<'EOF'
#!/usr/bin/env bash
printf 'core=%s\n' "$1"
shift
printf 'args=%s\n' "$*"
EOF
  chmod +x "$STUBDIR/python3"
}

make_path_without_python3() {
  mkdir -p "$STUBDIR/minpath"
  ln -s /bin/bash "$STUBDIR/minpath/bash"
  ln -s /usr/bin/dirname "$STUBDIR/minpath/dirname"
}

@test "permission-audit: --help exits 0 and prints usage" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: permission-audit"* ]]
  [[ "$output" == *"--action ask|deny|all"* ]]
}

@test "permission-audit: missing python3 exits 3" {
  make_path_without_python3
  run env PATH="$STUBDIR/minpath" PERMISSION_AUDIT_TODAY=2026-05-21 "$SCRIPT"
  [ "$status" -eq 3 ]
  [[ "$output" == *"Missing dependency"* ]]
  [[ "$output" == *"python3"* ]]
}

@test "permission-audit: invalid date format exits 2" {
  run "$SCRIPT" --start 2026/05/21
  [ "$status" -eq 2 ]
  [[ "$output" == *"Usage error"* ]]
  [[ "$output" == *"Invalid --start date"* ]]
}

@test "permission-audit: default args pass through to python core" {
  write_python_arg_stub
  run env PATH="$STUBDIR:$PATH" PERMISSION_AUDIT_TODAY=2026-05-21 "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"core=$BATS_TEST_DIRNAME/../scripts/agent/permission_audit_core.py"* ]]
  [[ "$output" == *"args=--start 2026-05-21 --end 2026-05-21 --action ask --json"* ]]
}
