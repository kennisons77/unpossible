# IMPLEMENTATION PLAN — Unpossible

**Phase:** 0 (Local — Docker Compose only)
**Generated:** 2026-05-01
**Scope:** Phase 0 only. No CI, no staging, no k8s.

---

## Gap Analysis Summary

**What exists (confirmed from code):**
- Rails 8 app with full module structure (agents, sandbox, analytics)
- Auth: JWT (`AuthToken`), `Secret` value object, `ApplicationController#authenticate!`, sidecar token
- Agents module: `AgentRun`, `AgentRunTurn`, `AgentRunJob`, `RunStorageService`, `PromptDeduplicator`, `ProviderAdapter` + all three adapters (Claude, Kiro, OpenAI), `SkillLoader`, `ContextRetriever`, `EnrichmentRunner`, `TurnContentGcJob`
- Sandbox module: `ContainerRun`, `DockerDispatcher`
- Analytics module: `AnalyticsEvent`, `AuditEvent`, `LlmMetric`, `FeatureFlag`, `AuditLogger`, `AuditLogJob`, `MetricsController`, `FeatureFlagsController`
- Middleware: `HealthCheckMiddleware`, `BatchRequestMiddleware`
- rswag: `swagger/v1/swagger.yaml`, request specs for all controllers
- Go runner sidecar: `go/cmd/runner/main.go` + tests (no `go.mod` at root, no `go/cmd/analytics`)
- Infra: `infra/Dockerfile`, `infra/Dockerfile.test`, `infra/Dockerfile.agent`, `infra/docker-compose.yml`, `infra/docker-compose.test.yml`
- `loop.sh`, `Makefile`, `LEDGER.jsonl`, `PROMPT_*.md` files

**Key gaps found:**
1. `go/go.mod` and `go/go.sum` missing — Go runner cannot build
2. `infra/Dockerfile.go` missing — Go sidecars cannot be containerised
3. `go/cmd/analytics/main.go` missing — analytics ingest sidecar not implemented
4. `docker-compose.yml` references `infra/Dockerfile.go` for `go_runner` — build will fail
5. `analytics_events` table missing `received_at` default; `distinct_id` UUID validation not enforced in Rails
6. `FeatureFlag.enabled?` class method not implemented (spec requires it; only instance method exists)
7. `FeatureFlag` `metadata.hypothesis` validation: spec says required on creation → 422 (platform/rails/product/analytics.md); feature-flags concept says optional in Phase 0 — **contradiction flagged below**
8. `MetricsController` crosses module boundary: reads `Agents::AgentRun` directly — violates cross-module access rule
9. `AgentRun` missing unique index on `(run_id, iteration)` — spec requires it; schema has unique on `run_id` only (no `iteration` column)
10. `run_id` unique index exists but spec says `(run_id, iteration)` — schema has no `iteration` column; spec may be stale (concept says `run_id` UUID, no iteration)
11. `swagger/v1/swagger.yaml` missing `/api/feature_flags` endpoints (GET, POST, PATCH)
12. `swagger/v1/swagger.yaml` missing `/api/batch` endpoint
13. `swagger/v1/swagger.yaml` missing `/health` endpoint (present but not in swagger)
14. `run-tests.sh` referenced in `Dockerfile.agent` but not found in repo
15. `RUNNER_PASSWORD` required by runner but not set in `docker-compose.yml` env (only in `.env`)
16. `go_runner` in `docker-compose.yml` has both a commented-out stub and a real definition — the commented stub has a typo (`go_runner:f`) and should be cleaned up
17. `analytics` service missing from `docker-compose.yml` (analytics sidecar not yet built)
18. `AgentRunTurn` unique index on `(agent_run_id, position)` exists in schema ✓
19. `FeatureFlagExposure` model/table missing (spec: `analytics_feature_flag_exposures`)
20. `LlmMetric` missing `mode` column (spec: `GET /api/analytics/llm` filterable by mode)
21. `run_tests.sh` script missing from repo (referenced in `Dockerfile.agent`)

**Spec contradiction:**
- `specifications/system/feature-flags/requirements.md` § Features Out: "metadata.hypothesis enforcement (optional, not required)"
- `specifications/platform/rails/product/analytics.md` § Rails-specific Acceptance Criteria: "FeatureFlag with missing metadata.hypothesis → 422"
- **Resolution:** The platform override is more specific and more recent. Treat hypothesis as required on creation per the Rails platform spec. Flag for human review.

---

## Open Questions

| # | Question | Impact |
|---|---|---|
| 1 | `FeatureFlag.metadata.hypothesis` required or optional? Platform spec says required (422), system spec says optional. | Blocks task 4.1 |
| 2 | `AgentRun` schema: spec says unique on `(run_id, iteration)` but no `iteration` column exists. Is `iteration` a planned column or a spec artifact? | Informational — schema looks correct as-is |
| 3 | `run-tests.sh` referenced in `Dockerfile.agent` — what should it contain? | Blocks task 6.1 |

---

## Tasks

### Section 1 — Go Module Foundation (blocks all Go tasks)

- [x] 1.1 — Add `go/go.mod` and `go/go.sum` for the Go module (`go/cmd/runner`, `go/cmd/analytics`) (`go/go.mod`, `go/go.sum`)
  Required tests: `go build ./...` exits 0; `go test ./...` exits 0 for runner

### Section 2 — Go Analytics Sidecar (blocks docker-compose.yml analytics service)

- [x] 2.1 — [SPIKE] Research Go analytics ingest sidecar design — run `./loop.sh research 2.1` (see specifications/skills/tools/research.md)
  Covers: `go/cmd/analytics/main.go` design, in-memory queue, batch flush, PII filtering, UUID validation, Postgres write path. Blocks 2.2.

- [x] 2.2 — Implement `go/cmd/analytics/main.go` — analytics ingest sidecar (`go/cmd/analytics/main.go`) [blocked by 2.1]
  Required tests (from `specifications/platform/go/system/analytics.md`):
  - `go test ./...` exits 0
  - `POST /capture` returns 202 immediately
  - Events flushed within 5s or 100 events (whichever first)
  - Events buffered in memory on Postgres unavailability — no events dropped
  - `GET /healthz` returns 200
  - Non-UUID `distinct_id` rejected before storage

### Section 3 — Go Dockerfile and Compose Wiring (blocks full stack)

- [x] 3.1 — Create `infra/Dockerfile.go` multi-stage build for runner and analytics binaries (`infra/Dockerfile.go`) [blocked by 1.1]
  Required tests:
  - `docker compose -f infra/docker-compose.yml build go_runner` exits 0
  - `docker compose -f infra/docker-compose.yml build analytics` exits 0 (after analytics service added)

- [ ] 3.2 — Fix `docker-compose.yml`: remove commented-out stub (`go_runner:f` typo), add `analytics` service (port 9100), set `RUNNER_PASSWORD` env var, wire `analytics` service to postgres (`infra/docker-compose.yml`) [blocked by 3.1, 2.2]
  Required tests:
  - `docker compose -f infra/docker-compose.yml config` exits 0 (no YAML errors)
  - `docker compose -f infra/docker-compose.yml up` starts all services; rails responds on port 3000
  - Postgres not bound to 0.0.0.0
  - Image tags use git SHA, not `latest`

### Section 4 — Analytics Module Gaps

- [ ] 4.1 — Implement `FeatureFlag.enabled?(org_id:, key:)` class method; resolve hypothesis validation contradiction (`web/app/modules/analytics/models/feature_flag.rb`, `web/spec/models/analytics/feature_flag_spec.rb`)
  Required tests (from `specifications/system/feature-flags/concept.md` + `specifications/platform/rails/product/analytics.md`):
  - `FeatureFlag.enabled?` returns `false` for unknown flag without raising
  - `FeatureFlag.enabled?` returns `false` for archived flag without raising
  - `FeatureFlag.enabled?` returns `true` for active enabled flag
  - `FeatureFlag` with missing `metadata.hypothesis` → 422 on creation (per Rails platform spec)
  - Archived `FeatureFlag` returns false from `enabled?` without raising
  - `distinct_id` in API responses is UUID, never email

- [ ] 4.2 — Add `FeatureFlagExposure` model and migration (`web/app/modules/analytics/models/feature_flag_exposure.rb`, `web/db/migrate/YYYYMMDD_create_analytics_feature_flag_exposures.rb`)
  Required tests (from `specifications/platform/rails/product/analytics.md`):
  - `feature_flag_exposures` table has index on `(org_id, flag_key, distinct_id)`
  - Model validates presence of `org_id`, `flag_key`, `distinct_id`

- [ ] 4.3 — Add `mode` column to `analytics_llm_metrics` table; update `LlmMetric` model and `RunStorageService#complete` to populate it (`web/db/migrate/YYYYMMDD_add_mode_to_analytics_llm_metrics.rb`, `web/app/modules/analytics/models/llm_metric.rb`, `web/app/modules/agents/services/run_storage_service.rb`)
  Required tests:
  - `LlmMetric` records include `mode` from the associated `AgentRun`
  - `GET /api/analytics/llm?mode=build` filters by mode

- [ ] 4.4 — Fix cross-module boundary violation: `MetricsController#loops` reads `Agents::AgentRun` directly; extract a public service interface or query object in the agents module (`web/app/modules/agents/services/loop_stats_query.rb`, `web/app/modules/analytics/controllers/metrics_controller.rb`)
  Required tests:
  - `MetricsController` does not reference `Agents::AgentRun` directly
  - `GET /api/analytics/loops` still returns correct data

### Section 5 — API Documentation Gaps

- [ ] 5.1 — Add rswag request specs and swagger entries for `FeatureFlagsController` (GET index, POST create, PATCH update) (`web/spec/requests/analytics/feature_flags_spec.rb`, `web/swagger/v1/swagger.yaml`)
  Required tests (from `specifications/platform/rails/system/api-standards.md`):
  - `GET /api/feature_flags` returns 200 with active flags; 401 unauthenticated
  - `POST /api/feature_flags` returns 201 on success; 422 on duplicate key; 422 on missing hypothesis; 401 unauthenticated
  - `PATCH /api/feature_flags/:key` returns 200 on success; 404 not found; 401 unauthenticated
  - `rake rswag:specs:swaggerize` exits 0 after changes

- [ ] 5.2 — Add rswag entry for `POST /api/batch` to `swagger/v1/swagger.yaml` (`web/spec/requests/batch_spec.rb`, `web/swagger/v1/swagger.yaml`)
  Required tests:
  - `GET /api/docs` lists `/api/batch` endpoint
  - `rake rswag:specs:swaggerize` exits 0

### Section 6 — Agent Dockerfile Fix

- [ ] 6.1 — Create `infra/run-tests.sh` script (referenced in `Dockerfile.agent` but missing from repo) (`infra/run-tests.sh`)
  Required tests:
  - `docker compose -f infra/docker-compose.yml build agent` exits 0
  - `run-tests` script delegates to runner sidecar `POST /test` endpoint

### Section 7 — Infra Acceptance Criteria Verification

- [ ] 7.1 — Verify Phase 0 infra acceptance criteria: `docker compose up` starts all services; rails responds on port 3000; test suite passes in container (`infra/docker-compose.yml`, `infra/docker-compose.test.yml`)
  Required tests (from `specifications/system/infrastructure/concept.md`):
  - `docker compose -f infra/docker-compose.yml up` → rails responds on port 3000
  - `docker compose -f infra/docker-compose.test.yml run --rm test` → `bundle exec rspec` exits 0
  - Postgres not bound to 0.0.0.0
  - Image tags use git SHA, not `latest`
  - `infra/k8s/` and `infra/nixos/` do not exist

### Section 8 — Reference Graph (Spike — unfamiliar domain)

- [ ] 8.1 — [SPIKE] Research reference graph implementation — run `./loop.sh research 8.1` (see specifications/skills/tools/research.md)
  Covers: `specifications/system/reference-graph/concept.md` — controlled commit skill, Go reference parser, LEDGER.jsonl schema, spec reference tags in tests, CI drift detection. Blocks 8.2–8.6.

- [ ] 8.2 — Implement controlled commit skill (shell script or Ruby rake task) that atomically commits code + appends LEDGER.jsonl + updates IMPLEMENTATION_PLAN.md (`scripts/commit.sh` or `lib/tasks/commit.rake`) [blocked by 8.1]
  Required tests (from `specifications/system/reference-graph/concept.md`):
  - Controlled commit atomically stages code + LEDGER.jsonl + IMPLEMENTATION_PLAN.md in one git commit
  - LEDGER.jsonl is append-only — entries never modified or deleted
  - If commit fails, nothing is recorded

- [ ] 8.3 — Implement Go reference parser CLI (`go/cmd/parser/main.go`) [blocked by 8.1, 1.1]
  Required tests:
  - `go test ./...` exits 0
  - Parser produces JSON graph from files + git + LEDGER.jsonl
  - Parser is deterministic — same inputs always produce same output
  - Parser runs as standalone binary with no runtime dependencies
  - `spec:` tags in RSpec files parsed and appear as edges
  - `blocked-by` references in plan items parsed as dependency edges
  - PR nodes emitted with edges to commits, tasks, spec sections

- [ ] 8.4 — Add `spec:` metadata tags to existing RSpec files for key spec sections (`web/spec/`) [blocked by 8.1]
  Required tests:
  - At least one RSpec file per module has `spec:` tag linking to its spec section
  - Reference parser resolves these tags as edges in the graph

- [ ] 8.5 — Implement read-only web UI for reference graph (current/open/condensed views) (`web/app/controllers/`, `web/app/views/`) [blocked by 8.3]
  Required tests (from `specifications/system/reference-graph/concept.md`):
  - Current view renders in-progress beat and ancestor chain
  - Open view lists all non-done plan items, filterable by status
  - Condensed view renders full project tree with text search

- [ ] 8.6 — CI drift detection step (Phase 0: rake task that compares spec content hashes) (`lib/tasks/drift_check.rake`) [blocked by 8.1]
  Required tests:
  - Rake task flags spec sections that changed since linked tests last passed
  - Does not fail the build — surfaces drift for review

### Section 9 — Agent Runs UI

- [ ] 9.1 — [SPIKE] Research agent-runs UI design — run `./loop.sh research 9.1` (see specifications/skills/tools/research.md)
  Covers: `specifications/system/agent-runs-ui.md` — what views are needed, Rails view conventions. Blocks 9.2.

- [ ] 9.2 — Implement agent runs UI (server-rendered views) [blocked by 9.1]
  Required tests (from `specifications/system/agent-runs-ui.md`):
  - Agent runs list view renders
  - Agent run detail view shows turns
  - Human input form submits to `POST /api/agent_runs/:id/input`

### Section 10 — Analytics Dashboard UI

- [ ] 10.1 — [SPIKE] Research analytics dashboard UI design — run `./loop.sh research 10.1` (see specifications/skills/tools/research.md)
  Covers: `specifications/system/analytics-dashboard-ui.md`. Blocks 10.2.

- [ ] 10.2 — Implement analytics dashboard UI (server-rendered views) [blocked by 10.1]
  Required tests (from `specifications/system/analytics-dashboard-ui.md`):
  - Dashboard renders LLM cost summary
  - Dashboard renders loop run counts and failure rates

### Section 11 — Coverage Floor

- [ ] 11.1 — Verify SimpleCov coverage floor ≥ 85% across all modules (`web/spec/spec_helper.rb` or `web/spec/rails_helper.rb`)
  Required tests:
  - `bundle exec rspec` exits 0 with coverage ≥ 85%
  - Any `# :nocov:` exclusions have explanatory comments

---

## Dependency Order

```
1.1 → 3.1 → 3.2
1.1 → 8.3
2.1 → 2.2 → 3.2
3.1 → 3.2
4.1 (independent)
4.2 (independent)
4.3 (independent)
4.4 (independent)
5.1 (independent — spec already exists, needs update)
5.2 (independent)
6.1 (independent)
7.1 → depends on 3.2 for full stack
8.1 → 8.2, 8.3, 8.4, 8.6
8.3 → 8.5
9.1 → 9.2
10.1 → 10.2
11.1 (independent — run after all other tasks)
```

## Recommended Build Order

1. **1.1** — Go module foundation (unblocks everything Go)
2. **4.1, 4.2, 4.3, 4.4** — Analytics gaps (independent, high value)
3. **5.1, 5.2** — Swagger gaps (independent, required for API completeness)
4. **6.1** — run-tests.sh (quick fix, unblocks agent image build)
5. **2.1** (spike) → **2.2** — Analytics sidecar
6. **3.1** → **3.2** — Go Dockerfile + compose wiring
7. **7.1** — Full stack verification
8. **8.1** (spike) → **8.2, 8.3, 8.4, 8.6** — Reference graph
9. **9.1** (spike) → **9.2** — Agent runs UI
10. **10.1** (spike) → **10.2** — Analytics dashboard UI
11. **8.5** — Reference graph web UI (after parser)
12. **11.1** — Coverage floor verification
