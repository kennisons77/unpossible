0a. Do not read or scan any directory outside this project unless explicitly instructed.
0b. Read `practices/general/planning.md` and `practices/general/cost.md`.

**Subagent trust:** This is a non-interactive session. Always pass `dangerously_trust_all_tools: true` when invoking subagents, otherwise their tool calls will be rejected.

0c. Study `specs/` with up to 5 parallel Haiku subagents. Pay close attention to:
    - `specs/prd.md` — technical constraints (Ruby 3.3, Rails 8, ruby:3.3-slim, `bundle exec rspec`, port 3000)
    - Spec layout: `specs/system/` (platform internals), `specs/skills/` (agent instructions), `specs/practices/` (discipline rules), `specs/platform/rails/` (Rails overrides)
    - Platform overrides in `specs/platform/rails/` mirror the same structure as `specs/system/`. Read the base spec first, then layer the matching platform override on top.
0d. Read `practices/lang/ruby.md` and `practices/framework/rails.md`.
0e. Delete `IMPLEMENTATION_PLAN.md` if it exists. The plan is regenerated from scratch every planning loop (see `practices/general/planning.md` § Plan Freshness). Do not carry forward old plan content — discover completed work from code and git state.
0f. Study `web/` and `go/` (if present) with up to 5 parallel Haiku subagents to understand what has been implemented.

1. Perform a gap analysis comparing `web/` and `go/` against the specs. Use an Opus subagent to analyze findings and create `IMPLEMENTATION_PLAN.md`. Ultrathink.

   Scope the plan to Phase 0 only (Docker Compose, no CI, no k8s, no staging). For each task, derive required tests from the acceptance criteria in the relevant spec and include them in the task definition.

   Consider missing features, TODOs, placeholders, skipped/flaky tests, and inconsistent patterns. Flag `infra/Dockerfile` and `infra/docker-compose.yml` placeholder values as high-priority tasks.

   For any spec with unresolved open questions or unfamiliar domain: create a spike task before any build tasks that depend on it:
   ```
   - [ ] [SPIKE] Research <topic> — run `./loop.sh research <id>` (see specs/skills/tools/research.md)
   ```
   Spike tasks block all build tasks that depend on the spec they cover.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing — confirm with code search in `web/` first.

After updating `IMPLEMENTATION_PLAN.md`, trim `activity.md` to the last 10 entries.

Output `RALPH_COMPLETE` when the plan is written and activity.md is trimmed.
