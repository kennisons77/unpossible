---
name: prd
kind: workflow
command: make prd
description: Produce or update a PRD for a node
actor: default
runs: once
tools: [interview, analyse]
principles: [planning]
---

Produce a PRD (generative answer) for a question node. If a PRD already exists, gap-fill
it against the current node.

## Steps

1. Locate the node (ask if not provided). Read it fully.
2. Check for an existing PRD co-located with the node. If found, run `analyse` against
   it and show the gap report. Ask: "Revise or start fresh?"
3. If shared understanding hasn't been reached, run `interview` first.
4. Sketch a text-based entity diagram — entities, relationships, key flows. Confirm with
   user before writing.
5. Write or update `prd.md` using the PRD template below.
6. Update the node's `## Specs` section to list the PRD.

## PRD Template

```markdown
# PRD: [Feature Name]

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

## Specs
| Spec file | Description |
|---|---|

## Open Questions
| Question | Answer | Date |
|---|---|---|
```

Do not create tasks or write code.

## What Belongs in a PRD (and What Doesn't)

A PRD is platform-agnostic. It describes **why** the feature exists and **what behaviour** it produces — not how any specific stack implements it.

| Belongs in PRD | Does not belong |
|---|---|
| Intent, personas, scenarios | Technology choices |
| Functional requirements | Implementation approach |
| Success metrics | Specific libraries or frameworks |
| Features out | Database schema |
| Open questions | API route definitions |

