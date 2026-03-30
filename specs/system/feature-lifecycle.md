# Feature Lifecycle & Version Control

## What This Spec Covers

The full lifecycle of a feature from raw idea to shipped code and beyond: how ideas are captured, researched, specced, planned, built, flagged, and archived. Where each artefact lives (disk vs DB). How version control ties it together.

---

## Lifecycle Stages

```
idea → research → spec → task → in_progress → complete → archived
                                     ↓
                              feature_flag (if hypothesis-driven)
```

Each stage is a status transition. Nothing skips stages — an idea cannot become a task without a spec, a task cannot be marked complete without passing tests.

### Idea

Captured in `IDEAS.md` on disk. Human-authored. Fields: id, title, description, status, created_at, promoted_at.

Status values: `parked` → `ready` → `promoted`. Only `ready` ideas can be promoted. Promotion creates a spec file and updates `IDEAS.md` — both happen atomically in the same operation.

`IDEAS.md` is the source of truth for ideas. The DB mirrors it (parsed by a background job) for UI display and querying. The file is never replaced by the DB.

### Research

A research loop pass produces `specs/research/{feature}.md`. This is a prerequisite for writing a spec on any non-trivial feature. Simple tasks (config changes, dependency bumps) may skip research.

Research logs are append-only on disk. They are indexed into the knowledge base for future context retrieval.

### Spec

A spec file at `specs/{feature}.md`. Human-authored or agent-assisted (via research loop output). Defines: what the feature does, why it exists, acceptance criteria, open questions.

Specs are the source of truth for intent. They are never deleted — only archived (moved to `specs/archive/{feature}.md` with an archived_at header). Archiving a spec triggers the library item lifecycle (cascade/archive/reassign children in the knowledge base).

### Task

A task is a checkbox in `IMPLEMENTATION_PLAN.md` derived from a spec's acceptance criteria. Tasks are the agent's unit of work.

`IMPLEMENTATION_PLAN.md` is the source of truth for task state. The DB mirrors it. See "Disk vs DB" below for the full decision.

### Feature Flag

Some tasks are gated behind a feature flag — the code ships but the behaviour is off by default until the hypothesis is validated. See "Feature Flags" below.

### Archive

Completed features and superseded specs are archived, not deleted. Archive preserves the audit trail. The git history is the ultimate archive — a file deleted from disk is still in git.

---

## Disk vs DB — Decision Table

This is the most important design decision in this spec. The rule: **disk is source of truth for human-authored content; DB is the query layer for machine-generated or machine-consumed content.**

| Artefact | Source of truth | DB role | Rationale |
|---|---|---|---|
| `IDEAS.md` | Disk | Mirror (parsed on change) | Human-authored, git-tracked, readable without the app |
| `specs/*.md` | Disk | Indexed into knowledge base | Human-authored, LLM context source |
| `specs/research/*.md` | Disk | Indexed into knowledge base | Append-only research logs |
| `IMPLEMENTATION_PLAN.md` | Disk | Mirror (parsed after plan loop) | Agent writes it; humans read it; git tracks changes |
| Task records | DB (mirrored from disk) | Primary for agent orchestration | Agent needs provider/model/tools — not expressible in MD |
| AgentRun records | DB only | Primary | Machine-generated, no human value as flat files |
| AuditEvent records | DB only | Primary | Append-only compliance log |
| FeatureFlag records | DB only | Primary | Runtime state, changes without a deploy |
| LlmMetric records | DB only | Primary | Analytics data, no human value as flat files |

**The key tension:** `IMPLEMENTATION_PLAN.md` is on disk (so humans can read it and git tracks it) but the task schema in the DB is richer (provider, model, tools, reviewer). Resolution: the MD file is the human interface; the DB record is the machine interface. `PlanParserJob` syncs disk → DB after each plan loop. Manual DB overrides (provider, model) are preserved across re-parses.

**Never write DB-only state back to disk** unless it's explicitly a sync operation. The DB does not own the MD files.

---

## IMPLEMENTATION_PLAN.md Lifecycle

### Creation
Written by the plan loop agent. Format: markdown checkboxes grouped by phase/section. Each checkbox is one task.

### Updates
- Plan loop: rewrites the file (full regeneration or targeted updates)
- Build loop: checks off completed items (`- [ ]` → `- [x]`)
- Human: can edit directly — `PlanParserJob` will reconcile on next run

### Pruning
When the file exceeds ~50 items, the plan loop prunes completed items and prepends a summary line:
```
[Prior N tasks completed: brief description of key outcomes]
```
Pruned items are not deleted from git — they exist in history.

### DB sync
`Tasks::PlanParserJob` runs after every plan loop completion and after every build loop commit. It upserts task records keyed on `task_ref` (SHA256 of checkbox text). Manually set `provider`/`model` overrides are never overwritten.

### Regeneration
`IMPLEMENTATION_PLAN.md` is disposable state. Run `./loop.sh plan 1` to regenerate it entirely from specs. Do this when: the plan is stale, specs changed significantly, or the agent seems confused about what's complete.

---

## Task States

```
pending → in_progress → complete
                ↓
             failed → pending (retry)
                ↓
           blocked (RALPH_WAITING — needs human input)
```

State transitions are owned by the build loop and the Rails API. The MD file reflects the final state (`[ ]` / `[x]`). Intermediate states (in_progress, failed, blocked) exist only in the DB — they are not written back to the MD file.

**Blocked tasks** — when the agent outputs `RALPH_WAITING`, the task transitions to `blocked` in the DB. The loop pauses. When the human responds, the task returns to `in_progress`. This state is never written to `IMPLEMENTATION_PLAN.md` — it would confuse the next plan loop.

---

## Feature Flags

Feature flags gate hypothesis-driven features. The pattern:

1. Write the feature behind a flag check: `FeatureFlag.enabled?(org_id:, key: 'my_feature')`
2. Ship the code with the flag disabled
3. Enable for a subset (or just yourself) and measure
4. If the hypothesis is validated → remove the flag, make the behaviour default
5. If not → remove the code, archive the flag record

### Flag schema (Phase 0)

```
key         string, unique per org
enabled     boolean, default false
variant     string, nullable (for A/B)
metadata    jsonb (hypothesis, metric, owner)
```

The `metadata.hypothesis` field is required when creating a flag — no flag without a stated hypothesis. This enforces the pitch's "test hypotheses through feature flags" principle.

### Flag lifecycle

- `active` — enabled for evaluation
- `archived` — experiment concluded, flag no longer evaluated (returns default variant always)
- Never deleted — archived flags are the experiment record

`FeatureFlag.enabled?` returns `false` for archived flags without raising. Archived flags are excluded from the UI flag list by default but accessible via filter.

### Flag naming convention

`{module}.{feature}` — e.g. `knowledge.vector_search`, `agents.reviewer_pattern`, `analytics.cost_alerts`. Namespaced to prevent collisions as the system grows.

---

## Version Control Practices

### One commit per passing task

The build loop commits after each task passes tests. Never bundle multiple tasks into one commit. The commit message format:

```
{task title}

- {what changed}
- {why — the spec or acceptance criterion it satisfies}
```

The "why" is mandatory. A commit message that only describes what changed is incomplete.

### Branch per loop run

`loop.sh` creates a `ralph/{timestamp}` branch for each run on main/master. This means:
- Main is always green
- Each loop run is reviewable as a PR before merge
- Rollback is `git revert` on the branch, not on main

### Tags

After every green build that advances the project to a fully passing state, the build loop creates or increments a semver tag (`0.0.1`, `0.0.2`, ...). Tags are the deployable units.

### What goes in git

- All MD files: specs, research logs, IDEAS.md, IMPLEMENTATION_PLAN.md, practices, AGENTS.md
- All application code
- `Gemfile.lock` and `go.sum` — always committed, never gitignored
- Infra manifests (`infra/`)
- `.env.example` — committed; `.env` — never committed

### What does not go in git

- `.env` files
- `master.key` / credential keys
- DB dumps
- Log files
- Generated assets (`public/assets/`)

A committed `.env` or `master.key` is a CI failure (detected by `git-secrets` or `gitleaks` pre-commit hook).

---

## Acceptance Criteria

- `IDEAS.md` is the source of truth for ideas — DB mirrors it, never replaces it
- Promoting an idea creates `specs/{feature}.md` and updates `IDEAS.md` atomically
- `IMPLEMENTATION_PLAN.md` is regenerated by `./loop.sh plan 1` without data loss (DB overrides preserved)
- `PlanParserJob` is idempotent — running twice produces the same DB state
- Task `blocked` state exists only in DB — never written to `IMPLEMENTATION_PLAN.md`
- `FeatureFlag` requires `metadata.hypothesis` on creation — missing hypothesis returns 422
- Archived flags return `false` from `FeatureFlag.enabled?` without raising
- Build loop commits after each passing task with a message containing both what and why
- `ralph/{timestamp}` branch is created when loop runs on main
- Committed `.env` is detected and fails CI
- `Gemfile.lock` is committed — missing lock file fails CI
