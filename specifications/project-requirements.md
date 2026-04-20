---
name: project-requirements
kind: requirements
status: active
description: Technical constraints, stack choices, and phase model for the whole project
modules: []
---

# Requirements — Unpossible

## What We're Building

An evolving platform for AI-assisted software development. It runs ralph loops (plan, build, review, reflect) against projects, stores everything those loops produce, and uses that evidence to improve itself over time.

Unpossible is both the platform and its own first project — it develops itself using its own loops.

## Technical Constraints

- Language: Ruby 3.3
- Framework: Rails 8 (full stack — not API-only; views needed for UI)
- Database: PostgreSQL 16 with pgvector extension
- Background jobs: Solid Queue
- Base image: ruby:3.3-slim
- Test command (in container): bundle exec rspec
- Port: 3000
- Go: Go 1.22 binaries under `go/` (single go.mod) — runner sidecar, analytics ingest sidecar, reference-graph parser CLI

## Phase

Phase 0 — Local development. Docker Compose only. No CI, no staging, no production config. See `specifications/infrastructure.md` for the full phase model.

## Modularity

Monorepo with namespaced Rails modules. Each module owns its models, services, jobs, and controllers under `app/modules/{name}/`. Cross-module calls go through a public service interface only — no direct model access across module boundaries.

```
app/modules/
  agents/       # agent run storage, prompt dedup, JWT auth
  sandbox/      # container lifecycle, Docker dispatcher
  analytics/    # LLM metrics, audit log, feature flags
```

## Security Constraints

- All API keys wrapped in `Secret` value object — redacts in inspect/to_s/logs
- filter_parameters includes :api_key, :token, :password, :secret
- Secrets never passed to LLMs or written to logs
- Audit log is append-only and separate from application logs

## Data Storage

- Primary store: PostgreSQL 16 with pgvector extension (vector similarity search)
- Schema is graph-aware from day one: explicit `parent_id`, `source_id`, and relationship columns on all agent models so traversal queries are possible without a schema migration
- Phase 0: plain Postgres relations — no graph extension
- Phase 3 candidate: Apache AGE (Postgres graph extension, openCypher) — add when traversal queries become painful in SQL. The data will already be graph-shaped; the migration is additive

## Open Questions

- loop.sh location: project root `./loop.sh`

## Future Phase Considerations

### Health Checks (Phase 3)

When production infrastructure is added, define a component-level health check system:
- Classify components as **critical** (database — unhealthy stops traffic) vs
  **non-critical** (LLM provider — degraded but functional)
- Single `/health` endpoint returns per-component status with latency
- Load balancers use HTTP status code only (200 = healthy/degraded, 503 = unhealthy)
- Each component check has an independent timeout to prevent slow checks blocking the response

### Configuration Layering (Phase 2+)

Evolve from flat `ENV.fetch` to a layered configuration system with clear precedence:
CLI args > environment variables > workspace config > defaults. Use a library rather
than hand-rolling — the layering, validation, and type coercion are solved problems.
