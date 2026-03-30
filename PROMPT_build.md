**Model selection:** Use Haiku for reading/searching files. Use Sonnet for code generation. Use Opus only for debugging and architectural decisions. Subagents for reading complete in ≤5 turns; kill any subagent exceeding 10 turns. Read `practices/general/cost.md` for caching and subagent economics — apply `cache_control: {type: "ephemeral", ttl: "1h"}` to specs, practices files, and prd.md passed to subagents.

0a. Read `ACTIVE_PROJECT` (root-level file) to get the project name. All project paths below use `projects/<name>/` as the root. **Do not read or scan any other directory under `projects/` unless explicitly instructed.**
0b. Read `practices/general/coding.md` — these are the standing rules for how to write code in this project.
0c. Read the language-specific practices file if it exists: `practices/lang/[language].md` (language from `projects/<name>/specs/prd.md`). Read the framework-specific file if it exists: `practices/framework/[framework].md`.
0d. Read `projects/<name>/specs/prd.md` and `projects/<name>/specs/plan.md` directly to understand the goal and current status. Pay close attention to Technical Constraints for language, framework, base image, and test command.
    **Spec layout:** specs are split into three directories:
    - `projects/<name>/specs/system/` — specs that describe unpossible's own internals (tasks, knowledge, agents, sandbox, runner, loop, analytics system)
    - `projects/<name>/specs/product/` — reusable specs for products built by unpossible (auth, security, backpressure, analytics product)
    - `projects/<name>/specs/` root — project-wide files (prd.md, audience.md, activity.md)
    **Spec inheritance:** platform-specific overrides mirror the same `system/` and `product/` split under `projects/<name>/specs/platform/<platform>/system/` and `projects/<name>/specs/platform/<platform>/product/`. An override shares the same filename as the base spec it extends. When implementing a feature, read the base spec first, then check for a matching platform override and layer it on top. The override adds implementation detail — it does not replace the base acceptance criteria.
0e. Study `projects/<name>/IMPLEMENTATION_PLAN.md`.
0f. Study relevant files in `projects/<name>/src/` with up to 3 parallel Haiku subagents before making changes.

1. Follow `projects/<name>/IMPLEMENTATION_PLAN.md` and choose the most important unchecked item. Before making changes, search `projects/<name>/src/` (don't assume not implemented) using up to 3 Haiku subagents. Use 1 Sonnet subagent for build/tests. Use an Opus subagent for complex reasoning (debugging, architectural decisions).

2. All application code goes in `projects/<name>/src/`. All infrastructure config lives in `projects/<name>/infra/`. Check `## Phase` in `projects/<name>/specs/prd.md` and follow the phase rules in `practices/general/planning.md` before touching any infra. Never add Phase N+1 infrastructure until the plan explicitly includes an "Advance to Phase N+1" task.

3. Before running tests, read `practices/general/verification.md`. Then run:
   ```
   docker compose -f projects/<name>/infra/docker-compose.yml build
   docker compose -f projects/<name>/infra/docker-compose.yml run --rm test
   ```
   If the Dockerfile still has placeholder values, fill them in from `projects/<name>/specs/prd.md` first.

4. When tests pass, update `projects/<name>/IMPLEMENTATION_PLAN.md`, then commit:
   ```
   git add -A && git commit -m "[description]"
   git push
   ```

- Capture the *why* in documentation and commit messages.
- Single sources of truth — no duplicate logic, no migration shims.
- If tests unrelated to your work fail, resolve them as part of the increment.
- Once there are no build or test errors, create or increment a git tag (start at 0.0.1).
- Keep `projects/<name>/IMPLEMENTATION_PLAN.md` current — clean out completed items when it gets large.
- Keep `projects/<name>/AGENTS.md` operational only (build/run/test commands and codebase patterns). Progress notes belong in `IMPLEMENTATION_PLAN.md`.
- Implement functionality completely. Placeholders and stubs waste future iterations.
- If you find inconsistencies in `projects/<name>/specs/*`, use an Opus subagent to update them.
- Update phase-appropriate infra files when ports, environment variables, or resource needs change (see rule 2 above).
- If you discover a pattern worth preserving (a gotcha, a convention, a hard-won lesson), append it to the relevant practices file: `practices/general/coding.md`, `practices/lang/[language].md`, or `practices/framework/[framework].md`. Keep entries terse.
- After a successful commit, trim `projects/<name>/specs/activity.md` to the last 10 entries (prepend a one-line summary of removed entries).
- Output `RALPH_COMPLETE` when the task is done and committed. Output `RALPH_WAITING: <question>` if you need human input before proceeding.
