# Implementation Plan

Generated: 2026-04-16 (gap analysis refresh)
Phase: 0 (Local Development — Docker Compose only)

> Scope: Phase 0 only. No CI, no k8s, no staging.
> **Execution order: top-down. Pick the FIRST unchecked item. Do not skip or reorder.**
> Tasks module is out of scope — no spec exists.
> `metadata.hypothesis` on FeatureFlag is NOT required in Phase 0 per the PRD and base spec.
> Go sidecar: fresh Go impl in `go/` with `cmd/parser/` and `cmd/analytics/`. No unpossible1 dependency.
> **Ledger + Knowledge modules have been removed** per `specs/system/reference-graph/spec.md`.
> **UI specs (analytics-dashboard-ui, agent-runs-ui) are `proposed` status** — not planned until adopted.
> **Log tail relay is `proposed` status** with open questions — not planned until adopted.
> **Batch request middleware** — spec exists but is post-MVP for Phase 0 (no UI consumers yet).

---

[Prior sections completed: infra skeleton, Rails app, JWT auth, Ledger module (built then removed), Knowledge module (built then removed), security (Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman), Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, Kiro configs), Sandbox module (ContainerRun, DockerDispatcher), FeatureFlag model + controller (11.1, 11.2), Ledger+Knowledge removal (18.1–18.7). 137 examples, 0 failures, 98.48% coverage. Tags through 0.0.39.]

---

## Section 21 — Stale Reference Cleanup (High Priority)

> Ledger/knowledge removal (18.x) left stale references in infra and seed files that will cause runtime failures.

- [x] 21.1 — Fix entrypoint.sh stale ledger rake tasks (`infra/entrypoint.sh`)
  `entrypoint.sh` still runs `bundle exec rake ledger:import ledger:seed` — these rake tasks were deleted in 18.5. The dev stack will crash on startup.
  Remove the `ledger:import ledger:seed` line. Keep only `bundle exec rails db:create db:migrate db:seed`.
  Required tests: `docker compose up` starts without entrypoint errors (manual verification — sandbox limitation).

- [x] 21.2 — Fix seeds.rb stale Ledger::Project reference (`web/db/seeds.rb`)
  `seeds.rb` references `Ledger::Project` which no longer exists. `db:seed` will crash.
  Replace with a no-op or remove the seed entirely (no project table exists post-removal).
  Required tests: `bundle exec rails db:seed` exits 0 (verified via test suite setup).

- [x] 21.3 — Fix docker-compose.yml stale ledger volume mount (`infra/docker-compose.yml`)
  `docker-compose.yml` mounts `../ledger:/ledger` — the `ledger/` directory no longer exists. Docker Compose will error or create an empty directory.
  Remove the `- ../ledger:/ledger` volume mount line.
  Required tests: `docker compose config` exits 0 (manual verification — sandbox limitation).

- [x] 21.4 — Fix application.rb stale comments (`web/config/application.rb`)
  Comments reference `Knowledge::` and `Ledger::Node` namespaces. Cosmetic but misleading.
  Update comments to reference current modules (Agents, Sandbox, Analytics).
  Required tests: none (comment-only change).

- [x] 21.5 — Fix ApplicationController stale `new_session_path` reference (`web/app/controllers/application_controller.rb`)
  `authenticate_session!` calls `redirect_to new_session_path` but no `/session/new` route exists (removed in 18.4). This will raise `NoMethodError` if `authenticate_session!` is ever called.
  Remove `authenticate_session!` method entirely — no controller uses it, and no session UI exists in Phase 0.
  Required tests: full suite passes; no route or controller references `new_session_path`.

---

## Section 13 — Analytics Module (Rails Query Side)

> The Go analytics ingest sidecar (Section 16) is blocked on the Go runner spike. The Rails side — models, query API, audit logger — can proceed independently.
> `node_id` is a plain string column (spec path or plan item ref) — not a UUID FK.
> **Depends on:** Section 21 (stale references must be fixed first so seeds/entrypoint work).

- [x] 13.1 — Analytics::AnalyticsEvent model + migration (`web/app/modules/analytics/models/analytics_event.rb`, `web/db/migrate/XXX_create_analytics_events.rb`)
  Schema per `specs/system/analytics/spec.md`: id (UUID), org_id (UUID), distinct_id (string — opaque UUID), event_name (string), node_id (string, nullable, indexed — spec path or plan item ref), properties (jsonb), timestamp (timestamptz), received_at (timestamptz).
  Append-only: no update or destroy methods exposed.
  Index on `(org_id, event_name, timestamp)`.
  Ref: `specs/system/analytics/spec.md`, `specs/platform/rails/system/analytics.md`
  Required tests (`web/spec/models/analytics/analytics_event_spec.rb`):
  - Valid with required fields
  - No update method exposed
  - No destroy method exposed
  - `distinct_id` stored as UUID string
  - `node_id` accepts string values (not UUID FK)

- [ ] 13.2 — Analytics::AuditEvent model + migration (`web/app/modules/analytics/models/audit_event.rb`, `web/db/migrate/XXX_create_analytics_audit_events.rb`)
  Append-only. Severity enum: info, warning, critical. Separate from AnalyticsEvent.
  Index on `(org_id, created_at)`.
  Ref: `specs/platform/rails/system/analytics.md`
  Required tests (`web/spec/models/analytics/audit_event_spec.rb`):
  - Valid with required fields
  - Severity enum validates
  - No update or destroy methods exposed

- [ ] 13.3 — Analytics::LlmMetric model + migration (`web/app/modules/analytics/models/llm_metric.rb`, `web/db/migrate/XXX_create_analytics_llm_metrics.rb`)
  Per agent run: provider, model, input_tokens, output_tokens, cost_estimate_usd (decimal(10,6)), mode, node_id (string, nullable — spec path or plan item ref), duration_ms.
  Index on `(org_id, provider, model, created_at)`.
  Ref: `specs/platform/rails/system/analytics.md`
  Required tests (`web/spec/models/analytics/llm_metric_spec.rb`):
  - Valid with required fields
  - cost_estimate_usd stored as decimal(10,6)
  - `node_id` accepts string values (not UUID FK)

- [ ] 13.4 — Analytics::AuditLogger service + AuditLogJob (`web/app/modules/analytics/services/audit_logger.rb`, `web/app/modules/analytics/jobs/audit_log_job.rb`)
  `AuditLogger.log(...)` — async, fire-and-forget, never raises. Enqueues AuditLogJob on `analytics` queue.
  **Depends on:** 13.2
  Ref: `specs/platform/rails/system/analytics.md`
  Required tests (`web/spec/modules/analytics/services/audit_logger_spec.rb`):
  - `AuditLogger.log` enqueues AuditLogJob
  - `AuditLogger.log` does not raise on failure (logs to Rails logger instead)
  - AuditLogJob creates an AuditEvent record

- [ ] 13.5 — Analytics::MetricsController (query API) (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/config/routes.rb`)
  JWT auth required on all endpoints.
  `GET /api/analytics/llm` — cost/tokens by provider/model, filterable by date range.
  `GET /api/analytics/loops` — run counts, failure rates by mode.
  `GET /api/analytics/summary` — total cost this week, loop error rate.
  `GET /api/analytics/events` — paginated event list, filterable by event_name, org_id, date range.
  `GET /api/analytics/flags/:key` — exposure counts per variant (depends on 11.1).
  **Depends on:** 13.1, 13.3, 11.1
  Ref: `specs/system/analytics/spec.md`, `specs/platform/rails/system/analytics.md`
  Required tests (`web/spec/requests/analytics/metrics_spec.rb`):
  - GET /api/analytics/llm returns aggregated cost data → 200
  - GET /api/analytics/loops returns run counts → 200
  - GET /api/analytics/summary returns summary → 200
  - GET /api/analytics/events returns paginated events → 200
  - GET /api/analytics/flags/:key returns exposure counts → 200
  - Unauthenticated → 401 on all endpoints

---

## Section 19 — Health Check Middleware

> Per `specs/platform/rails/system/health-check.md`: Rack middleware at position 0, `GET /health` → 200/503, bypasses full stack. Currently only Rails default `GET /up` exists.

- [ ] 19.1 — HealthCheckMiddleware (`web/app/middleware/health_check_middleware.rb`, `web/config/application.rb`)
  Rack middleware inserted at position 0. Intercepts `GET /health`. Returns 200 (DB connected via `SELECT 1` with short timeout) or 503 (DB unreachable). Empty body. No auth, no tenant resolution, no logging. Must not raise.
  Ref: `specs/platform/rails/system/health-check.md`
  Required tests (`web/spec/middleware/health_check_middleware_spec.rb`):
  - `GET /health` returns 200 when DB is connected
  - `GET /health` returns 503 when DB is unreachable
  - Response body is empty
  - Non-health-check requests pass through to the app
  Required threat tests: health check endpoint does not leak DB connection details in response body.

---

## Section 10 — API Documentation (rswag)

- [ ] 10.1 — Configure rswag and Swagger UI (`web/Gemfile`, `web/Gemfile.lock`, `web/vendor/cache/` rswag gems, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`, `web/config/routes.rb`, `web/swagger/v1/swagger.yaml`)
  Add rswag gems (`rswag-api`, `rswag-ui`, `rswag-specs`) to Gemfile. Download gems to vendor/cache. Create swagger_helper.rb, rswag initializer. Mount Swagger UI at `/api/docs` (unauthenticated).
  Ref: `specs/system/api/prd.md`, `specs/platform/rails/system/api-standards.md`
  Required tests:
  - `GET /api/docs` returns 200 without authentication
  - `rake rswag:specs:swaggerize` exits 0

- [ ] 10.2 — Convert existing request specs to rswag format (`web/spec/requests/api/auth_spec.rb`, `web/spec/requests/agents/agent_runs_spec.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`, `web/spec/requests/analytics/metrics_spec.rb`, `web/swagger/v1/swagger.yaml`)
  Convert all request specs to use rswag DSL so they contribute to the generated OpenAPI spec.
  **Depends on:** 10.1, 13.5
  Required tests: all existing tests still pass; `rake rswag:specs:swaggerize` exits 0 and lists all endpoints.

---

## Section 20 — Reference Graph (Priority 1 — Controlled Commit Skill)

> Per `specs/system/reference-graph/spec.md`. The reference graph replaces the ledger with a file-and-git-native system. Priority 1 is the controlled commit skill.

- [ ] 20.1 — [SPIKE] Research LEDGER.jsonl schema and controlled commit skill design — run `./loop.sh research ledger-jsonl` (see `specs/skills/tools/research.md`)
  The reference-graph spec defines LEDGER.jsonl and a controlled commit skill. Key decisions already made:
  - Append-only, semver-like task IDs (never renumber — old IDs are superseded, not reused).
  - Component registry: `COMPONENTS.md` (human-readable) + `components.yaml` (machine-readable for Go parser). All refs use canonical component names.
  Remaining research: controlled commit skill design, event schema details, component registry bootstrap.
  Deliverable: written decision in `specs/research/ledger-jsonl.md`.

- [ ] 20.1.1 — [SPIKE] Spec authoring practice — how PRDs, specs, git history, git notes, LEDGER.jsonl, and the component registry relate as reference sources (`specs/practices/spec-authoring.md`)
  Define the contract: PRD = why/what (platform-agnostic), spec = how/done (may be platform-specific). Describe how each artifact type feeds the reference graph and how the Go parser indexes them. Must account for git notes as annotation layer and LEDGER.jsonl as event log.
  **Depends on:** 20.1
  Deliverable: `specs/practices/spec-authoring.md` — loadable by plan, build, and interview agents.

- [ ] 20.2 — LEDGER.jsonl append utility (`web/lib/ledger_jsonl.rb` or standalone script)
  Append-only JSONL writer. Event types: `status`, `blocked`, `unblocked`, `spec_changed`.
  Schema per `specs/system/reference-graph/spec.md` § File Schemas.
  **Depends on:** 20.1
  Required tests:
  - Appends valid JSON line to LEDGER.jsonl
  - Entries are never modified or deleted
  - Each event type produces correct schema
  - File is created if it doesn't exist

---

## Section 8 — Infrastructure & Documentation Fixes

- [ ] 8.2 — Fix LOOKUP.md naming inconsistencies (`web/app/modules/LOOKUP.md`, `specs/practices/LOOKUP.md`)
  Update both LOOKUP.md files to match actual class names and current state:
  - `specs/practices/LOOKUP.md`: references to entrypoint dispatch, batch requests, multi-tenancy, and health check middleware describe patterns that don't exist yet — mark as planned or remove
  - `specs/practices/LOOKUP.md`: `filter_parameters` list doesn't match `config/application.rb` — update to match actual config
  - `specs/practices/LOOKUP.md`: references `AuthorizationConcern` which doesn't exist — remove
  Required tests: none (documentation only).

- [ ] 8.3 — Fix Dockerfile.test missing `/specs/` path for LOOKUP.md spec (`infra/Dockerfile.test`)
  `module_scaffold_spec.rb` checks `Pathname.new('/specs/practices/LOOKUP.md').exist?` — this works because `Dockerfile.test` copies `specs/` to `/specs/`. Verify this path is stable. No code change expected — just verification.
  Required tests: `module_scaffold_spec.rb` passes in container.

---

## Section 16 — Go Sidecars

> Fresh Go implementation in `go/` — no unpossible1 dependency.
> Single Go module with `cmd/parser/` (reference-graph parser) and `cmd/analytics/` (analytics ingest).
> One Dockerfile, entrypoint selects mode via command.

- [ ] 16.1 — Go module skeleton + parser entrypoint (`go/cmd/parser/main.go`, `go/go.mod`, `infra/Dockerfile.go`, `infra/docker-compose.yml`)
  Create Go module at `go/`. Parser reads git history + notes and produces/updates the reference graph.
  `GET /healthz`.
  Required tests: `go test ./...` exits 0.

- [ ] 16.2 — Go analytics ingest entrypoint (`go/cmd/analytics/main.go`, `infra/docker-compose.yml`)
  `POST /capture` returns 202 immediately. In-memory queue, batch flush every 5s or 100 events. Buffers on Postgres unavailability. `GET /healthz`.
  Ref: `specs/system/analytics/spec.md`, `specs/system/analytics/prd.md`
  Required tests: `go test ./...` exits 0; POST /capture returns 202; events flushed within 5s; events buffered on Postgres unavailability; non-UUID distinct_id rejected.

- [ ] 16.3 — Wire FeatureFlag.enabled? to fire $feature_flag_called via analytics sidecar (`web/app/modules/analytics/models/feature_flag.rb`)
  **Depends on:** 16.2
  `FeatureFlag.enabled?` fires `$feature_flag_called` event to `POST /capture` on the analytics sidecar. No manual instrumentation at call sites.
  Ref: `specs/system/feature-flags/spec.md`
  Required tests:
  - `enabled?` sends `$feature_flag_called` event to analytics sidecar
  - Event includes flag_key, variant, enabled fields

---

## Dependency Graph

```
Immediate (execute in order):

21.1 (fix entrypoint.sh) ──→ 21.2 (fix seeds.rb) ──→ 21.3 (fix compose volume) ──→ 21.4 (fix comments) ──→ 21.5 (fix stale session path)

13.1–13.3 (analytics models) ──→ 13.4 (AuditLogger) ──→ 13.5 (MetricsController)
 ↑ depends on 21.x (stale refs fixed first)

19.1 (health check middleware) ── no blockers

10.1 (rswag setup) ──→ 10.2 (rswag convert, depends on 13.5)

20.1 (SPIKE: LEDGER.jsonl) ──→ 20.1.1 (SPIKE: spec authoring) ──→ 20.2 (LEDGER.jsonl utility)

8.2 (LOOKUP fix) ── no blockers
8.3 (Dockerfile.test verify) ── no blockers

16.1 (Go skeleton) ──→ 16.2 (Go analytics ingest) ──→ 16.3 (FF event wiring)
```

---

## Spec Contradictions (flagged, not resolved)

| Contradiction | Specs | Current implementation | Recommendation |
|---|---|---|---|
| `metadata.hypothesis` required on FeatureFlag creation | `specs/platform/rails/product/analytics.md` says 422 if missing | `specs/system/feature-flags/spec.md` + `prd.md` say optional in Phase 0 | Base spec + PRD are authoritative. Current implementation (optional) is correct. Platform override needs updating. |

---

## Open Questions (require spikes before dependent work can proceed)

| Question | Spike | Blocks |
|---|---|---|
| LEDGER.jsonl schema: controlled commit skill design, event schema details | 20.1 | 20.2 |

### Resolved

| Question | Decision |
|---|---|
| Go runner source: copy from unpossible1 or submodule? | **Fresh Go impl** in `go/` with `cmd/parser/` and `cmd/analytics/`. Single Dockerfile, entrypoint selects mode. No unpossible1 dependency. |
| Multi-tenancy scope: hardcoded org_id = 1 or org creation flow? | **Not needed in Phase 0.** Hardcode `org_id = 1`. Analytics differentiates by project, not tenant. |
| LEDGER.jsonl renumbering / stable refs | **Append-only, semver-like task IDs** (never renumber). Component registry: `COMPONENTS.md` + `components.yaml`. All refs use canonical component names. |
| Redis in Phase 0? | **No.** Solid Queue uses Postgres. Rack-attack uses in-memory store. |
| MinIO in Phase 0? | **No.** No blob storage needed. Everything in Postgres or filesystem. |

## Out of Scope

- Tasks module — scaffolded but no spec exists
- Backfill from activity.md — post-MVP per the PRD
- Ideas.md sync — described in spec but post-MVP
- Auto-open bug on failed interaction — no implementation path in Phase 0
- Streaming output, network isolation, resource caps for sandbox — post-MVP
- CI enforcement, API versioning — post-MVP
- Batch request middleware (`specs/system/batch-requests.md`) — no UI consumers in Phase 0
- Analytics dashboard UI (`specs/system/analytics-dashboard-ui.md`) — proposed status, not adopted
- Agent runs UI (`specs/system/agent-runs-ui.md`) — proposed status, not adopted
- Log tail relay (`specs/system/log-tail-relay.md`) — proposed status with open questions
- Reference graph priorities 2–7 (Go parser, spec tags, CI drift, web UI, LLM acceptance tests) — future planning pass after priority 1
- Entrypoint dispatch pattern (`specs/practices/entrypoint-dispatch.md`) — current entrypoint works for Phase 0; multi-mode dispatch is a Phase 1+ concern
- `infra/debs-debian/` directory — referenced by `Dockerfile` but present; host-level build dependency, not an in-repo concern for Phase 0
- Knowledge module — superseded by reference graph; all code removed
- Ledger module — superseded by reference graph; all code removed
