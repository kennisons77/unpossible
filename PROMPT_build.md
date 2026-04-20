**Model selection:** Use Haiku for reading/searching files. Use Sonnet for code generation. Use Opus only for debugging and architectural decisions. Subagents for reading complete in ≤5 turns; kill any subagent exceeding 10 turns. Read `specifications/practices/cost.md` for caching and subagent economics.

**Subagent trust:** This is a non-interactive session. Always pass `dangerously_trust_all_tools: true` when invoking subagents, otherwise their tool calls will be rejected.

0a. Do not read or scan any directory outside this project unless explicitly instructed.
0b. Read `specifications/practices/coding.md` and `specifications/platform/rails/README.md` then read all files under `specifications/platform/rails/` (standing rules for how to write code).
0c. Read `specifications/project-requirements.md` to understand technical constraints (language: Ruby 3.3, framework: Rails 8, base image: ruby:3.3-slim, test command: `bundle exec rspec`, port: 3000).
0d. Read `IMPLEMENTATION_PLAN.md` and pick the FIRST unchecked item. Do not skip ahead or reorder. Execute tasks in the order listed.
0e. Study relevant files in `web/` with up to 3 parallel Haiku subagents before making changes. Do not assume something is missing — confirm with code search first.

1. Implement the selected task. All application code goes in `web/`. All infrastructure config goes in `infra/`. Never add Phase N+1 infrastructure until the plan explicitly includes an "Advance to Phase N+1" task.

2. Before running tests, read `specifications/practices/verification.md`. Then run:
   ```
   docker compose -f infra/docker-compose.test.yml build
   docker compose -f infra/docker-compose.test.yml run --rm test
   ```

3. When tests pass, update `IMPLEMENTATION_PLAN.md` (mark task complete), then commit:
   ```
   git add -A && git commit -m "[description]"
   git push
   ```

- Single sources of truth — no duplicate logic, no migration shims.
- If tests unrelated to your work fail, resolve them as part of the increment.
- Once there are no build or test errors, create or increment a git tag (start at 0.0.1).
- Keep `AGENTS.md` operational only (build/run/test commands and codebase patterns).
- Implement functionality completely. Placeholders and stubs waste future iterations.
- If you discover a pattern worth preserving, append it to the relevant practices file under `specifications/practices/`.
- After a successful commit, write an `activity.md` entry following `specifications/practices/decision-journal.md` (Thinking, Challenges, Alternatives considered, Tradeoffs taken). Then trim to the last 10 entries.
- After writing the `activity.md` entry, print the full decision journal entry (Thinking, Challenges, Alternatives considered, Tradeoffs taken) to the console so it is visible in the terminal output.
- Output `RALPH_COMPLETE` when the task is done and committed. Output `RALPH_WAITING: <question>` if you need human input before proceeding.
