# General Planning Practices

Loaded every plan iteration. Guides how to analyze specs and produce an implementation plan.

## Spec Granularity: Jobs to Be Done (JTBD)

Each spec file should cover exactly one **Topic of Concern** — a distinct capability or domain
within the project. Use the **One Sentence Without "And"** test:

- ✓ "The color extraction system analyzes images to identify dominant colors"
- ✗ "The user system handles authentication, profiles, and billing" → 3 topics, 3 spec files

If you can't describe a spec's scope in one sentence without "and", split it. Monolithic specs
produce monolithic tasks that can't fit cleanly in one loop iteration.

## Gap Analysis
- Read `app/**` before declaring anything missing — never assume unimplemented
- Compare against each spec file in `specs/` explicitly, item by item
- Flag `infra/Dockerfile` and `infra/docker-compose.yml` placeholder values as high-priority

## Task Structure
- Each task in `IMPLEMENTATION_PLAN.md` must be independently verifiable
- Tasks should be small enough to complete and test in one loop iteration
- Order by dependency — unblock other tasks first
- Distinguish clearly between "not started", "partially done", and "done but untested"

## Specs Integrity
- If specs contradict each other, resolve the conflict before planning implementation
- If a requirement is ambiguous, make the ambiguity explicit in `IMPLEMENTATION_PLAN.md`
- Never invent requirements — if something seems missing, flag it, don't add it silently

## IMPLEMENTATION_PLAN.md
- It is the agent's only memory across context windows — keep it current
- Remove completed items when the file grows large (>50 items)
- Each item should name the files it will touch, so future iterations can target searches
- The plan is disposable state — it is correct to regenerate it entirely when it's stale or wrong
