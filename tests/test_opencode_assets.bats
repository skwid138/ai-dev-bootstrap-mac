#!/usr/bin/env bats
#
# Structural smoke tests for the opencode/ asset tree.
#
# These tests are FILESYSTEM-ONLY: they verify the curated assets that
# the v2 bootstrap will deploy are present, parseable, and free of
# Wpromote-internal references. They do NOT exercise the installer
# (modules/09-opencode.sh) — that is Phase B2's responsibility.
#
# Why these invariants:
# - Catches accidental deletion / typo of any asset declared in the
#   opencode.json.template instruction list.
# - Catches re-introduction of forbidden tokens during future edits
#   (Jira / Sonar / Stryker / Wpromote / acli / atlassian / BIXB-NNNN /
#   hardcoded personal home paths or /code/wpromote paths).
# - Catches malformed JSON in the template before B2 ever consumes it.
# - Catches missing YAML frontmatter on agent files (opencode requires it).
#
# Forbidden-token grep is a single sweep across the whole opencode/
# subtree, so any new asset added later is automatically covered.

setup() {
  source "${BATS_TEST_DIRNAME}/test_helper.sh"
  setup_test_env
  OPENCODE_DIR="${BOOTSTRAP_DIR}/opencode"
  export OPENCODE_DIR
  # shellcheck source=../lib/opencode.sh
  source "${BOOTSTRAP_DIR}/lib/opencode.sh"
}

teardown() {
  teardown_test_env
}

line_number_for_literal() {
  local file="$1"
  local literal="$2"
  awk -v literal="$literal" 'index($0, literal) { line = NR } END { if (line) print line }' "$file"
}

frontmatter_bash_block() {
  local file="$1"
  awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && $0 == "  bash:" { in_bash = 1; print; next }
    in_bash {
      if ($0 ~ /^  [^ ].*:/) { exit }
      print
    }
  ' "$file"
}

frontmatter_block() {
  local file="$1"
  awk '
    NR == 1 {
      if ($0 != "---") { exit 1 }
      in_frontmatter = 1
      next
    }
    in_frontmatter && $0 == "---" {
      closed = 1
      printf "%s", block
      exit 0
    }
    in_frontmatter {
      block = block $0 ORS
    }
    END {
      if (!closed) { exit 1 }
    }
  ' "$file"
}

frontmatter_has_nonempty_description() {
  local file="$1"
  local block

  if ! block="$(frontmatter_block "$file")"; then
    printf '%s: front matter must start with --- and include a closing ---\n' "$file" >&2
    return 1
  fi

  printf '%s\n' "$block" | awk -v file="$file" '
    function fail(message) {
      failed = 1
      print file ": " message > "/dev/stderr"
      exit 1
    }
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function is_description_block_scalar(value) {
      return value ~ /^[>|][-+]?$|^[>|]$/
    }

    /^[[:space:]]*$/ { next }

    waiting_for_description_content && /^[^[:space:]][^:]*:/ {
      fail("description block scalar has no indented content")
    }

    /^description:[[:space:]]*/ {
      found_description = 1
      value = $0
      sub(/^description:[[:space:]]*/, "", value)
      value = trim(value)

      if (is_description_block_scalar(value)) {
        waiting_for_description_content = 1
        next
      }

      if (value == "") {
        fail("description is empty")
      }

      description_ok = 1
      next
    }

    waiting_for_description_content {
      if ($0 ~ /^[[:space:]]+[^[:space:]]/) {
        description_ok = 1
        waiting_for_description_content = 0
        next
      }

      fail("description block scalar has no indented content")
    }

    END {
      if (failed) { exit 1 }
      if (!found_description) {
        print file ": description is missing" > "/dev/stderr"
        exit 1
      }
      if (waiting_for_description_content) {
        print file ": description block scalar has no indented content" > "/dev/stderr"
        exit 1
      }
      if (!description_ok) { exit 1 }
    }
  '
}

frontmatter_yaml_has_nonempty_string_description() {
  local file="$1"
  local block

  if [ ! -x /usr/bin/ruby ]; then
    printf '%s: /usr/bin/ruby is required for YAML front matter validation\n' "$file" >&2
    return 1
  fi

  if ! block="$(frontmatter_block "$file")"; then
    printf '%s: front matter must start with --- and include a closing ---\n' "$file" >&2
    return 1
  fi

  printf '%s\n' "$block" | /usr/bin/ruby -ryaml -e '
    file = ARGV.fetch(0)

    begin
      parsed = YAML.safe_load(STDIN.read)
    rescue Psych::Exception => e
      warn "#{file}: front matter YAML parse failed: #{e.message}"
      exit 1
    end

    unless parsed.is_a?(Hash)
      warn "#{file}: front matter must parse to a YAML mapping"
      exit 1
    end

    description = parsed["description"]
    unless description.is_a?(String) && !description.strip.empty?
      warn "#{file}: front matter description must be a non-empty string"
      exit 1
    end
  ' "$file"
}

validate_curated_frontmatter() {
  local file="$1"

  frontmatter_has_nonempty_description "$file" && \
    frontmatter_yaml_has_nonempty_string_description "$file"
}

assert_literal_exists_after() {
  local file="$1"
  local literal="$2"
  local anchor="$3"
  local literal_line
  local anchor_line

  literal_line="$(line_number_for_literal "$file" "$literal")"
  anchor_line="$(line_number_for_literal "$file" "$anchor")"

  [ -n "$anchor_line" ]
  [ -n "$literal_line" ]
  [ "$literal_line" -gt "$anchor_line" ]
}

handoff_select_candidate_recipe() {
  local plans_dir="$1"
  local date_slug="$2"
  local subject_slug="$3"

  bash -c '
    plans_dir="$1"
    date_slug="$2"
    subject_slug="$3"

    base="${plans_dir}/${date_slug}_${subject_slug}"
    candidate="${base}.handoff.md"
    counter=2

    while [ -e "$candidate" ]; do
      candidate="${base}_${counter}.handoff.md"
      counter=$((counter + 1))
    done

    printf '\''%s\n'\'' "$candidate"
  ' bash "$plans_dir" "$date_slug" "$subject_slug"
}

handoff_list_notes_recipe() {
  local plans_dir="$1"

  bash -c '
    plans_dir="$1"

    notes=()

    for note in "$plans_dir"/*.handoff.md; do
      [ -f "$note" ] || continue
      notes+=("$note")
    done

    [ "${#notes[@]}" -eq 0 ] || ls -1t "${notes[@]}"
  ' bash "$plans_dir"
}

# ── Agents ───────────────────────────────────────────────────────────────────

@test "opencode/frontmatter: validator rejects malformed curated asset fixtures" {
  no_frontmatter="${BATS_TEST_TMPDIR}/no-frontmatter.md"
  opened_unclosed="${BATS_TEST_TMPDIR}/opened-unclosed.md"
  missing_description="${BATS_TEST_TMPDIR}/missing-description.md"
  empty_block_description="${BATS_TEST_TMPDIR}/empty-block-description.md"
  array_description="${BATS_TEST_TMPDIR}/array-description.md"
  boolean_description="${BATS_TEST_TMPDIR}/boolean-description.md"
  crlf_frontmatter="${BATS_TEST_TMPDIR}/crlf-frontmatter.md"

  cat >"$no_frontmatter" <<'EOF'
# Foo
EOF

  cat >"$opened_unclosed" <<'EOF'
---
description: >-
  This front matter never closes.
# Body
EOF

  cat >"$missing_description" <<'EOF'
---
permission:
  edit: deny
---
# Body
EOF

  cat >"$empty_block_description" <<'EOF'
---
description: >-

permission:
  edit: deny
---
# Body
EOF

  cat >"$array_description" <<'EOF'
---
description: []
---
# Body
EOF

  cat >"$boolean_description" <<'EOF'
---
description: true
---
# Body
EOF

  printf '%s\r\n%s\r\n%s\r\n%s\r\n' '---' 'description: Valid-looking text with CRLF delimiters.' '---' '# Body' >"$crlf_frontmatter"

  run frontmatter_block "$no_frontmatter"
  [ "$status" -ne 0 ]
  [ "$output" = "" ]

  run frontmatter_block "$opened_unclosed"
  [ "$status" -ne 0 ]
  [ "$output" = "" ]

  for fixture in \
    "$no_frontmatter" \
    "$opened_unclosed" \
    "$missing_description" \
    "$empty_block_description" \
    "$array_description" \
    "$boolean_description" \
    "$crlf_frontmatter"; do
    run validate_curated_frontmatter "$fixture"
    [ "$status" -ne 0 ]
  done
}

@test "opencode/agent: all 5 curated agents exist" {
  agents=("${OPENCODE_DIR}"/agent/*.md)
  [ "${#agents[@]}" -eq 5 ]

  for agent in gandalf saruman radagast aragorn legolas; do
    [ -f "${OPENCODE_DIR}/agent/${agent}.md" ]
  done
}

@test "opencode/agent: every agent has YAML frontmatter" {
  # opencode requires agents to begin with a --- frontmatter block.
  for f in "${OPENCODE_DIR}"/agent/*.md; do
    run head -n 1 "$f"
    [ "$status" -eq 0 ]
    [ "$output" = "---" ]
  done
}

@test "opencode/agent: every agent declares a non-empty description" {
  agents=("${OPENCODE_DIR}"/agent/*.md)
  [ "${#agents[@]}" -ge 1 ]

  for f in "${agents[@]}"; do
    run frontmatter_has_nonempty_description "$f"
    [ "$status" -eq 0 ]
  done
}

@test "opencode/agent: every agent front matter parses with a string description" {
  agents=("${OPENCODE_DIR}"/agent/*.md)
  [ "${#agents[@]}" -ge 1 ]

  for f in "${agents[@]}"; do
    run frontmatter_yaml_has_nonempty_string_description "$f"
    [ "$status" -eq 0 ]
  done
}

@test "opencode/agent: no model field set (defer to global default)" {
  # Per plan §0.4, lifted agents must not pin a model — the global
  # opencode.json default is the single source of truth.
  for f in "${OPENCODE_DIR}"/agent/*.md; do
    run grep -E '^model:' "$f"
    [ "$status" -ne 0 ]
  done
}

@test "opencode/agent: leaf agents deny recursive task delegation" {
  for agent in saruman legolas radagast; do
    run grep -Eq '^  task: deny$' "${OPENCODE_DIR}/agent/${agent}.md"
    [ "$status" -eq 0 ]
  done
}

@test "opencode/agent: exploration agents are read-only" {
  for agent in legolas radagast; do
    run grep -Eq '^  write: deny$' "${OPENCODE_DIR}/agent/${agent}.md"
    [ "$status" -eq 0 ]
    run grep -Eq '^  edit: deny$' "${OPENCODE_DIR}/agent/${agent}.md"
    [ "$status" -eq 0 ]
  done
}

@test "opencode/agent: gandalf cannot edit and aragorn can edit" {
  run grep -Eq '^  edit: deny$' "${OPENCODE_DIR}/agent/gandalf.md"
  [ "$status" -eq 0 ]

  run grep -Eq '^  question: allow$' "${OPENCODE_DIR}/agent/gandalf.md"
  [ "$status" -eq 0 ]

  run grep -Eq '^  edit: allow$' "${OPENCODE_DIR}/agent/aragorn.md"
  [ "$status" -eq 0 ]
}

@test "opencode/agent: read-only agents have no bash catch-all ask override" {
  for agent in legolas radagast saruman gandalf; do
    run frontmatter_bash_block "${OPENCODE_DIR}/agent/${agent}.md"
    [ "$status" -eq 0 ]
    [[ "$output" != *'"*": ask'* ]]
  done
}

@test "opencode/agent: gandalf has no bash permission overrides" {
  run frontmatter_bash_block "${OPENCODE_DIR}/agent/gandalf.md"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "opencode/agent: aragorn dangerous command denies override catch-all allow" {
  local aragorn_file="${OPENCODE_DIR}/agent/aragorn.md"
  local catch_all='"*": allow'

  for literal in \
    '"git reset --hard*": deny' \
    '"git clean*": deny' \
    '"git push --force*": deny' \
    '"git push * --force*": deny' \
    '"git push -f*": deny' \
    '"git push * -f*": deny' \
    '"rm -rf *": deny' \
    '"sudo *": deny'; do
    assert_literal_exists_after "$aragorn_file" "$literal" "$catch_all"
  done
}

# ── Skills ───────────────────────────────────────────────────────────────────

@test "opencode/skill: all curated skills have SKILL.md" {
  skills=("${OPENCODE_DIR}"/skill/*/SKILL.md)
  [ "${#skills[@]}" -eq 13 ]

  deepening_skill="improve-codebase-arch""itecture"
  for skill in tdd bug-hunter check-my-site dependency-update permission-audit diagnose grill-with-docs handoff prototype check-updates set-models zoom-out "$deepening_skill"; do
    [ -f "${OPENCODE_DIR}/skill/${skill}/SKILL.md" ]
  done
}

@test "opencode/skill: every skill begins with YAML frontmatter" {
  skills=("${OPENCODE_DIR}"/skill/*/SKILL.md)
  [ "${#skills[@]}" -ge 13 ]

  for f in "${skills[@]}"; do
    run awk 'NR == 1 { first_line_is_open = ($0 == "---"); exit } END { exit first_line_is_open ? 0 : 1 }' "$f"
    [ "$status" -eq 0 ]
  done
}

@test "opencode/skill: every skill front matter is closed" {
  skills=("${OPENCODE_DIR}"/skill/*/SKILL.md)
  [ "${#skills[@]}" -ge 13 ]

  for f in "${skills[@]}"; do
    run frontmatter_block "$f"
    [ "$status" -eq 0 ]
  done
}

@test "opencode/skill: every skill declares a non-empty description" {
  skills=("${OPENCODE_DIR}"/skill/*/SKILL.md)
  [ "${#skills[@]}" -ge 13 ]

  for f in "${skills[@]}"; do
    run frontmatter_has_nonempty_description "$f"
    [ "$status" -eq 0 ]
  done
}

@test "opencode/skill: every skill front matter parses with a string description" {
  skills=("${OPENCODE_DIR}"/skill/*/SKILL.md)
  [ "${#skills[@]}" -ge 13 ]

  for f in "${skills[@]}"; do
    run frontmatter_yaml_has_nonempty_string_description "$f"
    [ "$status" -eq 0 ]
  done
}

@test "opencode/skill: bug-hunter has all 4 reference files" {
  for ref in detector-rules.md examples.md fix-patterns.md severity-rubric.md; do
    [ -f "${OPENCODE_DIR}/skill/bug-hunter/references/${ref}" ]
  done
}

# ── Commands ─────────────────────────────────────────────────────────────────

@test "opencode/command: all curated commands exist" {
  commands=("${OPENCODE_DIR}"/command/*.md)
  [ "${#commands[@]}" -eq 14 ]

  for cmd in help-me explain safer commit diagnose grill prototype update-opencode-deps permission-audit check-updates map-my-app save-progress resume check-my-site; do
    [ -f "${OPENCODE_DIR}/command/${cmd}.md" ]
  done
}

@test "opencode/command: command front matter closes when present" {
  commands=("${OPENCODE_DIR}"/command/*.md)
  [ "${#commands[@]}" -ge 1 ]

  for f in "${commands[@]}"; do
    IFS= read -r first_line <"$f"
    if [ "$first_line" = "---" ]; then
      run frontmatter_block "$f"
      [ "$status" -eq 0 ]
    fi
  done
}

@test "opencode/skill: handoff redaction helper is executable" {
  [ -x "${OPENCODE_DIR}/skill/handoff/redact-secrets.sh" ]
}

@test "scripts/agent: chrome helper is executable" {
  [ -x "${BOOTSTRAP_DIR}/scripts/agent/chrome_mcp.sh" ]
}

@test "scripts/agent: chrome helper checks ownership by port and profile" {
  helper="${BOOTSTRAP_DIR}/scripts/agent/chrome_mcp.sh"
  run grep -q -- '--remote-debugging-port=${PORT}' "$helper"
  [ "$status" -eq 0 ]
  run grep -q -- '--user-data-dir=${USER_DATA_DIR}' "$helper"
  [ "$status" -eq 0 ]
  run grep -q 'pkill.*remote-debugging-port' "$helper"
  [ "$status" -ne 0 ]
}

@test "handoff redact-secrets: strips common secrets and emits markers" {
  secret_file="$TMP_DIR/secrets.txt"
  cat >"$secret_file" <<'EOF'
aws=AKIAIOSFODNN7EXAMPLE
Authorization: Bearer abcdefghijklmnopqrstuvwxyz123456
api_key="sk_test_abcdefghijklmnopqrstuvwxyz"
url=https://person:password@example.test/path
-----BEGIN PRIVATE KEY-----
abc123
-----END PRIVATE KEY-----
EOF

  run "${OPENCODE_DIR}/skill/handoff/redact-secrets.sh" redact "$secret_file"
  [ "$status" -eq 0 ]
  [[ "$output" != *"AKIAIOSFODNN7EXAMPLE"* ]]
  [[ "$output" != *"abcdefghijklmnopqrstuvwxyz123456"* ]]
  [[ "$output" != *"sk_test_abcdefghijklmnopqrstuvwxyz"* ]]
  [[ "$output" != *"person:password"* ]]
  [[ "$output" != *"BEGIN PRIVATE KEY"* ]]
  [[ "$output" == *"[REDACTED_AWS_ACCESS_KEY]"* ]]
  [[ "$output" == *"[REDACTED_BEARER_TOKEN]"* ]]
  [[ "$output" == *"[REDACTED_SECRET]"* ]]
  [[ "$output" == *"[REDACTED_URL_CREDENTIALS]"* ]]
  [[ "$output" == *"[REDACTED_PRIVATE_KEY]"* ]]
}

@test "handoff redact-secrets: preserves unlabeled long non-secret strings" {
  safe_hex="0123456789abcdef0123456789abcdef01234567"
  safe_b64="VGhpcy1pcy1qdXN0LWEtbG9uZy1ub24tc2VjcmV0LWlkZW50aWZpZXI="
  safe_id="build-artifact-20260606-abcdef1234567890"

  run bash -c "printf '%s\n%s\n%s\n' '$safe_hex' '$safe_b64' '$safe_id' | '${OPENCODE_DIR}/skill/handoff/redact-secrets.sh' redact -"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$safe_hex"* ]]
  [[ "$output" == *"$safe_b64"* ]]
  [[ "$output" == *"$safe_id"* ]]
  [[ "$output" != *"[REDACTED_"* ]]
}

@test "handoff skill: save and resume contracts are present" {
  handoff_skill="${OPENCODE_DIR}/skill/handoff/SKILL.md"
  run grep -q "## Suggested skills" "$handoff_skill"
  [ "$status" -eq 0 ]
  run grep -q "redact-secrets.sh" "$handoff_skill"
  [ "$status" -eq 0 ]
}

@test "handoff skill: collision recipe uses numeric counters without overwriting" {
  plans_dir="$TMP_DIR/.project-plans"
  mkdir -p "$plans_dir"
  first_note="$plans_dir/2026-06-06_foo.handoff.md"
  second_note="$plans_dir/2026-06-06_foo_2.handoff.md"
  third_note="$plans_dir/2026-06-06_foo_3.handoff.md"

  printf 'original note\n' >"$first_note"

  run handoff_select_candidate_recipe "$plans_dir" "2026-06-06" "foo"
  [ "$status" -eq 0 ]
  [ "$output" = "$second_note" ]

  printf 'new second note\n' >"$output"
  [ "$(<"$first_note")" = "original note" ]

  run handoff_select_candidate_recipe "$plans_dir" "2026-06-06" "foo"
  [ "$status" -eq 0 ]
  [ "$output" = "$third_note" ]

  printf 'new third note\n' >"$output"
  [ "$(<"$first_note")" = "original note" ]
  [ "$(<"$second_note")" = "new second note" ]
}

@test "handoff skill: listing recipe is newest-first and non-recursive" {
  plans_dir="$TMP_DIR/.project-plans"
  mkdir -p "$plans_dir/archive"
  oldest="$plans_dir/2026-06-06_oldest.handoff.md"
  middle="$plans_dir/2026-06-06_middle.handoff.md"
  newest="$plans_dir/2026-06-06_newest.handoff.md"
  archived="$plans_dir/archive/2026-06-06_archived.handoff.md"

  printf 'oldest\n' >"$oldest"
  printf 'middle\n' >"$middle"
  printf 'newest\n' >"$newest"
  printf 'archived\n' >"$archived"
  touch -t 202606061200.00 "$oldest"
  touch -t 202606061300.00 "$middle"
  touch -t 202606061400.00 "$newest"
  touch -t 202606061500.00 "$archived"

  run handoff_list_notes_recipe "$plans_dir"
  [ "$status" -eq 0 ]
  expected="$newest"$'\n'"$middle"$'\n'"$oldest"
  [ "$output" = "$expected" ]
  [[ "$output" != *"$archived"* ]]
}

# ── Instructions ─────────────────────────────────────────────────────────────

@test "opencode/instruction: all 3 curated instructions exist" {
  instructions=("${OPENCODE_DIR}"/instruction/*.md)
  [ "${#instructions[@]}" -eq 3 ]

  [ -f "${OPENCODE_DIR}/instruction/repo-context.md" ]
  [ -f "${OPENCODE_DIR}/instruction/agent-defaults.md" ]
  [ -f "${OPENCODE_DIR}/instruction/update-awareness.md" ]
}

# ── Top-level files ──────────────────────────────────────────────────────────

@test "opencode_deploy_assets: first run writes manifest without stale cleanup" {
  src="$TMP_DIR/src-opencode"
  dest="$TMP_DIR/dest-opencode"
  mkdir -p "$src/agent" "$dest/agent"
  echo "new" >"$src/agent/gandalf.md"
  echo "user or preexisting" >"$dest/agent/stale.md"

  run opencode_deploy_assets "$src" "$dest"
  [ "$status" -eq 0 ]

  [ -f "$dest/agent/gandalf.md" ]
  [ -f "$dest/agent/stale.md" ]
  [ -f "$dest/.managed-files" ]
  run grep -Fx "agent/gandalf.md" "$dest/.managed-files"
  [ "$status" -eq 0 ]
  run grep -Fx "agent/stale.md" "$dest/.managed-files"
  [ "$status" -eq 1 ]
}

@test "opencode_deploy_assets: removes files dropped from previous manifest" {
  src="$TMP_DIR/src-opencode"
  dest="$TMP_DIR/dest-opencode"
  mkdir -p "$src/agent" "$dest/agent"
  echo "new" >"$src/agent/gandalf.md"
  echo "old managed" >"$dest/agent/old-managed.md"
  echo "user custom" >"$dest/agent/custom.md"
  cat >"$dest/.managed-files" <<'EOF'
agent/gandalf.md
agent/old-managed.md
EOF

  run opencode_deploy_assets "$src" "$dest"
  [ "$status" -eq 0 ]

  [ -f "$dest/agent/gandalf.md" ]
  [ ! -e "$dest/agent/old-managed.md" ]
  [ -f "$dest/agent/custom.md" ]
  run grep -Fx "agent/old-managed.md" "$dest/.managed-files"
  [ "$status" -eq 1 ]
}

@test "opencode_deploy_assets: copies package manifests when present" {
  src="$TMP_DIR/src-opencode"
  dest="$TMP_DIR/dest-opencode"
  mkdir -p "$src/agent"
  echo "agent" >"$src/agent/gandalf.md"
  echo '{"scripts":{"test":"vitest"}}' >"$src/package.json"
  echo '{"lockfileVersion":3}' >"$src/package-lock.json"

  run opencode_deploy_assets "$src" "$dest"
  [ "$status" -eq 0 ]

  [ -f "$dest/package.json" ]
  [ -f "$dest/package-lock.json" ]
  run grep -Fx "package.json" "$dest/.managed-files"
  [ "$status" -eq 0 ]
  run grep -Fx "package-lock.json" "$dest/.managed-files"
  [ "$status" -eq 0 ]
}

@test "opencode/AGENTS.md exists" {
  [ -f "${OPENCODE_DIR}/AGENTS.md" ]
}

@test "opencode/dcp.jsonc.template exists" {
  [ -f "${OPENCODE_DIR}/dcp.jsonc.template" ]
}

@test "opencode/dcp.jsonc.template: valid JSONC (parses after stripping // comments)" {
  # JSONC = JSON + // line comments. Strip them and validate with jq.
  run bash -c "sed 's|//.*||' '${OPENCODE_DIR}/dcp.jsonc.template' | jq ."
  [ "$status" -eq 0 ]
}

@test "opencode/dcp.jsonc.template: sets compress.maxContextLimit to 65%" {
  run bash -c "sed 's|//.*||' '${OPENCODE_DIR}/dcp.jsonc.template' | jq -r '.compress.maxContextLimit'"
  [ "$status" -eq 0 ]
  [ "$output" = "65%" ]
}

# ── opencode.json.template ───────────────────────────────────────────────────

@test "opencode.json.template is valid JSON" {
  run jq . "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
}

@test "opencode.json.template: global dangerous command deny rules override broad asks" {
  local template_file="${OPENCODE_DIR}/opencode.json.template"
  local catch_all='"*": "ask"'
  local git_push_ask='"git push*": "ask"'

  for rule in \
    'git reset --hard*' \
    'git clean*' \
    'rm *' \
    'chmod *' \
    'chown *' \
    'sudo *' \
    'git push --force*' \
    'git push * --force*' \
    'git push -f*' \
    'git push * -f*'; do
    run jq -r --arg rule "$rule" '.permission.bash[$rule]' "$template_file"
    [ "$status" -eq 0 ]
    [ "$output" = "deny" ]

    assert_literal_exists_after "$template_file" "\"${rule}\": \"deny\"" "$catch_all"
  done

  for literal in \
    '"git push --force*": "deny"' \
    '"git push * --force*": "deny"' \
    '"git push -f*": "deny"' \
    '"git push * -f*": "deny"'; do
    assert_literal_exists_after "$template_file" "$literal" "$git_push_ask"
  done
}

@test "opencode.json.template: default agent is gandalf" {
  run grep -Eq '^  "default_agent": "gandalf",?$' "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
}

@test "opencode.json.template: built-in plan, build, and general agents are hidden" {
  for agent in plan build general; do
    run bash -c "grep -A4 '\"${agent}\": {' '${OPENCODE_DIR}/opencode.json.template' | grep -Eq '\"hidden\": true'"
    [ "$status" -eq 0 ]
  done
}

@test "opencode.json.template: every referenced instruction file exists" {
  # Defends against typos in the instructions array vs. on-disk filenames.
  while IFS= read -r rel; do
    [ -f "${OPENCODE_DIR}/${rel}" ]
  done < <(jq -r '.instructions[]' "${OPENCODE_DIR}/opencode.json.template")
}

@test "opencode.json.template: declares 3 MCPs (chrome-devtools, context7, exa)" {
  run jq -r '.mcp | keys | sort | join(",")' "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
  [ "$output" = "chrome-devtools,context7,exa" ]
}

@test "opencode.json.template: declares exact plugin versions" {
  run jq -r '.plugin | length' "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
  run jq -r '.plugin[0]' "${OPENCODE_DIR}/opencode.json.template"
  [ "$output" = "@tarquinen/opencode-dcp@3.1.12" ]
  run jq -r '.plugin[1][0]' "${OPENCODE_DIR}/opencode.json.template"
  [ "$output" = "@skwid138/opencode-council@0.10.0" ]
  run jq -r '.plugin[2][0]' "${OPENCODE_DIR}/opencode.json.template"
  [ "$output" = "@skwid138/opencode-tui@1.1.1/tui" ]
}

@test "opencode.json.template: council plugin delegates aggregation internally" {
  run jq -r '.plugin[1][1].council.reviewer' "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
  [ "$output" = "saruman" ]

  run jq -r '.plugin[1][1].council | has("aggregator")' "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "opencode.json.template: global questions are denied by default" {
  run jq -e '.permission.question == "deny"' "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
}

# ── Cross-pollination guardrails ─────────────────────────────────────────────

@test "opencode/: gandalf and saruman are active curated agents" {
  [ -f "${OPENCODE_DIR}/agent/gandalf.md" ]
  [ -f "${OPENCODE_DIR}/agent/saruman.md" ]

  run grep -RiiE '(^|[^a-z0-9_-])gandalf([^a-z0-9_-]|$)' "${OPENCODE_DIR}/agent"
  [ "$status" -eq 0 ]

  run grep -RiiE '(^|[^a-z0-9_-])saruman([^a-z0-9_-]|$)' "${OPENCODE_DIR}/agent"
  [ "$status" -eq 0 ]
}

@test "opencode/: skills and instructions do not reference external ADR docs" {
  run grep -RE \
    -e 'docs/adr' \
    "${OPENCODE_DIR}/skill" \
    "${OPENCODE_DIR}/instruction"
  [ "$status" -eq 1 ]
}

# ── Forbidden tokens (single sweep across whole tree) ────────────────────────

@test "opencode/ and scripts/agent: no internal or hardcoded-path references" {
  # One grep covers every OpenCode asset, plus helper scripts that ship beside
  # those assets.
  # Pattern intentionally case-insensitive for the org/tool names.
  # Excludes:
  # - 'wpromote' is matched only as a whole token (avoids accidental hits
  #   in legitimate words; there are none expected anyway).
  # - 'BIXB-' is the Jira project prefix as it appears in tickets.
  run grep -riE \
    -e '(^|[^a-z])wpromote([^a-z]|$)' \
    -e '(^|[^a-z])jira([^a-z]|$)' \
    -e '(^|[^a-z])sonar([^a-z]|$)' \
    -e '(^|[^a-z])stryker([^a-z]|$)' \
    -e '(^|[^a-z])acli([^a-z]|$)' \
    -e '(^|[^a-z])atlassian([^a-z]|$)' \
    -e 'BIXB-[0-9]+' \
    -e '/Users/'"hunter" \
    -e '/code/wpromote' \
    "${OPENCODE_DIR}" \
    "${BOOTSTRAP_DIR}/scripts/agent"
  # grep exits 1 on no-match, which is what we want.
  [ "$status" -eq 1 ]
}
