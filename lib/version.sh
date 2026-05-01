#!/bin/bash
# Single source of truth for the bootstrap version string.
#
# Read by lib/state.sh when emitting state.sh, and (in the future) by
# bootstrap.sh --version / a summary screen. Bumping this on a release is
# the only place a version needs to change.
#
# Versioning: pre-1.0.0 SemVer. v2.x.y is the post-curated-config rewrite
# (Phases A-Z); v1.x.y was the original tier-only bootstrap. The "-dev"
# suffix marks unreleased work; drop it on a release commit.

AI_BOOTSTRAP_VERSION="2.0.0-dev"
export AI_BOOTSTRAP_VERSION
