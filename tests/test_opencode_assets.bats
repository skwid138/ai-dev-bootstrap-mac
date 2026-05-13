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
}

teardown() {
  teardown_test_env
}

# ── Agents ───────────────────────────────────────────────────────────────────

@test "opencode/agent: all 4 curated agents exist" {
  agents=("${OPENCODE_DIR}"/agent/*.md)
  [ "${#agents[@]}" -eq 4 ]

  for agent in radagast aragorn treebeard legolas; do
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
  for agent in treebeard legolas radagast; do
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

# ── Skills ───────────────────────────────────────────────────────────────────

@test "opencode/skill: all 7 curated skills have SKILL.md" {
  skills=("${OPENCODE_DIR}"/skill/*/SKILL.md)
  [ "${#skills[@]}" -eq 7 ]

  for skill in tdd bug-hunter git-flow diagnose grill-me prototype improve-codebase-architecture; do
    [ -f "${OPENCODE_DIR}/skill/${skill}/SKILL.md" ]
  done
}

@test "opencode/skill: bug-hunter has all 4 reference files" {
  for ref in detector-rules.md examples.md fix-patterns.md severity-rubric.md; do
    [ -f "${OPENCODE_DIR}/skill/bug-hunter/references/${ref}" ]
  done
}

# ── Commands ─────────────────────────────────────────────────────────────────

@test "opencode/command: all 8 curated commands exist" {
  commands=("${OPENCODE_DIR}"/command/*.md)
  [ "${#commands[@]}" -eq 8 ]

  for cmd in help-me explain safer commit diagnose grill prototype architecture; do
    [ -f "${OPENCODE_DIR}/command/${cmd}.md" ]
  done
}

# ── Instructions ─────────────────────────────────────────────────────────────

@test "opencode/instruction: all 3 curated instructions exist" {
  instructions=("${OPENCODE_DIR}"/instruction/*.md)
  [ "${#instructions[@]}" -eq 3 ]

  [ -f "${OPENCODE_DIR}/instruction/repo-context.md" ]
  [ -f "${OPENCODE_DIR}/instruction/agent-defaults.md" ]
  [ -f "${OPENCODE_DIR}/instruction/plan-workflow.md" ]
}

# ── Top-level files ──────────────────────────────────────────────────────────

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

@test "opencode.json.template: declares the DCP plugin" {
  run jq -r '.plugin | length' "${OPENCODE_DIR}/opencode.json.template"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  run jq -r '.plugin[0]' "${OPENCODE_DIR}/opencode.json.template"
  [[ "$output" == @tarquinen/opencode-dcp@* ]]
}

# ── Cross-pollination guardrails ─────────────────────────────────────────────

@test "opencode/: personal agent names are absent from active assets" {
  run grep -RiiE \
    -e '(^|[^a-z0-9_-])gandalf([^a-z0-9_-]|$)' \
    -e '(^|[^a-z0-9_-])saruman([^a-z0-9_-]|$)' \
    "${OPENCODE_DIR}/agent" \
    "${OPENCODE_DIR}/skill" \
    "${OPENCODE_DIR}/command" \
    "${OPENCODE_DIR}/instruction"
  [ "$status" -eq 1 ]
}

@test "opencode/: skills and instructions do not reference external glossary docs" {
  run grep -RE \
    -e 'CONTEXT\.md' \
    -e 'docs/adr' \
    -e '(^|[^A-Za-z0-9_-])ADR([^A-Za-z0-9_-]|$)' \
    -e '(^|[^A-Za-z0-9_-])ADRs([^A-Za-z0-9_-]|$)' \
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
