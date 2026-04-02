---
name: review
kind: workflow
command: make review
description: Analyse the codebase for architectural weaknesses and propose beats to address them
actor: default
runs: once
tools: [analyse]
principles: [testing]
---

Explore the codebase and identify weaknesses that make it harder for agents to navigate,
test, and extend. Produce a set of proposed beats for the user to accept or reject.

## Look for

- Concepts that require bouncing between many small files to understand
- Pure functions extracted only for testability, where real bugs hide in how they're called
- Tightly coupled modules with unclear boundaries
- Test boundaries that are ambiguous — unclear which layer to test at
- Spec acceptance criteria that have no corresponding test

## Steps

1. Explore the codebase. Do not make any changes.
2. Run `analyse` — compare specs against implementation. Note gaps and inconsistencies.
3. Present 3–5 deepening candidates. For each:
   - Current structure and why it causes confusion
   - Proposed deeper module with a thinner interface
   - What becomes easier to test after the change
4. Wait for the user to select candidates.
5. For each accepted candidate, POST a beat to `/api/nodes` describing the refactor.
   One beat per candidate.

Do not modify any files until the user explicitly accepts a candidate.
