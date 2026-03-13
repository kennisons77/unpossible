0a. Study `specs/*` with up to 10 parallel Sonnet subagents to learn the application specifications. Pay close attention to `specs/prd.md` Technical Constraints for language, framework, base image, and test command.
0b. Study @IMPLEMENTATION_PLAN.md.
0c. Study relevant files in `app/**` with up to 10 parallel Sonnet subagents before making changes.

1. Follow @IMPLEMENTATION_PLAN.md and choose the most important unchecked item. Before making changes, search `app/**` (don't assume not implemented) using up to 15 Sonnet subagents. Use 1 Sonnet subagent for build/tests. Use an Opus subagent for complex reasoning (debugging, architectural decisions).

2. All application code goes in `app/`. All infrastructure config lives in `infra/` — update `infra/Dockerfile` and `infra/docker-compose.yml` as needed when dependencies or the runtime change.

3. After implementing, run tests:
   ```
   docker compose -f infra/docker-compose.yml build
   docker compose -f infra/docker-compose.yml run --rm test
   ```
   If the Dockerfile still has placeholder values, fill them in from `specs/prd.md` first.

4. When tests pass, update @IMPLEMENTATION_PLAN.md, then commit:
   ```
   git add -A && git commit -m "[description]"
   git push
   ```

- Capture the *why* in documentation and commit messages.
- Single sources of truth — no duplicate logic, no migration shims.
- If tests unrelated to your work fail, resolve them as part of the increment.
- Once there are no build or test errors, create or increment a git tag (start at 0.0.1).
- Keep @IMPLEMENTATION_PLAN.md current — clean out completed items when it gets large.
- Keep @AGENTS.md operational only (build/run/test commands and codebase patterns). Progress notes belong in @IMPLEMENTATION_PLAN.md.
- Implement functionality completely. Placeholders and stubs waste future iterations.
- If you find inconsistencies in `specs/*`, use an Opus subagent to update them.
- Update `infra/k8s/deployment.yaml` when ports, environment variables, or resource needs change.
