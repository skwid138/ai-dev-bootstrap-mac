#!/usr/bin/env bats
# Consistency tests for documentation URLs in README.md.
#
# Why this exists: the README's curl one-liner pointed at a file that
# didn't exist (or didn't work) at that URL for the entire life of the
# multi-file project — bootstrap.sh became a multi-file orchestrator
# but the README still said `curl … bootstrap.sh | bash`, which broke
# silently every time a real user tried it. We didn't catch it because
# nothing in CI exercised the URL.
#
# This test extracts every raw.githubusercontent.com URL the README
# tells users to curl, and verifies:
#   1. The path component points at a file that actually exists in the
#      repo at that path.
#   2. The branch component matches the repo's default branch (so we
#      don't ship a README pointing at a topic branch by accident).
#   3. The file in question is executable (since they're all curl|bash
#      install entrypoints).
#
# This is a STATIC test — it doesn't hit the network. We're verifying
# the README's URLs are internally consistent with the working tree.
# A separate concern is whether the URL is reachable on GitHub (i.e.
# the commit has been pushed to origin); that's not testable from
# inside the test runner, but `git status` showing a clean working
# tree is a reasonable proxy and is how we'd catch it in PR review.

bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export REPO_ROOT
  README="$REPO_ROOT/README.md"
  export README
}

# Extract all raw.githubusercontent.com URLs from README.md.
# Returns one URL per line on stdout.
_extract_raw_urls() {
  grep -oE 'https://raw\.githubusercontent\.com/[^[:space:]")]+' "$README" || true
}

@test "README.md exists and contains at least one curl URL" {
  [ -f "$README" ]
  # We require at least one — if curl install support is removed in
  # the future, delete this whole test file along with that change.
  count=$(_extract_raw_urls | wc -l | tr -d ' ')
  [ "$count" -gt 0 ]
}

@test "README curl URLs: every URL points at a file that exists in the repo" {
  failures=()
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    # URL shape: https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<path>
    # Strip the prefix and split.
    rest="${url#https://raw.githubusercontent.com/}"
    # rest = <owner>/<repo>/<branch>/<path>
    # The first three components are owner, repo, branch.
    owner="${rest%%/*}"; rest="${rest#*/}"
    repo="${rest%%/*}";  rest="${rest#*/}"
    branch="${rest%%/*}"; path="${rest#*/}"
    file="$REPO_ROOT/$path"
    if [ ! -e "$file" ]; then
      failures+=("URL $url points at $path but $file does not exist")
    fi
  done < <(_extract_raw_urls)
  if [ "${#failures[@]}" -gt 0 ]; then
    printf '%s\n' "${failures[@]}"
    return 1
  fi
}

@test "README curl URLs: every URL's branch matches the repo's default branch" {
  # Determine the repo's default branch. Prefer `git remote show origin`
  # (authoritative on a normal checkout); fall back to the current branch
  # if the remote isn't reachable (CI checkouts sometimes lack the
  # remote refs). The fallback is acceptable because CI typically runs
  # on the default branch or a PR head; either way it's the branch
  # users will hit when the change merges.
  default_branch=""
  if git -C "$REPO_ROOT" remote show origin >/dev/null 2>&1; then
    default_branch=$(git -C "$REPO_ROOT" remote show origin 2>/dev/null \
      | awk '/HEAD branch:/ {print $NF}')
  fi
  if [ -z "$default_branch" ]; then
    default_branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
  fi

  failures=()
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    rest="${url#https://raw.githubusercontent.com/}"
    owner="${rest%%/*}"; rest="${rest#*/}"
    repo="${rest%%/*}";  rest="${rest#*/}"
    branch="${rest%%/*}"
    if [ "$branch" != "$default_branch" ]; then
      failures+=("URL $url uses branch '$branch' but repo default is '$default_branch'")
    fi
  done < <(_extract_raw_urls)
  if [ "${#failures[@]}" -gt 0 ]; then
    printf '%s\n' "${failures[@]}"
    return 1
  fi
}

@test "README curl URLs: every targeted file is executable (curl|bash entrypoint)" {
  failures=()
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    rest="${url#https://raw.githubusercontent.com/}"
    owner="${rest%%/*}"; rest="${rest#*/}"
    repo="${rest%%/*}";  rest="${rest#*/}"
    branch="${rest%%/*}"; path="${rest#*/}"
    file="$REPO_ROOT/$path"
    if [ -e "$file" ] && [ ! -x "$file" ]; then
      failures+=("URL $url targets $path which exists but is not executable")
    fi
  done < <(_extract_raw_urls)
  if [ "${#failures[@]}" -gt 0 ]; then
    printf '%s\n' "${failures[@]}"
    return 1
  fi
}

@test "README curl URLs: owner/repo segment matches this repository" {
  # Guard against a README that accidentally points at a fork or a
  # different project. The owner/repo in the URL must match what `git
  # remote get-url origin` reports (or be skipped if origin is unset).
  origin=""
  if git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1; then
    origin=$(git -C "$REPO_ROOT" remote get-url origin)
  fi
  if [ -z "$origin" ]; then
    skip "no origin remote configured; cannot verify owner/repo"
  fi
  # Normalize: GitHub origins can be HTTPS or SSH; both end in <owner>/<repo>(.git)?
  # https://github.com/skwid138/ai-dev-bootstrap-mac.git
  # git@github.com:skwid138/ai-dev-bootstrap-mac.git
  # Strip the .git suffix and extract last two path components.
  norm_origin="${origin%.git}"
  # Replace `:` (SSH form) with `/` so both shapes parse the same.
  norm_origin="${norm_origin//://}"
  # Last two path components.
  expected_repo="${norm_origin##*/}"
  rest="${norm_origin%/*}"
  expected_owner="${rest##*/}"
  expected_owner_repo="$expected_owner/$expected_repo"

  failures=()
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    rest="${url#https://raw.githubusercontent.com/}"
    owner="${rest%%/*}"; rest="${rest#*/}"
    repo="${rest%%/*}"
    actual_owner_repo="$owner/$repo"
    if [ "$actual_owner_repo" != "$expected_owner_repo" ]; then
      failures+=("URL $url targets $actual_owner_repo but repo is $expected_owner_repo")
    fi
  done < <(_extract_raw_urls)
  if [ "${#failures[@]}" -gt 0 ]; then
    printf '%s\n' "${failures[@]}"
    return 1
  fi
}
