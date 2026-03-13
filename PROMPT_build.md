0a. Study `specs/*` with up to 10 parallel Sonnet subagents to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md.
0c. Study relevant source code with up to 10 parallel Sonnet subagents before making changes.

1. Your task is to implement functionality per the specifications. Follow @IMPLEMENTATION_PLAN.md and choose the most important unchecked item. Before making changes, search the codebase (don't assume not implemented) using up to 15 Sonnet subagents. Use 1 Sonnet subagent for build/tests. Use an Opus subagent when complex reasoning is needed (debugging, architectural decisions).
2. After implementing, run the tests for the code you changed. If functionality is missing per the specs, add it. Ultrathink.
3. When you discover issues, immediately update @IMPLEMENTATION_PLAN.md with your findings. When resolved, remove the item.
4. When tests pass, update @IMPLEMENTATION_PLAN.md, then commit: `git add -A && git commit -m "[description]"`. After the commit, `git push`.

- Capture the *why* in documentation and commit messages.
- Single sources of truth — no duplicate logic, no migration shims.
- If tests unrelated to your work fail, resolve them as part of the increment.
- Once there are no build or test errors, create or increment a git tag (start at 0.0.1).
- Keep @IMPLEMENTATION_PLAN.md current — future iterations depend on it to avoid duplicating effort. Clean out completed items when it gets large.
- Keep @AGENTS.md operational only (build/run/test commands and codebase patterns). Progress notes belong in @IMPLEMENTATION_PLAN.md.
- Implement functionality completely. Placeholders and stubs waste future iterations.
- If you find inconsistencies in `specs/*`, use an Opus subagent to update them.
