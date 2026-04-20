---
name: requirements
kind: workflow
command: make requirements
description: Produce or update requirements for a concept
actor: default
runs: once
tools: [interview, analyse]
principles: [planning]
---

Produce a requirements document (precise technical translation) for a concept. If
requirements already exist, gap-fill against the current concept.

## Steps

1. Locate the concept (ask if not provided). Read it fully.
2. Check for an existing `requirements.md` co-located with the concept. If found, run
   `analyse` against it and show the gap report. Ask: "Revise or start fresh?"
3. If shared understanding hasn't been reached, run `interview` first.
4. Sketch a text-based entity diagram — entities, relationships, key flows. Confirm with
   user before writing.
5. Write or update `requirements.md` using the requirements template below.
6. Update the concept's `## Specifications` section to list the requirements file.

## Requirements Template

```markdown
# Requirements: [Feature Name]

- **Status:** Draft
- **Created:** [date]
- **Last revised:** [date]

## Intent
One or two sentences. What this is and why it exists.

## Personas
Who uses this and what they need from it.

## User Scenarios
Narrative paragraphs — before, during, after for each persona.

## User Stories
- As a [persona], I want [action] so that [outcome].

## Success Metrics
| Goal | Metric |
|---|---|

## Functional Requirements
**MVP:**
**Post-MVP:**

## Features Out

## Specifications
| File | Description |
|---|---|

## Open Questions
| Question | Answer | Date |
|---|---|---|
```

Do not create tasks or write code.

## What Belongs in Requirements (and What Doesn't)

Requirements are platform-agnostic. They describe **why** the feature exists and **what
behaviour** it produces — not how any specific stack implements it.

| Belongs in requirements | Does not belong |
|---|---|
| Intent, personas, scenarios | Technology choices |
| Functional requirements | Implementation approach |
| Success metrics | Specific libraries or frameworks |
| Features out | Database schema |
| Open questions | API route definitions |

