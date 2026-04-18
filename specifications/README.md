# Specifications — Unpossible

One file per feature area. Each concept defines what the feature does, who it's for, and
its acceptance criteria. The implementation plan is derived from these concepts — not the
other way around.

Platform-agnostic specifications live here. Rails-specific implementation details live in
`platform/rails/`.

## Hierarchy

```
brief        (ideology)       → why does this exist, who is it for
concept      (concept)        → what does it do, behavioral model, acceptance criteria
requirements (specification)  → precise technical translation, schema, implementation patterns
practices    (practice)       → patterns and conventions that apply
code + tests (code)           → implementation + executable specifications
```

The chain: `interview → concept → requirements → plan → build → review`

## Conventions

**Flat file** — a single `[subject].md` for subjects that have only a concept.

**Directory** — a `[subject]/` directory for subjects that have both a concept and
requirements. A directory signals that the subject has been fully specified with
intent + model:

```
system/reference-graph/
  concept.md        behavioral model, acceptance criteria
  requirements.md   precise technical translation (when needed)
```

Apply this to any subject as it matures from a concept-only file into a fully specified
module.

## Core Paradigm

Every artifact in the system — a brief, a concept, requirements, a beat, a commit, a
bug — is tracked in the **reference graph**: a file-and-git-native system where
specifications live as markdown files, events are appended to `LEDGER.jsonl`, and
relationships are resolved by the Go parser reading git history and notes.

- A **concept** declares intent or defines behaviour. It is the source of truth for what
  the system does.
- A **LEDGER.jsonl entry** records a status change, block, or spec change event.
  Append-only — entries are never modified or deleted.
- The **glossary** (`specifications/practices/glossary.md`) defines canonical tags that
  connect artifacts across the system.

See [`system/reference-graph/`](system/reference-graph/) for the full model.

## System Specifications (`system/`)

Core platform capabilities — what the system does and how its modules behave.

| Specification | Module |
|---|---|
| [project-requirements.md](project-requirements.md) | All — technical constraints and phase |
| [system/reference-graph/](system/reference-graph/) | Reference graph — files, git, LEDGER.jsonl |
| [system/agent-runner/](system/agent-runner/) | AgentRun record, prompt assembly, dedup, sidecar, observability |
| [system/sandbox/](system/sandbox/) | Container lifecycle, Docker dispatcher |
| [system/analytics/](system/analytics/) | LLM metrics, product events, feature flag exposures, audit log |
| [system/feature-flags/](system/feature-flags/) | Feature flag schema, hypothesis requirement, lifecycle |
| [system/batch-requests.md](system/batch-requests.md) | Batch request middleware — fan-out sub-requests in a single HTTP call |
| [system/practices.md](system/practices.md) | Practices files — what they are and when they load |

## Product Specifications (`product/`)

User-facing capabilities — what users can do and why. Rails-specific implementation details
live in `platform/rails/product/`.

| Specification | Area |
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

Implementation details for a specific runtime. Each file extends a core specification —
it does not repeat it.

- `platform/rails/` — Rails 8 implementation
- `platform/go/` — Go sidecar implementation
