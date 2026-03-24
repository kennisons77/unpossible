# IMPLEMENTATION_PLAN — unpossible

A reusable bootstrap template for AI-assisted development. This plan covers metaprogramming improvements to the template itself.

**Current Phase:** Phase 0 (Local development with docker-compose)

**Critical Context:** The template uses a `projects/<name>/` directory structure anchored by an `ACTIVE_PROJECT` file at the repo root. The prompt files (PROMPT_plan.md, PROMPT_build.md) already reference this structure, but `loop.sh` does NOT yet implement it. Task #1 is the blocker that unblocks everything else.

---

## Backlog (Highest Priority — Unblocks Everything)

- [x] **Update loop.sh to read ACTIVE_PROJECT and scope all paths to projects/<name>/** (`loop.sh`)
  **Status:** Already implemented. loop.sh reads ACTIVE_PROJECT, validates it, and sets PROJECT_DIR accordingly.
  The prompt files (PROMPT_build.md, PROMPT_plan.md) instruct the agent to read ACTIVE_PROJECT and handle path scoping.

- [x] Add BATS tests for loop.sh ACTIVE_PROJECT scoping behavior (`src/test/loop.bats`)
  **Completed:** All tests pass (10/10 green)
  - loop.sh exits non-zero when ACTIVE_PROJECT is missing ✓
  - loop.sh exits non-zero when ACTIVE_PROJECT is empty ✓
  - loop.sh exits non-zero when projects/<name>/ directory does not exist ✓
  - loop.sh reads ACTIVE_PROJECT and constructs correct paths ✓
  - loop.sh falls back to root-level PROMPT files if project-level ones don't exist ✓
  - Added git and bash to test container Dockerfile ✓

- [x] Create new-project.sh scaffold script (`new-project.sh` at repo root)
  **Completed:** Script creates complete project structure with validation
  - Takes project name as argument: `./new-project.sh <name>` ✓
  - Creates projects/<name>/ directory structure: specs/, src/, infra/, src/test/ ✓
  - Creates placeholder spec files (prd.md, plan.md) with all required sections ✓
  - Creates IMPLEMENTATION_PLAN.md with header ✓
  - Creates minimal Dockerfile and docker-compose.yml with TODOs ✓
  - Validates input (exits non-zero for empty, slashes, spaces, existing projects) ✓

- [x] Add BATS tests for new-project.sh (`src/test/new-project.bats`)
  **Completed:** All tests pass (15/15 green)
  - new-project.sh creates projects/<name>/ with correct subdirectories ✓
  - new-project.sh creates Dockerfile and docker-compose.yml ✓
  - new-project.sh creates placeholder spec files (prd.md, plan.md) ✓
  - new-project.sh creates IMPLEMENTATION_PLAN.md with header ✓
  - new-project.sh exits non-zero if project name already exists ✓
  - new-project.sh exits non-zero if no project name provided ✓
  - new-project.sh exits non-zero if project name contains invalid characters ✓

- [x] Verify full BATS suite runs green via docker compose (`infra/docker-compose.yml`, all test files)
  **Completed:** All 25 tests pass (10 loop.sh + 15 new-project.sh)
  `docker compose -f infra/docker-compose.yml run --rm test` exits 0 with all tests passing ✓

---

## Feature: Spec Organisation by Feature

- [x] Document `projects/<name>/specs/features/<feature-name>.md` convention (`projects/unpossible/specs/README.md`)
  **Completed:** Created specs/README.md documenting directory structure, feature organization, and spec-writing guidelines

- [x] Update `PROMPT_plan.md` to scan `specs/features/` in addition to `specs/` (`PROMPT_plan.md` at repo root)
  **Completed:** Updated step 0c to explicitly reference projects/<name>/specs/features/* for feature-specific specs

- [ ] Add BATS test that plan prompt references the features directory (`projects/unpossible/src/test/prompts.bats`)
  Required tests: `grep -q 'specs/features' /workspace/PROMPT_plan.md` exits 0

---

## Feature: Structured Work Log

- [ ] Define `WORKLOG.md` schema (`projects/unpossible/specs/features/worklog.md`)
  Required tests: none (schema definition only)
  Schema fields: id (auto-increment), title, status (todo/in-progress/done), feature, started_at, completed_at, summary, commit_sha
  Document the format and purpose of WORKLOG.md

- [ ] Update `PROMPT_build.md` to append WORKLOG entries on task completion (`PROMPT_build.md` at repo root)
  Required tests: prompt instructs agent to append to projects/<name>/WORKLOG.md with correct schema after each task
  Change: add instruction to log completed tasks to WORKLOG.md before marking them done in IMPLEMENTATION_PLAN.md

- [ ] Add `scripts/worklog.sh` for pretty-printing/filtering WORKLOG entries (`scripts/worklog.sh` at repo root)
  Required functionality:
  - `worklog.sh list` — show all entries in table format
  - `worklog.sh show <id>` — show full details for one entry
  - `worklog.sh filter --status=<status>` — filter by status
  - `worklog.sh filter --feature=<feature>` — filter by feature
  Required tests: each subcommand produces valid output, exits non-zero on invalid input

- [ ] Add BATS test for `worklog.sh` output format (`projects/unpossible/src/test/worklog.bats`)
  Required tests:
  - worklog.sh list produces valid table output
  - worklog.sh show <id> exits 0 for valid id, exits 1 for invalid id
  - worklog.sh filter --status=done filters correctly
  - worklog.sh filter --feature=<name> filters correctly

---

## Feature: Idea Parking Lot

- [ ] Define `IDEAS.md` schema (`projects/unpossible/specs/features/ideas.md`)
  Required tests: none (schema definition only)
  Schema fields: id (auto-increment), title, status (parked/researching/ready/rejected/promoted), description, open_questions, created_at, promoted_at
  Document the format and purpose of IDEAS.md

- [ ] Add `./loop.sh research <idea-id>` mode (`loop.sh`, `PROMPT_research.md` at repo root)
  Required functionality:
  - loop.sh accepts `research <id>` as first argument
  - Reads projects/<name>/IDEAS.md, finds entry with matching id
  - Loads PROMPT_research.md and feeds it to agent with idea context
  - Agent researches the idea, updates findings, sets status to "ready" or "rejected"
  - Exits non-zero if <id> missing from IDEAS.md or IDEAS.md doesn't exist
  Required tests: research mode loads correct prompt, exits non-zero if id invalid, updates idea status

- [ ] Add `./loop.sh promote <idea-id>` command (`loop.sh`)
  Required functionality:
  - loop.sh accepts `promote <id>` as first argument
  - Reads projects/<name>/IDEAS.md, finds entry with matching id
  - Creates projects/<name>/specs/<idea-title-slugified>.md with idea content
  - Updates IDEAS.md entry status to "promoted" and sets promoted_at timestamp
  - Exits non-zero if <id> missing or already promoted
  Required tests: promote creates spec file, updates IDEAS.md status

- [ ] Add BATS tests for research and promote modes (`projects/unpossible/src/test/ideas.bats`)
  Required tests:
  - loop.sh research <id> loads PROMPT_research.md
  - loop.sh research exits non-zero if id invalid
  - loop.sh research updates idea status in IDEAS.md
  - loop.sh promote <id> creates spec file in correct location
  - loop.sh promote updates IDEAS.md status to "promoted"
  - loop.sh promote exits non-zero if id already promoted

---

## Feature: Agent Code Review

- [ ] Add `PROMPT_review.md` for reviewer agent (`PROMPT_review.md` at repo root)
  Required tests: none (prompt file only)
  Content: instruct agent to review code for: anti-patterns, missing tests, security issues, performance problems, readability
  Agent should read last commit diff, check alignment with specs, write findings to projects/<name>/REVIEW.md

- [ ] Add `./loop.sh review` mode (`loop.sh`)
  Required functionality:
  - loop.sh accepts `review` as first argument
  - Loads PROMPT_review.md and feeds it to agent
  - Agent reviews projects/<name>/src/ and outputs findings to projects/<name>/REVIEW.md
  Required tests: review mode loads correct prompt, runs review agent, creates REVIEW.md

- [ ] Update `loop.sh` to chain build → review when `REVIEW=1` (`loop.sh`)
  Required functionality:
  - When REVIEW=1 environment variable is set, run one build iteration, then one review iteration
  - Review iteration uses PROMPT_review.md
  - Both iterations count toward MAX_ITERATIONS limit
  Required tests: REVIEW=1 ./loop.sh runs build iteration, then review iteration

- [ ] Add BATS test for `PROMPT_review.md` and review mode (`projects/unpossible/src/test/review.bats`)
  Required tests:
  - loop.sh review loads PROMPT_review.md
  - loop.sh review creates REVIEW.md in projects/<name>/
  - REVIEW=1 triggers chained build → review execution (mock test with dry-run mode)

---

**Total tasks:** 18  
**Phase 0 constraints:** All work uses local docker-compose only. No CI/CD, no remote deploys, no k8s.  
**Next phase:** Phase 1 (CI) — not planned yet. Advance only after Phase 0 acceptance criteria are met.
