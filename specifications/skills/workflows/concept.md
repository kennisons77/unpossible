---
name: concept
kind: workflow
command: make concept
description: Produce or update concept files for requirements
actor: default
runs: once
tools: [interview, analyse, research]
principles: [planning]
---

Produce concept files (broad behavioral definitions) for a subject. If concepts already
exist, gap-fill them.

## Steps

1. Locate the subject (ask if not provided). Read it fully. Identify the
   `## Specifications` section — the list of concept files this subject declares it
   needs. If absent, derive the list and confirm with user.
2. Check which concepts already exist. Show status table. Ask: "Does this look right?"
3. For each concept to write or revise, ask:
   - Does this need research first? (unfamiliar domain, unresolved open questions)
   - Is there an existing library or prior art to reference?
   - Which other nodes does this touch?
   - Are the acceptance criteria specific enough to derive tests from?
   If research is needed, stop and run the `research` tool first.
4. Run `analyse` on any existing concepts against the subject. Report gaps.
5. Write or update each concept using the concept template below.
6. Update the subject's `## Specifications` section and set `Status: Specced`.

## Concept Template

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

Concepts are lean. Every acceptance criterion must map to at least one test.
Do not create tasks or write code.

## What Belongs in a Concept (and What Doesn't)

A concept is platform-agnostic. It describes **what** the system does and **what rules
govern it** — not how any specific stack implements it.

| Belongs in concept | Belongs in platform override |
|---|---|
| Schema field names and types | Migration syntax, column constraints |
| State machine transitions | ActiveRecord callbacks, SQL triggers |
| Acceptance criteria | RSpec examples, test helpers |
| API contract (shape, status codes) | Rails routes, controller code |
| Behaviour rules | Gem choices, library usage |

Implementation specifics live in `specifications/platform/{platform}/`. The plan loop
reads the concept first, then layers the matching platform override on top before
producing beats.

