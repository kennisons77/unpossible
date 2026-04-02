# Testing Principals

## Core Principles

- **Test behavior, not implementation.** Tests should verify what the code does, not how it does it.
- **One assertion per test** where possible. Multiple assertions signal multiple behaviors that should be split.
- **Test all cases.** For each unit of behavior, cover: happy path, edge cases, and error/invalid input.
- **Prefer real dependencies over mocks** for integration tests. Mock only at system boundaries (external APIs, file system, clock).
- **Keep tests fast.** Slow tests break the development loop. Isolate slow tests (DB, network) so unit tests can run quickly.
- **Tests are documentation.** A failing test should tell you exactly what broke and why.

## Test Categories

### Unit Tests
- Test individual functions/modules in isolation.
- Fast, no I/O, no external dependencies.
- Cover edge cases and error conditions.

### Integration Tests
- Test how components work together.
- May use real databases, file system, etc.
- Slower — run separately from unit tests if needed.

### End-to-End Tests
- Test the full application flow from the user's perspective.
- Fewest in number, highest value for regressions.

## What NOT to Test

- Third-party library internals.
- Trivial getters/setters with no logic.
- Code that is about to be deleted.
