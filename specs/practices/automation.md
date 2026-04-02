# Automation

When a task is deterministic — the same input always produces the same output — prefer
a script over an LLM call. Scripts are cheaper, faster, and testable. LLMs are for
tasks that require judgment, not tasks that require computation.

## When to Automate

Automate when:
- The logic can be fully specified as rules (linting, formatting, validation, parsing)
- The output is verifiable without human judgment
- The task runs repeatedly on similar inputs

Do not automate when:
- The task requires interpreting ambiguous input
- The correct output depends on context the script cannot access
- The logic is likely to change — a script that needs constant updating is worse than
  an LLM call

## Runtime Constraint

All automation scripts must run in one of two places:
- **Default runtime** — the main application container (Rails, Go sidecar)
- **Lightweight sidecar** — a minimal container with no application dependencies

No scripts that require a separate install, a different language runtime, or manual
setup. If it can't run in the default runtime or a sidecar, it doesn't ship.

## Hypothesis First

Before implementing a script, state the hypothesis:
- What problem does this solve?
- What is the expected improvement (speed, cost, accuracy)?
- How will we know if it worked?

A script without a hypothesis is a feature flag without a metric — it accumulates
without accountability. Use the feature flag system: ship behind a flag, measure,
promote or remove.

**Re-evaluate before promoting.** A hypothesis implemented as a script must be reviewed
against actual results before the flag is removed and the behaviour becomes default.
If the hypothesis was wrong, remove the script — do not leave it running on false
premises.

## Quality Bar

Every automation script must be:
- **Fully tested** — unit tests covering happy path, edge cases, and failure modes
- **Instrumented** — emits metrics or logs that make its behaviour observable
- **Idempotent** — running twice produces the same result as running once
- **Documented** — one paragraph explaining what it does and why it exists

A script that is not tested is a liability. A script that is not instrumented is
invisible. Both are worse than the LLM call they replaced.
