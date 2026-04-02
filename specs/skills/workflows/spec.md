---
name: spec
kind: workflow
command: make spec
description: Produce or update spec files for a PRD
actor: default
runs: once
tools: [interview, analyse, research]
principles: [planning]
---

Produce spec files (generative answers) for a PRD. If specs already exist, gap-fill them.

## Steps

1. Locate the PRD (ask if not provided). Read it fully. Identify the `## Specs` section
   — the list of spec files this PRD declares it needs. If absent, derive the list and
   confirm with user.
2. Check which specs already exist. Show status table. Ask: "Does this look right?"
3. For each spec to write or revise, ask:
   - Does this need research first? (unfamiliar domain, unresolved open questions)
   - Is there an existing library or prior art to reference?
   - Which other nodes does this touch?
   - Are the acceptance criteria specific enough to derive tests from?
   If research is needed, stop and run the `research` tool first.
4. Run `analyse` on any existing specs against the PRD. Report gaps.
5. Write or update each spec using the spec template below.
6. Update the PRD's `## Specs` section and set `Status: Specced`.

## Spec Template

```markdown
# [Module Name]

## What It Does
One paragraph.

## Why It Exists
One paragraph — design rationale.

## [Schema / Flow / State Machine]
Core model or behaviour. Diagram if helpful.

## Acceptance Criteria
- [Observable, testable outcome]
```

Specs are lean. Every acceptance criterion must map to at least one test.
Do not create tasks or write code.

## What Belongs in a Spec (and What Doesn't)

A spec is platform-agnostic. It describes **what** the system does and **what rules govern it** — not how any specific stack implements it.

| Belongs in spec | Belongs in platform override |
|---|---|
| Schema field names and types | Migration syntax, column constraints |
| State machine transitions | ActiveRecord callbacks, SQL triggers |
| Acceptance criteria | RSpec examples, test helpers |
| API contract (shape, status codes) | Rails routes, controller code |
| Behaviour rules | Gem choices, library usage |

Implementation specifics live in `specs/platform/{platform}/`. The plan loop reads the
spec first, then layers the matching platform override on top before producing beats.

