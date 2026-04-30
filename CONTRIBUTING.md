# Contributing

Welcome. This project sets up Macs for non-techy users to vibe-code with OpenCode. Bugs hit those users harder than they'd hit a developer, so we hold the bar high on shell quality.

## Local development

You need:

- macOS 15+ (the bootstrap targets it; CI also runs bats here)
- `bash` 5+ (`brew install bash` if needed — macOS ships 3.2)
- `shellcheck` (`brew install shellcheck`)
- `shfmt` (`brew install shfmt`)
- `bats-core` (`brew install bats-core`)

## Quality gates

Three commands. All run locally and in CI with identical args.

### 1. ShellCheck (static analysis — blocking)

```sh
shellcheck -e SC1090 -e SC1091 -e SC2034 -e SC2155 -x \
  bootstrap.sh lib/*.sh modules/*.sh config/*.sh dotfiles/*.sh
```

Justified exclusions (single source of truth: `.github/workflows/ci.yml`):

- **SC1090**: dynamic `source` in `bootstrap.sh` is intentional — the modular architecture sources `modules/*.sh` by computed name.
- **SC1091**: don't follow sourced files individually — they're checked on their own.
- **SC2034**: `dotfiles/zsh_*.sh` define variables consumed by external zsh plugins (spaceship, history) — they're "unused" from the file's perspective.
- **SC2155**: stylistic preference, not a bug class.

If you need to add a new exclusion, document the justification in `.github/workflows/ci.yml` and here in the same PR.

### 2. shfmt (format — blocking)

```sh
# Check (matches CI):
shfmt -d -i 2 -ci -bn bootstrap.sh lib/ modules/ config/ dotfiles/

# Auto-fix:
shfmt -w -i 2 -ci -bn bootstrap.sh lib/ modules/ config/ dotfiles/
```

Flags: 2-space indent (`-i 2`), case statements indented (`-ci`), binary ops at line start (`-bn`).

### 3. Bats (tests — blocking)

```sh
bats tests/
```

## Adding new code

### New helper in `lib/`

1. Add the function to the appropriate file in `lib/`.
2. Add a corresponding test case to the matching `tests/test_<name>.bats` file.
3. Run `shellcheck`, `shfmt -d`, `bats tests/` locally.

### New module in `modules/`

1. Create `modules/NN-name.sh`. Modules are *sourced* by `bootstrap.sh`, not executed — they rely on `SELECTED_PACKAGES` and helpers from `lib/common.sh`.
2. At minimum, add a parse-check or smoke test (`bats` + `bash -n`) to `tests/`.
3. Wire it into `bootstrap.sh`'s module loop and update `config/packages.sh` if it adds a package.
4. Update `PLAN.md`'s architecture section.

### Touching `dotfiles/`

These are sourced into the user's `~/.zshrc` via the bootstrap. Keep them small, idempotent, and `set -u` clean. They should be safe to source twice.

## Conventional Commits

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/). Common types in this repo:

- `feat:` — new user-facing behavior
- `fix:` — bug fix
- `chore:` — non-functional housekeeping (gitignore, editorconfig, deps)
- `ci:` — CI/CD changes
- `docs:` — README, plan, contributing
- `refactor:` — internal restructure, no behavior change
- `test:` — tests only
- `style:` — formatting only (e.g. shfmt pass)

Keep commits **atomic** — one logical change per commit. The same discipline we ship to bootstrap users via the global `AGENTS.md` applies to us.

## Pull requests

- Branch off `main`.
- Run all three quality gates locally before opening a PR.
- CI must be green to merge.
- Keep PRs focused. Multi-phase work (per `PLAN.md` / `ANALYSIS_AND_PLAN.md`) lands as separate PRs per phase where reasonable.
