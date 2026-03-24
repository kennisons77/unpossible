# IMPLEMENTATION_PLAN — unpossible

## Backlog

- [ ] Verify BATS test harness runs green via `docker compose -f projects/unpossible/infra/docker-compose.yml run --rm test`
- [ ] Add `new-project.sh` scaffold script that creates `projects/<name>/{specs,infra,src/test}` with stub files
- [ ] Add BATS test for `new-project.sh` (creates expected directory structure)
- [ ] Add BATS test that `loop.sh` exits non-zero when `ACTIVE_PROJECT` is missing

## Feature: Spec Organisation by Feature

- [ ] Document convention: `projects/<name>/specs/features/<feature-name>.md` for feature-scoped specs
- [ ] Update `PROMPT_plan.md` to scan `specs/features/` in addition to `specs/` root
- [ ] Add BATS test that plan prompt references the features directory

## Feature: Structured Work Log (ticket-style)

- [ ] Define `projects/<name>/WORKLOG.md` schema: each entry has `id`, `title`, `status` (todo/in-progress/done), `feature`, `started_at`, `completed_at`, `summary` (1–2 sentences), `commit`
- [ ] Update `PROMPT_build.md` to append a WORKLOG entry on each completed task
- [ ] Add `scripts/worklog.sh` that pretty-prints WORKLOG entries (filterable by status/feature) for UI consumption
- [ ] Add BATS test for `worklog.sh` output format

## Feature: Idea Parking Lot

- [ ] Define `projects/<name>/IDEAS.md` schema: each idea has `id`, `title`, `status` (parked/researching/ready/rejected), `description`, `open_questions`
- [ ] Add `./loop.sh research <idea-id>` mode: reads the idea, does web/codebase research, updates the idea entry with findings and sets status to `ready` or `rejected`
- [ ] Add `./loop.sh promote <idea-id>` command: moves a `ready` idea into `IMPLEMENTATION_PLAN.md` as a new task block
- [ ] Add BATS tests for research and promote modes

## Feature: Agent Code Review

- [ ] Add `PROMPT_review.md`: reviewer agent reads the last commit diff, checks alignment with specs, flags issues, writes findings to `projects/<name>/REVIEW.md`
- [ ] Add `./loop.sh review` mode that runs one review iteration after each build iteration (or on demand)
- [ ] Update `loop.sh` to optionally chain build → review when `REVIEW=1` env var is set
- [ ] Add BATS test that `PROMPT_review.md` exists and `loop.sh review` mode is reachable
