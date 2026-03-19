# Specs Directory

This directory contains the specifications that drive the Ralph loop. The planning agent reads
these files every iteration to understand what to build and verify what exists.

## Files

### `pitch.md` — The main idea of the project
Lays out the initial vision and goals for the project. It is intended as a starting point of the project and will be refined as the project progresses. It should also serve as a reference for the project team. If this document changes throughout the project, it should be updated accordingly.

### `audience.md` — Audience & Jobs to Be Done
Fill this in first, before running the loop. Defines who you're building for, what outcomes they
want (JTBDs), what activities they perform, and how those activities map to SLC releases. The
planning agent uses this to scope each IMPLEMENTATION_PLAN.md to one coherent, shippable slice
rather than the entire feature space.

### `prd.md` — Product Requirements Document
Defines the technical constraints: language, framework, base Docker image, test command, port.
The agent reads this to configure `infra/Dockerfile` and `infra/docker-compose.yml`.

### `plan.md` — High-Level Task Checklist
A human-authored checklist used as a starting point. The agent reads this during planning but
maintains `IMPLEMENTATION_PLAN.md` (at the repo root) as its live working state.

### `activity.md` — Activity Log
Appended by the agent after each iteration. Provides continuity between context windows — the
agent's short-term memory across loops.

### `testing.md` — Testing Strategy
Describes the testing approach for this project. Agent reads this before running tests.

### Per-activity specs (e.g. `upload-photo.md`, `extract-colors.md`)
One spec file per activity from `audience.md`. Activities are verbs in the user journey, not
system capabilities:

- ✓ `upload-photo.md` — "upload photo" is one user action
- ✗ `image-system.md` — "image system" bundles upload, storage, and processing

Each spec describes:
- What the user does and why
- Acceptance criteria (observable outcomes, not implementation details)
- Capability depths (basic → enhanced → advanced)

The acceptance criteria in each spec become the test requirements the planning agent derives
tasks from.

## How Specs Drive the Loop

```
audience.md          →  planning agent determines next SLC slice
specs/*.md           →  planning agent derives tasks + required tests
IMPLEMENTATION_PLAN.md  →  build agent picks next task, implements, commits
activity.md          →  agent appends summary after each iteration
```

## Writing Good Acceptance Criteria

Specs should describe **what to verify** (outcomes), not **how to implement** (approach).

| ✓ Good — behavioral outcome | ✗ Bad — implementation detail |
|---|---|
| "Extracts 5–10 dominant colors from any uploaded image" | "Use K-means clustering with LAB color space" |
| "Processes images under 5MB in under 100ms" | "Cache results in Redis with 5 min TTL" |
| "Handles grayscale, single-color, and transparent images" | "Check image mode before processing" |

Ralph decides *how* to implement. You decide *what success looks like*.
