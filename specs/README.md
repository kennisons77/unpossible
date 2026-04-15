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
system/ledger/
  prd.md    intent, personas, scenarios, success metrics
  spec.md   data model, schema, behaviour, acceptance criteria
```

This is the new convention. Apply it to any subject as it matures from a spec-only file
into a fully specced module.

## Core Paradigm

Every artifact in the system — a pitch, a PRD, a spec, a beat, a commit, a bug, a form,
a deployment — is a **node** in the ledger: either a question or an answer.

- A **question** declares intent or poses a problem. It is open until an answer is accepted.
- An **answer** responds to a question. It is either terminal (work done) or generative
  (spawns child questions that must be resolved before the tree is complete).
- A **generative answer** is a shared understanding checkpoint — a PRD, a spec, a
  research finding. It requires co-acceptance before child questions open.

Nodes form a DAG via `NodeEdge` (contains / depends_on / refs). The ledger is the
ordered sequence of all nodes by `originated_at`. It is append-only.

See [`system/ledger/`](system/ledger/) for the full model.

## System Specs (`system/`)

Core platform capabilities — what the system does and how its modules behave.

| Spec | Module |
|---|---|
| [project-prd.md](project-prd.md) | All — technical constraints and phase |
| [system/ledger/](system/ledger/) | Universal data model — nodes, edges, questions, answers |
| [system/agent-runner/](system/agent-runner/) | AgentRun record, prompt assembly, dedup, sidecar, observability |
| [system/knowledge/](system/knowledge/) | Vector store, MD indexing, LLM response indexing, context retrieval |
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
