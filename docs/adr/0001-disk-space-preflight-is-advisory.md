# ADR 0001: Disk-space preflight is advisory, not blocking

## Status

Accepted

## Context

Preflight runs before tier selection and before Homebrew install, so the selected tier and actual size requirement are unknown at this point. Any threshold here is a guess.

The previous disk-space check always returned 0 and the caller used `|| true`, so it could never actually block. The code lied about its intent by looking like a failing check while behaving as an advisory warning.

## Decision

Keep disk-space preflight advisory. Rename `check_disk_space` to `warn_disk_space`, drop the misleading caller-side `|| true`, and keep a flat 10GB warning threshold. That threshold is validated against measured Complete-tier usage of about 6.7GB installed and about 8.5GB peak.

Use a plain-language, non-jargon warning message and measure `/` directly.

## Rationale

The Bootstrap cannot know the real requirement during preflight because tier selection happens later. Blocking at this point offers only a small extra priority-#1 "cannot cause harm" gain because safe re-runs are part of the design, partial state can be fixed by running the Bootstrap again, and Homebrew resumes downloads and installs.

A flat hard-block would falsely stop some small-tier users who have enough space for what they chose. That would violate priority #2: never leave them stuck or confused.

There is no hard confirmation gate for very low space. Keeping the check simple and advisory honors the priority-#2 goal, while the safe re-run architecture covers the main harm case.

## Consequences

The disk-space preflight never hard-blocks installation. A future contributor must not "fix" this into a blocker without revisiting this ADR.

Tier-aware thresholds would require moving the check after tier selection, around `bootstrap.sh:566`, and are out of scope for this decision.
