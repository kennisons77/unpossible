# Version Control

## One Update Rule

When a file moves or is renamed, one additional change is required in the same commit:
update its row in the relevant lookup table (`specs/README.md`, `AGENTS.md`, or
`specs/practices/LOOKUP.md`). This keeps lookup tables current without a separate
maintenance pass.

A commit that renames a spec without updating its lookup table row is incomplete.

## One Commit Per Passing Beat

The build loop commits after each beat passes tests. Never bundle multiple beats into
one commit.

Commit message format:
```
{beat title}

- {what changed}
- {why — the spec or acceptance criterion it satisfies}
```

The "why" line is mandatory. A commit that only describes what changed is incomplete.

## Branch Per Loop Run

`loop.sh` creates a `ralph/{timestamp}` branch for each run on main/master:
- Main is always green
- Each loop run is reviewable as a PR before merge
- Rollback is `git revert` on the branch, not on main

## Tags

After every green build that advances the project to a fully passing state, the build
loop creates or increments a semver tag (`0.0.1`, `0.0.2`, ...). Tags are the
deployable units.

## What Goes in Git

- All MD files: specs, research logs, `IDEAS.md`, `IMPLEMENTATION_PLAN.md`, principles
- All application code
- `Gemfile.lock` and `go.sum` — always committed, never gitignored
- `infra/` manifests
- `.env.example`

## What Does Not Go in Git

- `.env` files
- `master.key` / credential keys
- DB dumps
- Log files
- Generated assets (`public/assets/`)

A committed `.env` or `master.key` is a CI failure — detected by `git-secrets` or
`gitleaks` pre-commit hook.
