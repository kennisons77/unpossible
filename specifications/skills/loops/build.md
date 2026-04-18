---
name: build
kind: loop
command: ./loop.sh [n]
description: Execute beats until tests pass
actor: default
runs: until — tests green and beat accepted
principles: [testing, verification, coding]
---

Execute one beat per iteration until the beat's acceptance criteria are met and the
verdict is accepted.

## Each Iteration

1. Read `IMPLEMENTATION_PLAN.md` for the oldest open unblocked beat.
2. Read the beat's acceptance criteria and the spec it belongs to.
3. **Design the interface** — before writing any test, agree on the interface. What are
   the inputs, outputs, and boundaries? Explore the codebase to understand what already
   exists.
4. **Red** — write the smallest test that describes one behaviour from the acceptance
   criteria. Run it. It must fail.
5. **Green** — write the minimum code to make the test pass. Run it. It must pass.
6. **Refactor** — clean up without changing behaviour. Run tests again. Still green.
7. **Typecheck + lint** — fix any errors before continuing.
8. **Repeat** steps 4–7 for each acceptance criterion until all are green.
9. Commit. Mark the beat complete in `IMPLEMENTATION_PLAN.md`.
10. Log to `specifications/activity.md`.
11. Output `RALPH_COMPLETE` when no open unblocked beats remain.

## RALPH Signals

- `RALPH_COMPLETE` — beat done, loop exits 0
- `RALPH_WAITING: <question>` — agent needs human input, loop pauses

Output exactly one of these at the end of every iteration. The runner scans stdout for
them after each iteration. 3 consecutive iterations without a signal stops the loop with
exit 2.

## Rollback Guard

Each iteration is wrapped in a git stash guard:
1. `git stash push -m "ralph-pre-iteration-$N"` before agent runs
2. On success: `git stash drop`
3. On failure: `git stash pop` — working tree restored

Do not commit partial work. Do not mark a beat complete until tests, typechecks, and
lints all pass.

## Practices

`cost.md` and `version-control.md` are always in context. All other practices
(`coding.md`, `verification.md`, `security.md`) are loaded by file path on demand —
not loaded by default. If the agent hits an issue, load the relevant practice by name before proceeding.
