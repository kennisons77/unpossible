0a. Study `specs/*` with up to 10 parallel Sonnet subagents to learn the application specifications. Pay close attention to the Technical Constraints section of `specs/prd.md` — it defines the language, framework, base image, and test command.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0c. Study `app/**` with up to 10 parallel Sonnet subagents to understand what has been implemented so far.

1. Perform a gap analysis: compare what exists in `app/**` against what is required by `specs/prd.md` and `specs/plan.md`. Use an Opus subagent to analyze findings, prioritize gaps, and create/update @IMPLEMENTATION_PLAN.md as a bullet point list sorted by priority. Ultrathink. Consider: missing features, TODOs, placeholders, skipped/flaky tests, and inconsistent patterns.

Also check `infra/Dockerfile` and `infra/docker-compose.yml` — if they still contain placeholder values (e.g. `[base-image]`, `[your test command]`), add a high-priority task to fill them in from `specs/prd.md`.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search in `app/**` first.

ULTIMATE GOAL: We want to achieve [project-specific goal — fill this in]. Consider missing elements and plan accordingly. If an element is missing, search first to confirm it doesn't exist, then if needed author the specification at specs/FILENAME.md and document the plan to implement it in @IMPLEMENTATION_PLAN.md.
