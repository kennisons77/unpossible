# Audience & Jobs to Be Done

Fill this in during Phase 1 (before running the loop). The planning agent reads it to scope each
release to a coherent SLC slice rather than planning the entire feature space at once.

## Audiences

Describe who this is built for. There may be more than one connected audience.

| Audience | Role / context |
|---|---|
| [e.g., Designer] | [Creates mood boards for client presentations] |
| [e.g., Client] | [Reviews and approves designer's work] |

## Jobs to Be Done

For each audience, what outcome do they want? JTBDs are high-level — they describe *why* someone
uses the product, not what features it has.

**[Audience 1]:**
- JTBD: [e.g., "Quickly extract a color palette from reference images so I can present cohesive options to clients"]
- JTBD: [e.g., "..."]

**[Audience 2]:**
- JTBD: [e.g., "Review and give feedback on design work without needing design tools"]

## Activities

For each JTBD, what do users *do* to accomplish it? Activities are verbs — steps in a journey,
not system capabilities. Each activity becomes one spec file in `specs/`.

| Activity | JTBD it serves | Capability depths |
|---|---|---|
| [e.g., upload photo] | [Extract palette] | basic → bulk → batch |
| [e.g., see extracted colors] | [Extract palette] | auto → palette → AI themes |
| [e.g., arrange layout] | [Present to client] | manual → templates → auto-layout |
| [e.g., share result] | [Present to client] | export → collab → embed |

## Story Map

Arrange activities as columns (the journey backbone) with capability depths as rows. This is the
full space of what *could* be built — release slices are horizontal cuts through it.

```
[ACTIVITY 1] → [ACTIVITY 2] → [ACTIVITY 3] → [ACTIVITY 4]

basic            auto            manual           export
enhanced         palette         templates        collab
advanced         AI themes       auto-layout      embed
```

## Release Plan

Define named SLC releases as horizontal slices. Each release must be:
- **Simple** — narrow scope, shippable fast
- **Lovable** — people actually want to use it within its scope
- **Complete** — fully accomplishes a job; not a broken preview

| Release | Activity 1 | Activity 2 | Activity 3 | Activity 4 | Value delivered |
|---|---|---|---|---|---|
| [Name] | basic | auto | — | export | [One sentence] |
| [Name] | — | palette | manual | — | [One sentence] |
| [Name] | batch | AI themes | templates | embed | [One sentence] |

**Current target release:** [Name] — [one sentence describing what this release makes possible]
