# IMPLEMENTATION_PLAN — unpossible

A reusable bootstrap template for AI-assisted development. This plan covers metaprogramming improvements to the template itself.

**Current Phase:** Phase 0 (Local development with docker-compose)

**Critical Context:** ACTIVE_PROJECT=unpossible means all paths are at repo root. loop.sh, new-project.sh, scripts/worklog.sh, PROMPT_*.md, and src/test/*.bats all live at root level.

---

## Completed

- [x] Update loop.sh to read ACTIVE_PROJECT and scope all paths (`loop.sh`)
- [x] Add BATS tests for loop.sh ACTIVE_PROJECT scoping (`src/test/loop.bats`) — 10/10 green
- [x] Create new-project.sh scaffold script (`new-project.sh`)
- [x] Add BATS tests for new-project.sh (`src/test/new-project.bats`) — 15/15 green
- [x] Verify full BATS suite runs green via docker compose (`infra/docker-compose.yml`)
- [x] Document specs/features/ convention (`specs/README.md`)
- [x] Update PROMPT_plan.md to scan specs/features/ (`PROMPT_plan.md`)
- [x] Add BATS test that plan prompt references features directory (`src/test/prompts.bats`) — 1/1 green
- [x] Define WORKLOG.md schema (`specs/features/worklog.md`)
- [x] Update PROMPT_build.md to append WORKLOG entries on task completion (`PROMPT_build.md`)
- [x] Add scripts/worklog.sh for pretty-printing/filtering WORKLOG entries (`scripts/worklog.sh`)
- [x] Add BATS tests for worklog.sh (`src/test/worklog.bats`) — 10/10 green
- [x] Define IDEAS.md schema (`specs/features/idea-parking-lot.md`)
- [x] Create IDEAS.md with initial entries (`IDEAS.md`)
- [x] Fix new-project.sh: substitute [PROJECT_NAME] placeholder in generated files (`new-project.sh`) — 18/18 tests green
- [x] Fix new-project.sh: correct Dockerfile COPY path (`new-project.sh`) — 19/19 tests green
- [x] Remove dead code: parse_entry function in worklog.sh is defined but never called (`scripts/worklog.sh`) — 40/40 tests green
- [x] Add RALPH_COMPLETE detection to loop.sh: exit cleanly when agent outputs the sentinel (`loop.sh`) — 43/43 tests green
- [x] Add `./loop.sh research <id>` mode (`loop.sh`, `PROMPT_research.md`) — 49/49 tests green
- [x] Create PROMPT_research.md (`PROMPT_research.md`) — covered by research mode implementation
- [x] Add `./loop.sh promote <id>` command (`loop.sh`) — 55/55 tests green
- [x] Add BATS tests for research and promote modes (`src/test/ideas.bats`) — 12/12 tests green
- [x] Create PROMPT_review.md (`PROMPT_review.md`)
- [x] Add `./loop.sh review` mode (`loop.sh`)
- [x] Add BATS tests for review mode (`src/test/review.bats`) — 3/3 tests green

**Total completed:** 27 tasks — 58/58 BATS tests passing

---

## Backlog

### Feature: Agent Code Review

All tasks complete.

---

### Feature: Bash Language Practices

- [x] Create practices/lang/bash.md (`practices/lang/bash.md`)
  Content: bash-specific patterns for this project — errexit/pipefail/nounset conventions, array handling, quoting rules, BATS test structure, heredoc usage, portability notes (macOS vs Linux)
  Required tests: none (documentation file)

---

**Total tasks:** 0 remaining (0 features)
**Phase 0 constraints:** All work uses local docker-compose only. No CI/CD, no remote deploys, no k8s.
**Next phase:** Phase 1 (CI) — not planned yet. Advance only after Phase 0 acceptance criteria are met.

---

## Future (not planned — requires Phase 0 completion)

Ideas in IDEAS.md that are out of scope for current phase:
- Project Dashboard (IDEAS.md #1) — parked
- Metrics System (IDEAS.md #2) — parked
- Improvement Mode (IDEAS.md #3) — parked
- External Benchmarking (IDEAS.md #4) — parked
- Failure Analysis & Prompt Learning (IDEAS.md #5) — parked
