# General Verification Practices

Loaded when running tests. Applies regardless of language or framework.

## Backpressure

Tests, typechecks, lints, and builds are not just quality gates — they are the mechanism that
prevents the loop from marking work done when it isn't. A task is not complete until the full
validation suite passes. This is called **acceptance-driven backpressure**: the agent cannot
move forward until reality agrees with the spec.

Without strong backpressure the loop produces the appearance of progress rather than actual
progress. Every skipped test or suppressed error is a hole in that pressure.

### Check Layers

1. **Property-based tests** — verify invariants across the full input space, not just example cases. Every property test must include a comment explaining the invariant it verifies. Agent selects the appropriate library based on the language in `specs/prd.md`.
2. **Unit & integration tests** — targeted tests for specific scenarios and edge cases.
3. **Linters** — run every iteration. Enforce code style and catch static errors early.
4. **Playwright** (optional) — enabled by declaring `UI: true` in `specs/prd.md`. Regression suite runs every iteration; feature suite runs when the completed beat is UI-related.

### Failure Reporting

On any check failure, feed back a structured summary — not raw output:
- Which check failed (lint / unit / property / playwright)
- First failing assertion or error message with file and line
- Exit code

### LLM-as-Judge
For criteria that can't be expressed as a traditional test (tone, visual layout, subjective
quality), write an LLM-as-judge check: a prompt that evaluates output against the spec and
returns pass/fail. Treat it as a first-class test — it must pass before committing.

## Tool Effectiveness Benchmarking

The `agent_override` flag on `AgentRun` enables a controlled comparison between enrichment
tools and raw agent capability. Use it to build benchmark test cases:

**Pattern:**
1. Run the same beat twice against the same context — once normally, once with `agent_override: true`
2. Record tokens, cost, duration, and output for both runs
3. Evaluate output quality via one of:
   - **Human review** — a person judges which output better satisfies the acceptance criteria
   - **Blind model comparison** — submit both outputs to a judge model with the spec as rubric,
     without revealing which run used enrichment. Ask for a preference and a reason.

**What to measure:**
- Token delta — how much context did the enrichment tool save the agent from generating itself?
- Cost delta — did the enrichment tool call cost less than the equivalent agent tokens?
- Quality delta — did enrichment improve, degrade, or not affect output quality?

**When to run:**
- When adding a new enrichment tool — establish its baseline before shipping
- When a tool's effectiveness is questioned — re-run the benchmark
- Not every iteration — this is a deliberate, periodic check, not part of the build loop

Keep benchmark runs tagged with `agent_override: true` so they're queryable from run history.

## Before Running Tests
- Rebuild the Docker image if dependencies or the Dockerfile changed
- Run the full test suite, not just tests for the code you touched
- If unrelated tests fail, fix them — don't skip or suppress

## What to Test
- Test behavior, not implementation — tests should survive refactoring
- Cover: happy path, edge cases, invalid input, error conditions
- Each test should have one reason to fail
- Test names should read as sentences describing the expected behavior

## What Not to Test
- Third-party library internals
- Trivial pass-through code with no logic
- Code that is about to be deleted

## On Failure
- Read the full error output before changing anything
- Reproduce the failure with the smallest possible input
- Fix the root cause — don't mask the failure with a broader catch or a skip
- If a test is genuinely wrong (not the code), fix the test and document why

## After Tests Pass
- Commit immediately — don't bundle multiple task completions into one commit
- Tag if this brings the build to a fully green state (increment patch: 0.0.1, 0.0.2, ...)
- Update `IMPLEMENTATION_PLAN.md` to mark the task complete
