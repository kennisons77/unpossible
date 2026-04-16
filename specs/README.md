# Specs — Unpossible

One file per feature area. Each spec defines what the feature does, who it's for, and
its acceptance criteria. The implementation plan is derived from these specs — not the
other way around.

Platform-agnostic specs live here. Rails-specific implementation details live in
`platform/rails/`.

## Conventions

**Flat file** — a single `[subject].md` for subjects that have only a spec.

**Directory** — a `[subject]/` directory for subjects that have both a PRD and a spec.
A directory signals that the subject has been fully specced with intent + model:

```
system/reference-graph/
  spec.md   data model, schema, behaviour, acceptance criteria
```

This is the new convention. Apply it to any subject as it matures from a spec-only file
into a fully specced module.

## Core Paradigm

Every artifact in the system — a pitch, a PRD, a spec, a beat, a commit, a bug — is
tracked in the **reference graph**: a file-and-git-native system where specs live as
markdown files, events are appended to `LEDGER.jsonl`, and relationships are resolved
by the Go parser reading git history and notes.

- A **spec** declares intent or defines behaviour. It is the source of truth for what
  the system does.
- A **LEDGER.jsonl entry** records a status change, block, or spec change event.
  Append-only — entries are never modified or deleted.
- The **component registry** (`COMPONENTS.md` + `components.yaml`) maps canonical
  component names to their spec and implementation paths.

See [`system/reference-graph/`](system/reference-graph/) for the full model.

## System Specs (`system/`)

Core platform capabilities — what the system does and how its modules behave.

| Spec | Module |
|---|---|
| [project-prd.md](project-prd.md) | All — technical constraints and phase |
| [system/reference-graph/](system/reference-graph/) | Reference graph — files, git, LEDGER.jsonl, component registry |
| [system/agent-runner/](system/agent-runner/) | AgentRun record, prompt assembly, dedup, sidecar, observability |
| [system/sandbox/](system/sandbox/) | Container lifecycle, Docker dispatcher |
| [system/analytics/](system/analytics/) | LLM metrics, product events, feature flag exposures, audit log |
| [system/feature-flags/](system/feature-flags/) | Feature flag schema, hypothesis requirement, lifecycle |
| [system/batch-requests.md](system/batch-requests.md) | Batch request middleware — fan-out sub-requests in a single HTTP call |
| [system/practices.md](system/practices.md) | Practices files — what they are and when they load |

## Product Specs (`product/`)

User-facing capabilities — what users can do and why. Rails-specific implementation details
live in `platform/rails/product/`.

| Spec | Area |
|---|---|
| [platform/rails/product/auth.md](platform/rails/product/auth.md) | Authentication — user and internal service |
| [platform/rails/product/analytics.md](platform/rails/product/analytics.md) | Product events, feature flags, experiment infrastructure |

## Skills (`skills/`)

Instructions for agents. See [`skills/README.md`](skills/README.md).

| Kind | Location |
|---|---|
| Tools | `skills/tools/` |
| Workflows | `skills/workflows/` — includes `server-ops` |
| Loops | `skills/loops/` |
| Providers | `skills/providers/` |

## Practices (`practices/`)

Agent discipline rules. See [`practices/README.md`](practices/README.md).

## Platform Overrides (`platform/`)

Implementation details for a specific runtime. Each file extends a core spec — it does
not repeat it.

- `platform/rails/` — Rails 8 implementation
- `platform/go/` — Go sidecar implementation
