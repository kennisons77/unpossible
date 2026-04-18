# General Planning Practices

Loaded every plan iteration. Guides how to analyze specs and produce an implementation plan.

## Spec Granularity: Activities, Not Capabilities

Each spec file should cover exactly one **activity** — a verb in the user journey, not a system
capability. Use the **One Sentence Without "And"** test:

- ✓ "The user uploads a photo" → `upload-photo.md`
- ✗ "The image system handles upload, storage, and processing" → 3 specs

Activities are naturally scoped by user intent. Capability-named specs tend to grow unbounded.

If `projects/<name>/specifications/audience.md` exists, the activity names and their capability depths are defined there —
use them as the authoritative list of spec topics.

## SLC Release Scoping

If `projects/<name>/specifications/audience.md` exists and defines a **Current target release**, scope
`projects/<name>/IMPLEMENTATION_PLAN.md` to that release only — not the full feature space.

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

For tasks that touch trust boundaries, also derive threat-informed test scenarios per
`threat-modeling.md` and include them as required threat tests.

## Gap Analysis
- Read `projects/<name>/src/` before declaring anything missing — never assume unimplemented
- Compare against each spec file in `projects/<name>/specifications/` explicitly, item by item
- Flag `projects/<name>/infra/Dockerfile` and `projects/<name>/infra/docker-compose.yml` placeholder values as high-priority

## Task Structure
- Each task in `IMPLEMENTATION_PLAN.md` must be independently verifiable
- Tasks should be small enough to complete and test in one loop iteration
- Order by dependency — unblock other tasks first
- Distinguish clearly between "not started", "partially done", and "done but untested"

## Specs Integrity
- If specs contradict each other, resolve the conflict before planning implementation
- If a requirement is ambiguous, make the ambiguity explicit in `IMPLEMENTATION_PLAN.md`
- Never invent requirements — if something seems missing, flag it, don't add it silently

## Superseding Specs

A new spec can invalidate existing plan tasks. When a spec declares that a module or
feature is being removed, replaced, or fundamentally redesigned:

- Mark affected unchecked tasks as out of scope with a one-line reason
- Add new tasks derived from the superseding spec in the correct dependency order
- Update the plan's scope notes to prevent future iterations from re-planning removed work
- Reorder if the new tasks must precede existing ones (e.g., removal before new code
  that would depend on the removed module)

The planner must check for contradictions between existing plan tasks and current specs
each iteration — not only look for unplanned specs. A plan task that references a module
marked for removal is stale and must be replaced, not executed.

## Development Phases

New projects advance through phases. Each phase must be stable before the next begins.
The current phase is recorded in `specifications/project-requirements.md` under `## Phase`. Default to Phase 0 for new projects.

| Phase | Name | Infrastructure | Goal |
|---|---|---|---|
| 0 | Local | `docker-compose up`, `docker-compose run test` | App runs and tests pass on dev machine |
| 1 | CI | GitHub Actions (or equivalent) | Tests run automatically on every push |
| 2 | Staging | Remote deploy (platform-specific) | App reachable at a non-production URL |
| 3 | Production | Multi-env, secrets mgmt, monitoring | Production-ready, security hardened |

**Phase rules:**
- Plan tasks only for the current phase. Future-phase infrastructure (k8s, secrets managers, staging pipelines) must not appear in the implementation plan until that phase is active.
- To advance a phase, add a task: `[ ] Advance to Phase N` — it requires the previous phase's acceptance criteria to all be passing.
- When planning Phase 0, the only infra files needed are `infra/Dockerfile` and `infra/docker-compose.yml`.
- When planning Phase 1, add CI config (e.g. `.github/workflows/ci.yml`). Do not add deploy jobs yet.
- When planning Phase 2, add a deploy workflow and a staging environment. Do not add production config yet.
- When planning Phase 3, add production config, secrets management, and security hardening.

## IMPLEMENTATION_PLAN.md
- It is the agent's only memory across context windows — keep it current
- Each item should name the files it will touch, so future iterations can target searches

## Plan Freshness

IMPLEMENTATION_PLAN.md is **regenerated from scratch** on every planning loop.
The planning loop deletes the file before writing a new one. The source of truth
is the code and specs, not the plan — a stale plan is worse than no plan.

- **Planning loops:** Delete IMPLEMENTATION_PLAN.md, gap-analyze specs vs code, write a fresh plan.
  Completed work is discovered from code and git state, not carried forward from the old plan.
- **Build loops:** Check off tasks and log findings to `activity.md`. Never add sections or
  restructure the plan. If a build loop discovers missing work, it logs the finding for the
  next planning loop to pick up.
- **Staleness guard:** Before writing the plan, diff what the plan would say against what
  actually exists in `web/` and `go/`. Flag any task whose artifacts already exist (skip it)
  or any completed-looking code that has no spec coverage (add a task).
