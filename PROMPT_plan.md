0a. Read `ACTIVE_PROJECT` (root-level file) to get the project name. All project paths below use `projects/<name>/` as the root.
0b. Read `practices/general/planning.md` — these are the standing rules for how to plan this project.
0c. Study `projects/<name>/specs/*` with up to 10 parallel Sonnet subagents. Pay close attention to:
    - `projects/<name>/specs/prd.md` Technical Constraints (language, framework, base image, test command)
    - `projects/<name>/specs/audience.md` if it exists — it defines the current target SLC release and the activities to plan for
0d. Read the language-specific practices file if it exists: `practices/lang/[language].md` (language from `projects/<name>/specs/prd.md`). Read the framework-specific file if it exists: `practices/framework/[framework].md`.
0e. Study `projects/<name>/IMPLEMENTATION_PLAN.md` (if present) to understand the plan so far.
0f. Study `projects/<name>/src/` with up to 10 parallel Sonnet subagents to understand what has been implemented so far.

1. Perform a gap analysis comparing `projects/<name>/src/` against the specs. Use an Opus subagent to analyze findings and create/update `projects/<name>/IMPLEMENTATION_PLAN.md`. Ultrathink.

   **If `projects/<name>/specs/audience.md` exists:** scope the plan to the **Current target release** defined there.
   Plan only the activities and capability depths for that release — not the full feature space.
   For each task, derive required tests from the acceptance criteria in the relevant spec file and
   include them in the task definition (see `practices/general/planning.md` for format).

   **If `projects/<name>/specs/audience.md` does not exist:** perform a full gap analysis across all specs.
   Prioritize by dependency order. Include required tests derived from acceptance criteria where
   specs define them.

   In both cases: consider missing features, TODOs, placeholders, skipped/flaky tests, and
   inconsistent patterns. Flag `projects/<name>/infra/Dockerfile` and `projects/<name>/infra/docker-compose.yml` placeholder
   values as high-priority tasks.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search in `projects/<name>/src/` first.

ULTIMATE GOAL: We want to achieve [project-specific goal — fill this in]. Consider missing elements and plan accordingly. If something is missing, search first to confirm it doesn't exist, then if needed author the specification at `projects/<name>/specs/FILENAME.md` and document the plan to implement it in `projects/<name>/IMPLEMENTATION_PLAN.md`.
