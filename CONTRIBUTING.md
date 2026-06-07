# Contributing

Welcome. This project sets up Macs for non-techy users to vibe with OpenCode. Bugs hit those users harder than they'd hit a developer, so we hold the bar high on shell quality.

## Local development

You need:

- macOS 15+ (the bootstrap targets it; CI also runs bats here)
- `bash` 5+ (installed automatically by `./bootstrap.sh` at the Essential tier; or `brew install bash` if you've cloned this repo without running bootstrap. macOS ships bash 3.2.)
- `shellcheck` (`brew install shellcheck`)
- `shfmt` (`brew install shfmt`)
- `bats-core` (`brew install bats-core`)

## Quality gates

Three commands. All run locally and in CI with identical args.

### 1. ShellCheck (static analysis — blocking, `.sh` only)

```sh
shellcheck -e SC1090 -e SC1091 -e SC2034 -e SC2155 -e SC2031 -x \
  bootstrap.sh lib/*.sh modules/*.sh config/*.sh \
  scripts/*.sh scripts/lib/*.sh scripts/agent/*.sh launcher/*.sh
```

ShellCheck dropped zsh support in v0.11.0, so it does **not** lint `dotfiles/*.zsh`. The dialect-aware gate for those files is `zsh -n` (see step 1b). If you have a `.zsh` file where bash-overlap coverage would be useful, you can opt in with `# shellcheck shell=bash` on line 2 (after the purpose comment) — but plan to also exclude `SC2034` since `.zsh` files often define vars consumed by external zsh plugins.

Justified exclusions (single source of truth: `.github/workflows/ci.yml`):

- **SC1090**: dynamic `source` in `bootstrap.sh` is intentional — the modular architecture sources `modules/*.sh` by computed name.
- **SC1091**: don't follow sourced files individually — they're checked on their own.
- **SC2034**: kept defensive — declares an exclusion that historically applied to `dotfiles/zsh_*.sh` and remains a useful escape hatch for any helper file that exports vars consumed by external code.
- **SC2155**: stylistic preference, not a bug class.
- **SC2031**: temporary false-positive exclusion from the opencode.jsonc migration's `lib/common.sh` source guard before `BOOTSTRAP_DIR` assignment.

If you need to add a new exclusion, document the justification in `.github/workflows/ci.yml` and here in the same PR.

### 1b. zsh -n (parse check for `.zsh` files — blocking)

```sh
# Check every .zsh file in dotfiles/ parses cleanly. No static analysis,
# just a dialect-aware syntax gate.
find dotfiles -type f -name '*.zsh' -exec zsh -n {} +
```

`zsh -n` is fast and deterministic. It catches the syntax errors shellcheck cannot. macOS ships zsh; on Linux CI we install via apt.

### 2. shfmt (format — blocking)

```sh
# Check (matches CI):
shfmt -d -i 2 -ci -bn bootstrap.sh lib/ modules/ config/ scripts/ launcher/
shfmt -d -i 2 -ci -bn dotfiles/   # auto-detects .zsh and parses with -ln zsh

# Auto-fix:
shfmt -w -i 2 -ci -bn bootstrap.sh lib/ modules/ config/ scripts/ launcher/
shfmt -w -i 2 -ci -bn dotfiles/
```

Flags: 2-space indent (`-i 2`), case statements indented (`-ci`), binary ops at line start (`-bn`). shfmt 3+ auto-detects zsh dialect from the `.zsh` extension.

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
4. Update the README or contributing docs if the user-facing behavior or project structure changed.

### Touching `dotfiles/`

These are sourced into the user's `~/.zshenv`, `~/.zprofile`, and `~/.zshrc` via the bootstrap (one barrel per tier — see `dotfiles/init_env.zsh`, `init_profile.zsh`, `init_rc.zsh`). Keep them small, idempotent, and safe to source twice. Each barrel is sentinel-guarded against double-source; sentinels MUST use `${_VAR:-}` form to be `set -u`-safe (the helpers are called from test harnesses running `set -euo pipefail`).

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
- Keep PRs focused. Multi-phase work should land as separate PRs per phase where reasonable.
