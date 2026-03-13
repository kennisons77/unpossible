# General Planning Practices

Loaded every plan iteration. Guides how to analyze specs and produce an implementation plan.

## Spec Granularity: Activities, Not Capabilities

Each spec file should cover exactly one **activity** — a verb in the user journey, not a system
capability. Use the **One Sentence Without "And"** test:

- ✓ "The user uploads a photo" → `upload-photo.md`
- ✗ "The image system handles upload, storage, and processing" → 3 specs

Activities are naturally scoped by user intent. Capability-named specs tend to grow unbounded.

If `specs/audience.md` exists, the activity names and their capability depths are defined there —
use them as the authoritative list of spec topics.

## SLC Release Scoping

If `specs/audience.md` exists and defines a **Current target release**, scope
`IMPLEMENTATION_PLAN.md` to that release only — not the full feature space.

A good release slice is:
- **Simple** — narrow enough to ship in a focused build loop
- **Lovable** — delivers real value to the target audience within its scope
- **Complete** — fully accomplishes a job; no broken preview states

Do not plan tasks for capability depths beyond the current target release. Tasks for future
releases belong in a future planning pass, not the current plan.

## Acceptance-Driven Task Definition

For each task, derive required tests from the acceptance criteria in the relevant spec:

- Acceptance criteria describe *what* to verify (observable outcomes)
- Required tests are the verification points derived from those criteria
- Include required tests in the task definition in `IMPLEMENTATION_PLAN.md`

Example task entry:
```
- [ ] Extract dominant colors from uploaded image (app/extract.py)
  Required tests: returns 5–10 colors, handles grayscale, handles single-color image, <100ms for <5MB
```

This prevents tasks from being marked done without the required verification existing and passing.

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
- The plan is disposable state — regenerate it entirely when it's stale or wrong
