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
#   hardcoded /Users/hunter or /code/wpromote paths).
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

# ── Agents ───────────────────────────────────────────────────────────────────

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

@test "opencode/skill: all 8 curated skills have SKILL.md" {
  skills=("${OPENCODE_DIR}"/skill/*/SKILL.md)
  [ "${#skills[@]}" -eq 8 ]

  for skill in tdd bug-hunter dependency-update diagnose grill-me grill-with-docs prototype improve-codebase-architecture; do
    [ -f "${OPENCODE_DIR}/skill/${skill}/SKILL.md" ]
  done
}

@test "opencode/skill: bug-hunter has all 4 reference files" {
  for ref in detector-rules.md examples.md fix-patterns.md severity-rubric.md; do
    [ -f "${OPENCODE_DIR}/skill/bug-hunter/references/${ref}" ]
  done
}

# ── Commands ─────────────────────────────────────────────────────────────────

@test "opencode/command: all 9 curated commands exist" {
  commands=("${OPENCODE_DIR}"/command/*.md)
  [ "${#commands[@]}" -eq 9 ]

  for cmd in help-me explain safer commit diagnose grill prototype architecture update-opencode-deps; do
    [ -f "${OPENCODE_DIR}/command/${cmd}.md" ]
  done
}

# ── Instructions ─────────────────────────────────────────────────────────────

@test "opencode/instruction: all 2 curated instructions exist" {
  instructions=("${OPENCODE_DIR}"/instruction/*.md)
  [ "${#instructions[@]}" -eq 2 ]

  [ -f "${OPENCODE_DIR}/instruction/repo-context.md" ]
  [ -f "${OPENCODE_DIR}/instruction/agent-defaults.md" ]
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

@test "opencode.json.template: declares exact DCP plugin version" {
  run jq -r '.plugin | length' "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  run jq -r '.plugin[0]' "${OPENCODE_DIR}/opencode.json.template"
  [ "$output" = "@tarquinen/opencode-dcp@3.1.11" ]
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

@test "opencode/: no Wpromote-internal or hardcoded-path references" {
  # One grep covers every file added now and every file added later.
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
    -e '/Users/hunter' \
    -e '/code/wpromote' \
    "${OPENCODE_DIR}"
  # grep exits 1 on no-match, which is what we want.
  [ "$status" -eq 1 ]
}
