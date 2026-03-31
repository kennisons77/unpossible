---
name: improve-codebase-architecture
command: make improve-codebase-architecture
description: Find shallow modules, propose deepening candidates
model: opus
loop_type: none
principles: [testing]
---

Explore the codebase and identify architectural weaknesses that make it harder for agents to navigate and test. Do not make any changes.

## Look for

- Concepts that require bouncing between many small files to understand
- Pure functions extracted only for testability, where real bugs hide in how they're called
- Tightly coupled modules with unclear boundaries
- Test boundaries that are ambiguous — it's unclear which layer to test at

## Output

Present 3–5 deepening candidates. For each, show:
- The current structure and why it causes confusion
- A proposed deeper module with a thinner interface
- What becomes easier to test after the change

Present all candidates to the user. Do not create any tasks or modify any files.

Only after the user explicitly selects a candidate, create a task via POST to `$UNPOSSIBLE_API_URL/api/tasks` describing the refactor. One task per accepted candidate.
