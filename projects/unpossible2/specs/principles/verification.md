# General Verification Practices

Loaded when running tests. Applies regardless of language or framework.

## Backpressure

Tests, typechecks, lints, and builds are not just quality gates — they are the mechanism that
prevents the loop from marking work done when it isn't. A task is not complete until the full
validation suite passes. This is called **acceptance-driven backpressure**: the agent cannot
move forward until reality agrees with the spec.

Without strong backpressure the loop produces the appearance of progress rather than actual
progress. Every skipped test or suppressed error is a hole in that pressure.

### LLM-as-Judge
For criteria that can't be expressed as a traditional test (tone, visual layout, subjective
quality), write an LLM-as-judge check: a prompt that evaluates output against the spec and
returns pass/fail. Treat it as a first-class test — it must pass before committing, just like
any other assertion.

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
