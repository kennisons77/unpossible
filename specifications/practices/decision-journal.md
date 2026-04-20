---
name: decision-journal
kind: practice
domain: Decision journal
description: Record thinking, challenges, and alternatives in each activity log entry
loaded_by: [build]
---

# Decision Journal

Every build loop iteration writes a decision journal entry in `activity.md` alongside
the existing change summary. This captures the thinking behind the code for posterity.

## Required Sections

Each activity log entry must include:

```
## YYYY-MM-DD HH:MM — {task title} (tag x.y.z)

**Changes:** (existing — what was done)

**Thinking:**
- Why this approach was chosen
- What the key insight or mental model was

**Challenges:**
- What was hard or surprising
- Common gotchas encountered and how they were avoided

**Alternatives considered:**
- Other approaches evaluated
- Why they were rejected (cost, complexity, coupling, etc.)

**Tradeoffs taken:**
- What was traded away and what was gained
- Known limitations or debt introduced
- Possible future issues to watch for
```

## Guidelines

- Be specific. "Considered X but rejected it because Y" is useful. "Thought about
  alternatives" is not.
- Name the gotcha. "PostgreSQL WHERE != excludes NULLs" is useful. "Had some SQL
  issues" is not.
- Future issues are predictions. State the trigger condition: "If we add multi-region,
  the single-writer assumption in LedgerAppender breaks."
- Keep entries concise — aim for 5–15 lines per section, not essays.
- If a task is trivial (rename, typo fix), the Thinking section can be one line:
  "Straightforward rename, no design decisions."

## Git Notes (future)

Once git-notes integration is built, the same journal content will be attached to the
commit as a structured note. The activity.md entry remains the source of truth during
the loop; the git note is the archival copy.
