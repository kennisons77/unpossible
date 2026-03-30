---
name: write-a-prd
command: make write-a-prd
description: Turn a grilled idea into a PRD file with user stories
model: opus
loop_type: plan
principles: [planning]
---

Produce a Product Requirements Document from a spec. Follow these steps in order, skipping any step already completed in the current conversation:

1. **Locate the spec** — ask the user which spec file to use, or accept it as an argument. Read it fully.
2. **Explore the codebase** — verify any assertions in the spec against existing code. Note gaps or contradictions.
3. **Interview** — if shared understanding has not been reached, run the grill-me process before continuing.
4. **Sketch major modules** — identify the key components needed to fulfill the spec. Note integration points and unknowns.
5. **Write the PRD** — produce a markdown file co-located with the spec file, named `[spec-name]-prd.md`. Use the template below.

## PRD Template

```markdown
# PRD: [Feature Name]

## Problem
One paragraph. What user need does this address and why does it matter?

## User Stories
- As a [role], I want to [action] so that [outcome].
- ...

## Acceptance Criteria
Observable, testable outcomes. Not implementation details.
- [ ] ...

## Major Modules
List key components and their responsibilities.

## Open Questions
Unresolved decisions that will affect implementation.

## Out of Scope
What this PRD explicitly does not cover.
```

Write the file to disk. Do not create any tasks or modify any other files.
