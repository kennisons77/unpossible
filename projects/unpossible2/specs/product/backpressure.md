# Backpressure

## What It Does

Blocks the Ralph Wiggum loop from marking a task complete until all verification checks pass.
The agent cannot commit or advance until the full check suite exits green.

## Check Layers

### 1. Property-Based Tests (primary signal)
- Verify invariants across the full input space, not just example cases
- Language-agnostic: agent selects the appropriate property-testing library based on the language declared in `specs/prd.md`
- Every property test must include a comment explaining the invariant it verifies

### 2. Unit & Integration Tests
- Targeted tests for specific scenarios and edge cases
- Complement property tests; do not replace them

### 3. Linters
- Run every iteration
- Enforce code style and catch static errors early

## Failure Reporting

On any check failure, the loop feeds back a structured summary — not raw output:

- Which check failed (lint / unit / property / playwright)
- First failing assertion or error message with file and line
- Exit code

If more detail is needed, the agent re-runs the specific failing check inside the container.

## Playwright (Optional)

Enabled by declaring `UI: true` in `specs/prd.md`. When enabled:

- **Regression suite** — runs every iteration; verifies nothing is broken
- **Feature suite** — runs when the completed task is UI-related; verifies the new behavior

The agent writes Playwright tests at the time of implementing each UI feature.
Tests live in `app/tests/e2e/`.

## Acceptance Criteria

- [ ] Non-zero exit from any check blocks task completion
- [ ] Failure summary includes check type, first error, and location
- [ ] Property-based tests are present for all non-trivial logic
- [ ] Playwright suite is skipped cleanly when `UI` is not declared in `specs/prd.md`
