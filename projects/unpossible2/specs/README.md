# Specs — Unpossible 2

One file per feature area. Each spec defines what the feature does, who it's for, and its acceptance criteria. The implementation plan is derived from these specs — not the other way around.

Platform-agnostic specs live here. Rails-specific implementation details live in `platform/rails/`.

## System Specs (`system/`)

Core platform capabilities — what the system does and how its modules behave.

| Spec | Module |
|---|---|
| [prd.md](prd.md) | All — technical constraints and phase |
| [system/tasks.md](system/tasks.md) | Task schema, plan parsing, tool definitions |
| [system/stories.md](system/stories.md) | Story lifecycle, disk↔DB sync, audit log |
| [system/agents.md](system/agents.md) | Agent run lifecycle, prompt dedup, provider adapters |
| [system/knowledge.md](system/knowledge.md) | Vector store, MD indexing, context retrieval |
| [system/sandbox.md](system/sandbox.md) | Container lifecycle, Docker dispatcher |
| [system/analytics.md](system/analytics.md) | LLM metrics, infrastructure signal, audit log |
| [system/runner.md](system/runner.md) | Go sidecar — process executor |
| [system/loop.md](system/loop.md) | loop.sh, RALPH signals, prompt templates |
| [system/research-loop.md](system/research-loop.md) | Research loop — spec deepening before planning |
| [system/feature-lifecycle.md](system/feature-lifecycle.md) | Idea → spec → task → complete lifecycle |
| [system/infrastructure.md](system/infrastructure.md) | Phase model, Docker Compose, deployment |
| [system/api-standards.md](system/api-standards.md) | API documentation and request test standards |
| [system/security.md](system/security.md) | Secrets, PII, attack surface, incident response |
| [system/practices.md](system/practices.md) | Practices files — what they are and when they load |
| [system/lookup-tables.md](system/lookup-tables.md) | Canonical lookup tables used across modules |
| [system/server-operations.md](system/server-operations.md) | Server ops, deployment, rollback |

## Product Specs (`product/`)

User-facing capabilities — what users can do and why.

| Spec | Area |
|---|---|
| [product/auth.md](product/auth.md) | Authentication — user and internal service |
| [product/analytics.md](product/analytics.md) | Product events, feature flags, experiment infrastructure |
| [product/backpressure.md](product/backpressure.md) | Verification checks that gate task completion |

## Platform Overrides (`platform/`)

Implementation details for a specific runtime. Each file extends a core spec — it does not repeat it.

- `platform/rails/` — Rails 8 implementation
- `platform/go/` — Go sidecar implementation
