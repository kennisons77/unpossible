# PRD — Unpossible 2

## What We're Building

An evolving platform for AI-assisted software development. It runs ralph loops (plan, build, review, reflect) against projects, stores everything those loops produce, and uses that evidence to improve itself over time.

Unpossible 2 is both the platform and its own first project — it develops itself using its own loops.

## Technical Constraints

- Language: Ruby 3.3
- Framework: Rails 8 (full stack — not API-only; views needed for UI)
- Database: PostgreSQL 16 with pgvector extension
- Background jobs: Solid Queue
- Base image: ruby:3.3-slim
- Test command (in container): bundle exec rspec
- Port: 3000
- Sidecar: Go 1.22 runner (separate container, same pod)

## Phase

Phase 0 — Local development. Docker Compose only. No CI, no staging, no production config. See `specs/infrastructure.md` for the full phase model.

## Modularity

Monorepo with namespaced Rails modules. Each module owns its models, services, jobs, and controllers under `app/modules/{name}/`. Cross-module calls go through a public service interface only — no direct model access across module boundaries.

```
app/modules/
  knowledge/    # vector store, MD indexing, context retrieval
  tasks/        # task schema, plan parsing, tool set definitions
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
- Schema is graph-aware from day one: explicit `parent_id`, `source_id`, and relationship columns on all agent and knowledge models so traversal queries are possible without a schema migration
- Phase 0: plain Postgres relations — no graph extension
- Phase 3 candidate: Apache AGE (Postgres graph extension, openCypher) — add when traversal queries become painful in SQL. The data will already be graph-shaped; the migration is additive

## Open Questions

- Multi-tenancy scope for Phase 0: single-org (hardcoded org_id = 1) or org creation flow?
- MinIO: is it needed in Phase 0, and what is stored there?
- loop.sh location: `projects/unpossible2/loop.sh` or monorepo root?
- Go runner: copy from unpossible1 into `runner/` or reference as submodule?
