---
name: write-a-prd
command: make write-a-prd
description: Turn a grilled idea into a PRD file with user stories
model: opus
loop_type: plan
principles: [planning]
---

Produce a Product Requirements Document from a spec. Follow these steps in order, skipping
any step already completed in the current conversation:

1. **Locate the spec** — ask the user which spec file to use, or accept it as an argument.
   Read it fully.
2. **Check for existing PRD** — look for a file named `[spec-name]-prd.md` co-located with
   the spec. If one exists, show the user its Status field and current sections, then ask:
   "This PRD already exists — are we revising it or starting fresh?" Do not proceed until
   confirmed.
3. **Explore the codebase** — verify any assertions in the spec against existing code. Note
   gaps or contradictions.
4. **Interview** — if shared understanding has not been reached, run the grill-me process
   before continuing.
5. **Sketch major modules** — identify the key components needed to fulfill the spec. Note
   integration points and unknowns.
6. **Write the PRD** — produce or update `[spec-name]-prd.md` using the template below.

## Design Diagram

Before writing the PRD, produce a text-based entity diagram showing the core data model
and key flows. Use box-drawing characters. Include:
- Entities with their key fields
- Relationships and cardinality (1, 0..1, [])
- Key API flows as indented arrows beneath the diagram

Present the diagram to the user and confirm it matches their mental model before
proceeding to write the PRD file.

## PRD Template

```markdown
# PRD: [Feature Name]

- **Status:** Draft
- **Created:** [date]
- **Last revised:** [date]

## Intent
One or two sentences. What this feature is and why it exists — written so an agent reading
this document cold understands the purpose without reading further.

## Personas
Who uses this feature and what they need from it. For internal unpossible features use the
defaults below; replace with grill-me output for client projects.

**Default personas:**
- **Solo developer (you):** building and iterating on unpossible projects; needs clarity and
  speed
- **Future contributor:** onboarding to an existing project; needs shared understanding
  without tribal knowledge
- **Loop agent:** executing tasks autonomously; needs unambiguous scope and explicit
  boundaries

## User Scenarios
Full stories describing how each persona uses the feature in context. Not bullet points —
narrative paragraphs that show the before, during, and after.

## User Stories
- As a [persona], I want [action] so that [outcome].

## Success Metrics
Measurable outcomes that indicate this feature is working. The agent should suggest
candidates based on the feature type if the author hasn't defined them yet.

| Goal | Metric |
|---|---|
| [goal] | [measurable indicator] |

## Functional Requirements
What the feature does. Describe inputs, processes, and expected outputs per capability.
Mark the MVP boundary explicitly — everything above the line ships first.

**MVP:**
- ...

**Post-MVP:**
- ...

## Features Out
What this PRD explicitly does not cover, and why. Be specific — vague exclusions get
ignored.

- ...

## Designs
Links to wireframes, mockups, or interaction specs. Placeholder until assets exist.

- Links to Wireframes/Mockups: _none yet_

## Specs
Spec files this PRD requires before the plan loop can run. Populated by `prd-to-specs`.

| Spec file | Description |
|---|---|
| | |

## Open Questions
Unresolved decisions that will affect implementation. Add entries freely — open questions
make it safe to start a PRD before everything is known. Resolve or defer each before
promoting Status to Approved.

| Question | Answer | Date |
|---|---|---|
| [question] | | |
```

Write the file to disk. Do not create any tasks or modify any other files.
