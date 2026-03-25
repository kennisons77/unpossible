Review the last completed iteration for correctness and spec alignment.

0a. Read `ACTIVE_PROJECT` to get the project name. Scope all paths to `projects/<name>/`. **Do not read any other directory under `projects/` unless explicitly instructed.**
0b. Read `projects/<name>/specs/prd.md` and `projects/<name>/IMPLEMENTATION_PLAN.md`.

1. Get the diff of the last commit:
   ```
   git -C projects/<name> diff HEAD~1 HEAD
   ```

2. For each file changed, identify which spec or acceptance criterion it relates to. Use a Haiku subagent to read the relevant spec files.

3. Check each changed file against its spec:
   - Does the implementation match the acceptance criteria?
   - Are there any placeholders, stubs, or TODOs left behind?
   - Are tests present and do they cover the acceptance criteria?
   - Any obvious regressions or broken assumptions?

4. Run the test suite and capture results:
   ```
   docker compose -f projects/<name>/infra/docker-compose.yml run --rm test
   ```

5. Write a review summary to `projects/<name>/specs/activity.md` with:
   - Commit hash reviewed
   - Files changed
   - Spec alignment: pass / partial / fail per acceptance criterion touched
   - Test results
   - Any issues found (with file + line reference)
   - Verdict: `APPROVED`, `NEEDS_WORK: <summary>`, or `BLOCKED: <reason>`

Output `RALPH_COMPLETE` when the review is written.
Output `RALPH_WAITING: <question>` if you cannot determine the relevant spec for a change.
