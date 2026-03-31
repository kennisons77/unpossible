---
name: tdd
command: make tdd TASK=<id>
description: Red-green-refactor loop with interface-first philosophy
model: sonnet
loop_type: build
principles: [testing, verification]
---

Fetch task `$TASK` from `$UNPOSSIBLE_API_URL/api/tasks/$TASK`. Use its acceptance criteria to drive the loop.

## Loop

1. **Design the interface** — before writing any test, agree on the interface. What are the inputs, outputs, and boundaries? Explore the codebase to understand what already exists.
2. **Write one test** — write the smallest test that describes one behavior from the acceptance criteria. Run it. It must fail (red).
3. **Implement** — write the minimum code to make the test pass. Run it. It must pass (green).
4. **Refactor** — clean up without changing behavior. Run tests again. Still green.
5. **Typecheck + lint** — run the typechecker and linter. Fix any errors before continuing.
6. **Repeat** — return to step 2 for the next behavior until all acceptance criteria are covered.
7. **Commit** — only after all acceptance criteria are green, commit the work.
8. **Complete task** — PATCH `$UNPOSSIBLE_API_URL/api/tasks/$TASK` with `status: "complete"`.

Update task status to `in_progress` at step 1 and `complete` only at step 8. Do not commit partial work.
