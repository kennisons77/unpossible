# Verification

Loaded by plan loop (for AC-to-test derivation) and build loop (on demand).
Applies regardless of language or framework — platform-specific test tooling
lives in `specs/platform/{platform}/`.

## Backpressure

Tests, typechecks, lints, and builds are not just quality gates — they are the mechanism
that prevents the loop from marking work done when it isn't. A task is not complete until
the full validation suite passes. This is called **acceptance-driven backpressure**: the
agent cannot move forward until reality agrees with the spec.

Without strong backpressure the loop produces the appearance of progress rather than
actual progress. Every skipped test or suppressed error is a hole in that pressure.

## Core Principles

- Test behavior, not implementation — tests should survive refactoring
- One assertion per test where possible — multiple assertions signal multiple behaviors
- Prefer real dependencies over mocks for integration tests — mock only at system
  boundaries (external APIs, file system, clock)
- Keep tests fast — isolate slow tests (DB, network) so unit tests run quickly
- Tests are documentation — a failing test should tell you exactly what broke and why

## Check Layers

1. **Unit tests** — individual functions/modules in isolation, no I/O, no external
   dependencies. Cover happy path, edge cases, and error conditions.
2. **Integration tests** — how components work together. May use real databases, file
   system, etc. Slower — run separately from unit tests if needed.
3. **Property-based tests** — verify invariants across the input space, not just example
   cases. Preferred when the domain has clear invariants (parsers, serializers, state
   machines). Not required when unit + integration tests cover the behavior adequately.
   Each property test must include a comment explaining the invariant it verifies.
4. **Linters** — run every iteration. Enforce code style and catch static errors early.
5. **Playwright** (optional) — enabled by declaring `UI: true` in `specs/prd.md`.

## What to Test

- Cover: happy path, edge cases, invalid input, error conditions
- Each test should have one reason to fail
- Test names should read as sentences describing the expected behavior

## What NOT to Test

- Third-party library internals
- Trivial pass-through code with no logic
- Code that is about to be deleted

## Platform-Specific Testing

Base verification rules are platform-agnostic. Each platform has its own test tooling,
conventions, and helpers. Before writing tests, check `specs/platform/{platform}/` for:

- Test framework and runner (e.g. RSpec + FactoryBot for Rails, go test for Go)
- Helper patterns and shared contexts
- Database setup/teardown conventions
- Platform-specific assertion styles

The platform override is authoritative for *how* to test. This file is authoritative
for *what* to test and *when* a task is done.

## Failure Reporting

On any check failure, feed back a structured summary — not raw output:
- Which check failed (lint / unit / integration / property / playwright)
- First failing assertion or error message with file and line
- Exit code

## LLM-as-Judge

For criteria that can't be expressed as a traditional test (tone, visual layout,
subjective quality), write an LLM-as-judge check: a prompt that evaluates output
against the spec and returns pass/fail. Treat it as a first-class test — it must pass
before committing.

## Before Running Tests

- Rebuild the Docker image if dependencies or the Dockerfile changed
- Run the full test suite, not just tests for the code you touched
- If unrelated tests fail, fix them — don't skip or suppress

## On Failure

- Read the full error output before changing anything
- Reproduce the failure with the smallest possible input
- Fix the root cause — don't mask the failure with a broader catch or a skip
- If a test is genuinely wrong (not the code), fix the test and document why

## After Tests Pass

- Commit immediately — don't bundle multiple task completions into one commit
- Tag if this brings the build to a fully green state
- Update `IMPLEMENTATION_PLAN.md` to mark the task complete
