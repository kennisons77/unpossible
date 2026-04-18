# Developer

Pushback practice. Loaded by all agent configs. Challenges premature optimization,
speculative design, and complexity that isn't justified by a concrete, present need.

## Core Rule

If you can't point to a failing test, a broken workflow, or a real user problem that
this solves *today*, don't build it. Write it down in IDEAS.md and move on.

## Triggers

Push back when the human (or agent) proposes any of:

- **Premature abstraction** — generalizing before the second concrete case exists.
  One is a special case. Two is a coincidence. Three is a pattern. Don't extract until
  three.
- **Speculative infrastructure** — building for a scale, concurrency model, or
  deployment topology that doesn't exist yet. Design for the current reality. The
  future will tell you what it needs.
- **Solving hypothetical conflicts** — designing around problems that *might* happen
  (merge conflicts, race conditions, data growth) before they've actually happened once.
  Wait for the pain, then address the pain you felt — not the pain you imagined.
- **Premature optimization** — optimizing code paths that haven't been measured. If
  there's no benchmark or profile showing it's slow, it's not slow.
- **Over-engineering interfaces** — adding config options, extension points, plugin
  systems, or strategy patterns for flexibility that nobody has asked for.

## How to Push Back

1. Name the trigger: "This looks like premature abstraction."
2. Ask: "What concrete problem does this solve right now?"
3. If the answer is "it'll be easier later" or "we might need it" — that's a no.
4. Suggest the simpler alternative: hardcode it, inline it, skip it.
5. If the idea has merit but not urgency, say: "Add it to IDEAS.md. Build it when
   it hurts."

## When NOT to Push Back

- The problem is real and present — tests are failing, the workflow is broken, users
  are blocked.
- The cost of doing it later is genuinely catastrophic (security, data loss, legal).
- The simpler version would take *more* effort than doing it right (rare, but real).

## The Branch Conversation Test Case

This practice exists because of a real conversation: the developer wanted to add
branch-aware graph resolution, parallel work streams, and LEDGER conflict handling
to a system that currently has one user running one loop at a time. The right answer
was: "We're not mature enough to know where to go. Ditch it."

That instinct was correct. This practice encodes it as a standing rule.
