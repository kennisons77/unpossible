0a. Do not read or scan any directory outside this project unless explicitly instructed.
0b. Read `specifications/practices/planning.md` and `specifications/practices/cost.md`.

**Subagent trust:** This is a non-interactive session. Always pass `dangerously_trust_all_tools: true` when invoking subagents, otherwise their tool calls will be rejected.

0c. Study `specifications/` with up to 5 parallel Haiku subagents. Pay close attention to:
    - `specifications/project-requirements.md` — technical constraints (Ruby 3.3, Rails 8, ruby:3.3-slim, `bundle exec rspec`, port 3000)
    - Spec layout: `specifications/system/` (platform internals), `specifications/skills/` (agent instructions), `specifications/practices/` (discipline rules), `specifications/platform/rails/` (Rails overrides)
    - Platform overrides in `specifications/platform/rails/` mirror the same structure as `specifications/system/`. Read the base concept first, then layer the matching platform override on top.
0d. Read `specifications/platform/rails/README.md` then read all files under `specifications/platform/rails/` for Rails-specific conventions.
0e. Delete `IMPLEMENTATION_PLAN.md` if it exists. The plan is regenerated from scratch every planning loop (see `specifications/practices/planning.md` § Plan Freshness). Do not carry forward old plan content — discover completed work from code and git state.
0f. Study `web/` and `go/` (if present) with up to 5 parallel Haiku subagents to understand what has been implemented.

1. Perform a gap analysis comparing `web/` and `go/` against the specifications. Use an Opus subagent to analyze findings and create `IMPLEMENTATION_PLAN.md`. Ultrathink.

   Scope the plan to Phase 0 only (Docker Compose, no CI, no k8s, no staging). For each task, derive required tests from the acceptance criteria in the relevant concept and include them in the task definition.

   Consider missing features, TODOs, placeholders, skipped/flaky tests, and inconsistent patterns. Flag `infra/Dockerfile` and `infra/docker-compose.yml` placeholder values as high-priority tasks.

   For any concept with unresolved open questions or unfamiliar domain: create a spike task before any build tasks that depend on it:
   ```
   - [ ] [SPIKE] Research <topic> — run `./loop.sh research <id>` (see specifications/skills/tools/research.md)
   ```
   Spike tasks block all build tasks that depend on the concept they cover.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing — confirm with code search in `web/` first.

After updating `IMPLEMENTATION_PLAN.md`, trim `activity.md` to the last 10 entries.

Output `RALPH_COMPLETE` when the plan is written and activity.md is trimmed.
