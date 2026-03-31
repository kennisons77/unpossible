# PRD: Task Manager

- **Status:** Draft
- **Created:** 2026-03-31
- **Last revised:** 2026-03-31

## Intent

The Task Manager is the execution layer between human intent (specs and PRDs) and the
loop. It owns task state, enforces dependency ordering, and gives the loop a queryable
API so it can discover and claim work autonomously rather than reading a flat file.

## Design Diagram

```
┌─────────────────┐         ┌─────────────────┐
│   Story         │         │  AgentProfile   │
│─────────────────│         │─────────────────│
│ id              │         │ id              │
│ title           │         │ name            │
│ item_type       │         │ provider        │
│ status          │         │ model           │
│ assignee_type   │         │ allowed_tools[] │
│ assignee_id     │         │ prompt_template │
└────────┬────────┘         └────────┬────────┘
         │ 1                         │ 1
         │                           │
         │ 1                         │ 0..1
┌────────┴────────────────────────────────────┐
│   Task                                      │
│─────────────────────────────────────────────│
│ id                                          │
│ story_id          FK → Story                │
│ agent_profile_id  FK → AgentProfile         │
│ title                                       │
│ description                                 │
│ status            pending|in_progress|      │
│                   complete|failed|blocked   │
│ loop_type         plan|build|review|...     │
│ task_ref          SHA256 of checkbox text   │
│ depends_on_ids[]  FK → Task[]               │
│ provider          override (nullable)       │
│ model             override (nullable)       │
│ prompt_template   override (nullable)       │
└─────────────────────────────────────────────┘
         │ syncs from
         │
┌────────┴────────┐
│  PlanFile       │
│─────────────────│
│ path            │  e.g. specs/system/tasks-plan.md
│ - [ ] item  ────┼──→ creates Task on sync
│ - [x] item  ────┼──→ marks Task complete
└─────────────────┘
```

**Key flows:**

```
prd-to-tasks skill
  └─→ POST /api/tasks          (creates Tasks directly, no PlanFile needed)

loop
  └─→ GET /api/tasks/next      (returns all unblocked pending tasks with descriptions)
  └─→ PATCH /api/tasks/:id     (updates status after completing work)
       └─→ Story.status sync   (synchronous)

PlanFile edit (human or loop)
  └─→ POST /api/tasks/sync     (upserts Tasks from file, orphans renamed items)

promote
  └─→ POST /api/tasks/:id/promote
       └─→ 422 if any depends_on task is not complete
```

## Personas

- **Solo developer (you):** creating tasks via PRD-to-tasks skill or editing plan files;
  needs confidence that the loop will pick up the right work in the right order
- **Future contributor:** onboarding to a project; needs to read task state without
  tribal knowledge of what the loop is doing
- **Loop agent:** discovering and claiming work autonomously; needs unambiguous next-task
  selection, clear dependency enforcement, and a reliable status update path

## User Scenarios

**Scenario 1 — PRD to running loop:**
You finish a PRD for a new feature and run `make prd-to-tasks`. The skill reads the PRD,
POSTs a set of tasks to the API with dependencies set, and confirms the list with you.
You run the loop. The loop calls `GET /api/tasks/next`, receives the unblocked tasks,
picks the first one, works on it, and PATCHes it complete. The next iteration picks the
next unblocked task. You watch the task list drain without touching a file.

**Scenario 2 — Plan file edit:**
Mid-feature, you realize a step was missed. You add `- [ ] Add rate limiting to ingest`
to the feature's plan file. On the next loop iteration, the loop calls
`POST /api/tasks/sync` with the file path. The new item becomes a task. The loop picks
it up in the normal next-task flow.

**Scenario 3 — Blocked task:**
Task B depends on Task A. Task A is `in_progress`. The loop tries to promote Task B.
The API returns 422 with a message listing Task A as the blocker. The loop logs the
block, picks a different unblocked task, and continues.

## User Stories

- As the loop, I want to query all unblocked pending tasks so I can choose what to work
  on next without reading a file.
- As the loop, I want to update task status via the API so the system reflects reality
  after each iteration.
- As a developer, I want to add a task by editing a plan file so I don't have to use
  the API directly for quick additions.
- As the prd-to-tasks skill, I want to create tasks with dependencies via the API so
  the loop executes them in the right order.
- As a developer, I want blocked tasks to surface their blockers clearly so I can
  diagnose stalled loops without reading the full task list.

## Success Metrics

| Goal | Metric |
|---|---|
| Loop picks correct next task | Loop never promotes a task whose dependencies are incomplete |
| Plan file sync is reliable | Zero duplicate tasks created from re-syncing an unchanged file |
| Status accuracy | Task status in DB matches loop reality within one iteration |
| API response time | `GET /api/tasks/next` responds in < 100ms under normal load |

## Functional Requirements

**MVP:**

- **Task CRUD** — `POST /api/tasks`, `GET /api/tasks`, `GET /api/tasks/:id`,
  `PATCH /api/tasks/:id`. All require authentication.
- **Next task endpoint** — `GET /api/tasks/next` returns all tasks where status is
  `pending` and all `depends_on` tasks are `complete`. Returns full task records
  including description and AgentProfile config.
- **Promote endpoint** — `POST /api/tasks/:id/promote` sets status to `in_progress`.
  Returns 422 with blocker list if any dependency is not `complete`.
- **Plan file sync** — `POST /api/tasks/sync` accepts a file path, parses `- [ ]` and
  `- [x]` checkboxes, upserts tasks keyed on `task_ref` (SHA256 of checkbox text).
  Checked items are marked `complete`. Items whose `task_ref` no longer exists in the
  file are flagged as orphaned in the response but not deleted.
- **Story sync** — task status changes propagate to the corresponding Story record
  synchronously. No spec file rewrite in Phase 0.
- **AgentProfile assignment** — a task may be assigned to an AgentProfile. The profile's
  provider, model, allowed_tools, and prompt_template are returned with the task in
  `GET /api/tasks/next`. Task-level overrides (provider, model, prompt_template) take
  precedence over the profile.
- **Dependency enforcement** — `depends_on_ids` is validated on create (all referenced
  IDs must exist). Promote is blocked if any dependency is not `complete`. Task creation
  is never blocked by dependency state.

**Post-MVP:**

- `GET /api/tasks/export` — generates a markdown snapshot of the task list (replaces
  `IMPLEMENTATION_PLAN.md` as a human-readable view)
- Spec file header rewrite on status change (callback from Story sync)
- Multi-agent parallelism (multiple loops claiming tasks concurrently)
- Task archival and history

## Features Out

- Spec file header rewrite — deferred to post-MVP; DB propagation only in Phase 0
- `IMPLEMENTATION_PLAN.md` export endpoint — post-MVP
- Multi-agent parallelism — post-MVP; Phase 0 assumes single loop
- Task deletion — orphaned tasks are flagged, not deleted; deletion is a future concern
- Webhook/event system for status changes — synchronous propagation only in Phase 0

## Designs

- Links to Wireframes/Mockups: _none yet_

## Open Questions

_None._

## Open Questions

| Question | Answer | Date |
|---|---|---|
| The plan loop currently writes `IMPLEMENTATION_PLAN.md` directly. In unpossible 2 it should call `POST /api/tasks/sync` instead. How does the plan loop know which feature's plan file to sync, and does it replace or merge with existing tasks? | TBD — resolve when speccing the loop runner | |

## Resolved

| Question | Answer | Date |
|---|---|---|
| Should `GET /api/tasks/next` return a single task or the full unblocked list? | Returns full unblocked list — loop decides which to work on | 2026-03-31 |
| How does the loop authenticate with the task API? | Shared secret via env var for now. Migrate to passwordless auth when that pattern is established project-wide | 2026-03-31 |
| Should orphaned tasks be auto-deleted after N days or require manual cleanup? | Orphaned tasks are surfaced as a pre-loop worklog check — the loop flags them before starting an iteration. Manual resolution required. Not auto-deleted | 2026-03-31 |
