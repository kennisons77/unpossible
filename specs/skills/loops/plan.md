---
name: plan
kind: loop
command: ./loop.sh plan [n]
description: Produce beats from specs until no open questions remain
actor: default
runs: until — no open unplanned questions in scope
tools: [analyse]
principles: [planning, cost]
---

Produce beats (executable questions, scope: code) from specs until the plan is complete.
Each iteration picks the highest-priority unplanned spec, runs `analyse` against the
codebase, and writes beats to the plan file.

A beat is the residue of PRD + spec + gap analysis in agreement. Do not write a beat
unless all three exist and are consistent.

## Each Iteration

1. Read `ACTIVE_PROJECT`. Read specs and PRD.
2. Read the platform override for the active stack — `specs/platform/{platform}/` —
   and layer it on top of the base spec. Platform overrides add implementation specifics
   (migration syntax, gem choices, test helpers) without changing the spec's intent.
3. Load `planning.md` and `verification.md` from the knowledge base. `cost.md` is always
   present. Do not load other practices — retrieve on demand if needed.
4. Run `analyse` — compare specs + platform override against codebase. Identify what's missing.
5. For any spec with unresolved open questions or unfamiliar domain: create a spike beat
   (`loop_type: research`) before any build beats that depend on it.
6. Write beats to the plan file as `- [ ]` checkboxes. Each beat must include:
   - Title derived from an acceptance criterion (not free-form)
   - `loop_type`
   - `depends_on` refs
7. POST beats to `/api/nodes` via plan file sync.
8. **Prune the plan file** — when `IMPLEMENTATION_PLAN.md` exceeds ~50 items, remove
   completed items and prepend a digest line:
   ```
   [Prior N beats completed: brief description of key outcomes]
   ```
   Pruned items are not deleted from git — they exist in history.
9. Log to `specs/activity.md`.
10. Output `RALPH_COMPLETE` when no open unplanned questions remain.

Spike beats block all build beats that depend on the spec they cover.
Plan only. Do not implement anything.
