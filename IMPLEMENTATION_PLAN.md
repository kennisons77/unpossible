
markdown
# Implementation Plan

Generated: 2026-04-16 (gap analysis refresh — reference-graph supersession)
Phase: 0 (Local Development — Docker Compose only)

> Scope: Phase 0 only. No CI, no k8s, no staging.
> **Execution order: top-down. Pick the FIRST unchecked item. Do not skip or reorder.**
> Tasks module is out of scope — no spec exists.
> `metadata.hypothesis` on FeatureFlag is NOT required in Phase 0 per the PRD.
> Go sidecar: fresh Go impl in `go/` with `cmd/parser/` and `cmd/analytics/`. No unpossible1 dependency.
> **Ledger + Knowledge modules are being removed** per `specs/system/reference-graph/spec.md`. Do not plan new ledger or knowledge work.
> **UI specs (analytics-dashboard-ui, agent-runs-ui, knowledge-browser-ui) are `proposed` status** — not planned until adopted.
> **Log tail relay is `proposed` status** with open questions — not planned until adopted.
> **Batch request middleware** — spec exists but is post-MVP for Phase 0 (no UI consumers yet).

---

[Prior sections completed: infra skeleton, Rails app, JWT auth, Ledger module (Node, NodeEdge, Actor, ActorProfile, NodeAuditEvent, NodeLifecycleService, NodesController, SpecWatcherJob, PlanFileSyncService, LedgerController + UI views), security (Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman), Ledger comment rewrite (9.1), Ledger test gaps (9.2–9.4), MarkdownHelper spec + fix (9.5), AUTH_SECRET env var extraction (8.1), Knowledge module (LibraryItem, MdChunker, EmbedderService, ContextRetriever, IndexerJob), Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, Kiro configs), Sandbox module (ContainerRun, DockerDispatcher), FeatureFlag model (11.1). 315 examples, 0 failures, 95.66% coverage. Tags through 0.0.36.]

---

## Section 11 — Feature Flags Controller

- [x] 11.2 — Feature flags API controller (`web/app/modules/analytics/controllers/feature_flags_controller.rb`, `web/config/routes.rb`)
  `POST /api/feature_flags` — create flag with key, org_id. Duplicate key → 422. `metadata.hypothesis` not required.
  `PATCH /api/feature_flags/:key` — update enabled field.
  `GET /api/feature_flags` — list active flags (archived excluded by default, `?status=archived` to include).
  JWT auth required on all endpoints.
  Ref: `specs/system/feature-flags/prd.md`, `specs/system/feature-flags/spec.md`
  Required tests (`web/spec/requests/analytics/feature_flags_spec.rb`):
  - POST with valid key → 201
  - POST with duplicate key → 422
  - POST without `metadata.hypothesis` → 201 (not 422)
  - PATCH sets enabled → 200
  - GET returns active flags, excludes archived
  - GET with `?status=archived` includes archived
  - Unauthenticated → 401

---

## Section 18 — Ledger + Knowledge Module Removal

> Per `specs/system/reference-graph/spec.md` §6. The ledger and knowledge modules are replaced by a file-and-git-native reference graph. Postgres is retained only for operational data (agents, analytics, sandbox).

- [x] 18.1 — Remove Ledger module code (`web/app/modules/ledger/` delete, `web/spec/` delete ledger specs/factories, `web/db/migrate/XXX_drop_ledger_tables.rb` new, `web/config/routes.rb`)
  Delete all Ledger models: Node, NodeEdge, NodeAuditEvent, Actor, ActorProfile, Project.
  Delete all Ledger services: TransitionService, VerdictService, NodeLifecycleService, NodeFactory, LedgerSnapshotService, PlanFileSyncService.
  Delete all Ledger controllers: NodesController, LedgerController.
  Delete all Ledger jobs: SpecWatcherJob.
  Delete all Ledger views: `web/app/views/ledger/`.
  Delete `web/app/modules/ledger.rb`.
  Write a migration to drop tables: nodes, node_edges, node_audit_events, actors, actor_profiles, projects.
  Remove ledger routes from `config/routes.rb`.
  Remove ledger factories: `ledger_nodes.rb`, `ledger_node_edges.rb`, `ledger_actors.rb`, `ledger_actor_profiles.rb`, `ledger_node_audit_events.rb`, `ledger_projects.rb`.
  Remove ledger specs: all files under `web/spec/models/ledger/`, `web/spec/requests/ledger/`, `web/spec/modules/ledger/`.
  Required tests: full suite passes with no ledger references; dropped tables do not exist in schema.

- [x] 18.2 — Remove Knowledge module code (`web/app/modules/knowledge/` delete, `web/spec/` delete knowledge specs/factories, `web/db/migrate/XXX_drop_knowledge_tables.rb` new)
  Delete all Knowledge models: LibraryItem.
  Delete all Knowledge services: MdChunker, EmbedderService, OpenAiEmbedder, ContextRetriever.
  Delete all Knowledge jobs: IndexerJob.
  Delete `web/app/modules/knowledge.rb`.
  Write a migration to drop tables: knowledge_library_items.
  Remove knowledge factories: `knowledge_library_items.rb`.
  Remove knowledge specs: all files under `web/spec/models/knowledge/`, `web/spec/modules/knowledge/`.
  Required tests: full suite passes with no knowledge references.

- [x] 18.3 — Update AgentRun to remove ledger FKs (`web/app/modules/agents/models/agent_run.rb`, `web/db/migrate/XXX_remove_ledger_fks_from_agent_runs.rb`, `web/spec/models/agents/agent_run_spec.rb`, `web/spec/factories/agents_agent_runs.rb`)
  Remove `node_id` (FK → Node) and `actor_id` (FK → Actor) columns from agents_agent_runs.
  Replace with `source_ref` (string, nullable) — a spec path or plan item ref that the reference parser can resolve.
  Update AgentRun model, factory, and specs.
  **Depends on:** 18.1
  Required tests: AgentRun valid without node_id/actor_id; source_ref is nullable string.

- [x] 18.5 — Remove BulkSnapshotService and ledger_snapshot initializer (`web/app/modules/agents/services/bulk_snapshot_service.rb` delete, `web/config/initializers/ledger_snapshot.rb` delete, `web/lib/tasks/ledger.rake` delete)
  BulkSnapshotService references `Ledger::ActorProfile`, `Ledger::Actor`, `Knowledge::LibraryItem` — all removed.
  `ledger_snapshot.rb` initializer references `Ledger::Node`, `Ledger::LedgerSnapshotService`, `Ledger::SpecWatcherJob` — all removed.
  `ledger.rake` references `Ledger::LedgerSnapshotService` — removed.
  Delete these files. Remove `bulk:export` and `bulk:import` rake tasks if defined in ledger.rake.
  **Depends on:** 18.1, 18.2
  Required tests: full suite passes; no references to deleted services remain.

- [x] 18.6 — Update Makefile for ledger removal (`Makefile`)
  Remove `ledger-export`, `ledger-import`, `ledger-seed`, `bulk-export`, `bulk-import` targets.
  Remove `bundle exec rake ledger:export bulk:export` from the `down` target.
  Remove ledger/bulk entries from help text.
  **Depends on:** 18.5
  Required tests: `make help` runs without errors; no references to removed rake tasks.

- [x] 18.4 — Clean up cross-module references (`web/app/modules/LOOKUP.md`, `specs/practices/LOOKUP.md`, `AGENTS.md`, `web/config/routes.rb`)
  Remove ledger and knowledge references from: LOOKUP.md files, AGENTS.md module table.
  Update `web/app/modules/LOOKUP.md` to remove knowledge and ledger entries.
  Update `specs/practices/LOOKUP.md` to remove ledger-specific entries and update `Agents::RunStorageService` → `Agents::PromptDeduplicator`.
  Remove `/session/new` stub route if no longer needed (was for ledger UI auth).
  **Depends on:** 18.1, 18.2, 18.3, 18.5
  Required tests: no dangling references to ledger or knowledge modules in LOOKUP files or routes.

- [x] 18.7 — Clean up specs and docs for ledger/knowledge removal
  Broad sweep of all spec, skill, practice, and root documentation files to remove stale ledger/knowledge references.
  **Depends on:** 18.1, 18.2
  Changes:
  **Delete or supersede:**
  - `specs/system/ledger/` (prd.md, spec.md, ui.md) — add `SUPERSEDED by specs/system/reference-graph/spec.md` header or delete.
  - `specs/system/knowledge/` (prd.md, spec.md) — same treatment.
  - `specs/system/knowledge-browser-ui.md` — delete (proposed UI for removed module).
  - `specs/platform/rails/system/knowledge.md` — delete. Remove row from `specs/platform/rails/system/README.md`.
  **Rewrite `specs/README.md`:**
  - Core Paradigm section: replace ledger/Node/NodeEdge model with reference graph (files + git + LEDGER.jsonl).
  - Conventions example: replace `system/ledger/` with `system/reference-graph/`.
  - System Specs table: replace ledger row with reference-graph, remove knowledge row.
  **Update system specs:**
  - `specs/system/agent-runner/spec.md` + `prd.md`: replace `actor_id`/`node_id` FKs with string refs, remove ActorProfile, replace "posts answer to ledger".
  - `specs/system/analytics/spec.md` + `prd.md`: `node_id` is a string ref (spec path or plan item ref), not "ledger node ID".
  - `specs/system/sandbox/prd.md`: replace "durable record lives in the ledger".
  - `specs/system/api/prd.md`: replace "posting a node to the ledger" example.
  - `specs/system/practices.md`: replace "indexed into the knowledge base" with file-based retrieval.
  - `specs/system/infrastructure/spec.md` + `prd.md`: remove Redis from Phase 0 compose layouts.
  - `specs/system/agent-runs-ui.md` + `specs/system/analytics-dashboard-ui.md`: remove LedgerController auth references.
  **Update skills:**
  - `specs/skills/README.md`: replace ActorProfile references with agent config (`.kiro/agents/`).
  - `specs/skills/loops/build.md`: replace `/api/nodes` with IMPLEMENTATION_PLAN.md, replace "knowledge base" with `specs/practices/`.
  - `specs/skills/loops/plan.md`: replace "knowledge base" loading, replace `POST /api/nodes`.
  - `specs/skills/workflows/review.md`: replace `POST /api/nodes`.
  - `specs/skills/workflows/server-ops.md`: remove `sidekiq` and `redis` from service list.
  - `specs/skills/tools/research.md`: remove `link_reference` knowledge base step.
  - `specs/skills/providers/claude.md`: replace "retrieved knowledge chunks".
  - `specs/skills/providers/kiro.md`: replace ActorProfile references.
  **Update practices:**
  - `specs/practices/structural-vocabulary.md`: replace module dependency graph example, remove NodeEdge reference.
  - `specs/practices/changeability.md`: replace `Node#closed?` and `TransitionService.call` examples.
  - `specs/practices/lookup-tables.md`: replace "see the ledger spec" example.
  - `specs/practices/coding.md`: replace `modules/knowledge/` example.
  **Update root docs:**
  - `README.md`: fix file structure tree (remove knowledge/, ledger/, Dockerfile.runner, Dockerfile.analytics; fix `app/` → `web/`). Update stack section.
  - `AGENTS.md`: remove Dockerfile.runner/analytics comment, fix module list (remove knowledge, tasks), remove ledger jobs row.
  - `specs/project-prd.md`: remove knowledge/ledger from module list, mark resolved open questions.
  Required tests: `grep -ri 'ledger\|knowledge\|ActorProfile\|NodeEdge' specs/ README.md AGENTS.md` returns only reference-graph spec and SUPERSEDED headers.

## Section 13 — Analytics Module (Rails Query Side)

> The Go analytics ingest sidecar (Section 16) is blocked on the Go runner spike. The Rails side — models, query API, audit logger — can proceed independently.
> `node_id` is a plain string column (spec path or plan item ref) — not a UUID FK. Ledger tables no longer exist.
> **Depends on:** Section 18 (ledger removal must complete first so analytics models use string refs from the start).

- [ ] 13.1 — Analytics::AnalyticsEvent model + migration (`web/app/modules/analytics/models/analytics_event.rb`, `web/db/migrate/XXX_create_analytics_events.rb`)
  Schema per `specs/system/analytics/spec.md`: id (UUID), org_id, distinct_id (string — opaque UUID), event_name (string), node_id (string, nullable, indexed — spec path or plan item ref), properties (jsonb), timestamp (timestamptz), received_at (timestamptz).
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

## Section 10 — API Documentation (rswag)

- [ ] 10.1 — Configure rswag and Swagger UI (`web/Gemfile`, `web/Gemfile.lock`, `web/vendor/cache/` rswag gems, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`, `web/config/routes.rb`, `web/swagger/v1/swagger.yaml`)
  Add rswag gems (`rswag-api`, `rswag-ui`, `rswag-specs`) to Gemfile. Download gems to vendor/cache. Create swagger_helper.rb, rswag initializer. Mount Swagger UI at `/api/docs` (unauthenticated).
  Ref: `specs/system/api/prd.md`, `specs/platform/rails/system/api-standards.md`
  Required tests:
  - `GET /api/docs` returns 200 without authentication
  - `rake rswag:specs:swaggerize` exits 0

- [ ] 10.2 — Convert existing request specs to rswag format (`web/spec/requests/api/auth_spec.rb`, `web/spec/requests/agents/agent_runs_spec.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`, `web/spec/requests/analytics/metrics_spec.rb`, `web/swagger/v1/swagger.yaml`)
  Convert all request specs to use rswag DSL so they contribute to the generated OpenAPI spec.
  **Depends on:** 10.1, 11.2, 13.5
  Required tests: all existing tests still pass; `rake rswag:specs:swaggerize` exits 0 and lists all endpoints.

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

## Section 20 — Reference Graph (Priority 1 — Controlled Commit Skill)

> Per `specs/system/reference-graph/spec.md`. The reference graph replaces the ledger with a file-and-git-native system. Priority 1 is the controlled commit skill.
> **Depends on:** Section 18 (ledger removal must complete first).

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

## Section 8 — Infrastructure Fixes

- [ ] 8.2 — Fix LOOKUP.md naming inconsistencies (`web/app/modules/LOOKUP.md`, `specs/practices/LOOKUP.md`)
  Update both LOOKUP.md files to match actual class names:
  - `Knowledge::RetrievalService` → `Knowledge::ContextRetriever`
  - `Sandbox::ContainerDispatchService` → `Sandbox::DockerDispatcher`
  - `Analytics::AuditLogService` → `Analytics::AuditLogger`
  - `Analytics::FeatureFlagService` → `Analytics::FeatureFlag` (model)
  - `Agents::RunStorageService` → `Agents::PromptDeduplicator` (in practices LOOKUP)
  - Remove `Tasks::TaskLifecycleService` reference (no spec exists)
  Note: partially superseded by 18.4 (ledger/knowledge entries removed there). This task covers the remaining naming fixes for agents, sandbox, analytics entries.
  Required tests: none (documentation only).

---

## Section 7 — Spikes

- [x] 7.3 — ~~[SPIKE] Multi-tenancy scope for Phase 0~~ **RESOLVED**
  Decision: **Not needed in Phase 0.** Hardcode `org_id = 1`. Analytics differentiates by project, not tenant. No org creation flow, no tenant scoping middleware. `org_id` columns stay for forward compatibility but are always `1`.

---

## Section 16 — Go Sidecars

> Fresh Go implementation in `go/` — no unpossible1 dependency.
> Single Go module with `cmd/parser/` (reference-graph parser) and `cmd/analytics/` (analytics ingest).
> One Dockerfile, entrypoint selects mode via command.

- [x] 16.0 — ~~[SPIKE] Go runner source decision~~ **RESOLVED**
  Decision: **Fresh Go impl in `go/` with `cmd/parser/` and `cmd/analytics/`.** Single Dockerfile, entrypoint selects mode. Parser reads git history + notes and maintains the reference graph. Analytics ingest is POST /capture → batch flush to Postgres. No unpossible1 dependency, no submodule.

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


Immediate (execute in order):

11.2 (FF controller) ── no blockers

18.1 (remove ledger) ──┬──→ 18.3 (update AgentRun FKs) ──┐
18.2 (remove knowledge) ┤                                  ├──→ 18.4 (cleanup refs)
                       └──→ 18.5 (remove BulkSnapshot) ──→ 18.6 (Makefile) ──┘
                       └──→ 18.7 (cleanup specs + docs)

13.1–13.3 (analytics models) ──→ 13.4 (AuditLogger) ──→ 13.5 (MetricsController)
 ↑ depends on 18.1+18.2 (ledger tables gone before analytics models created)

10.1 (rswag setup) ──→ 10.2 (rswag convert, depends on 11.2 + 13.5)

19.1 (health check middleware) ── no blockers

20.1 (SPIKE: LEDGER.jsonl) ──→ 20.1.1 (SPIKE: spec authoring) ──→ 20.2 (LEDGER.jsonl utility)
 ↑ depends on 18.1+18.2

8.2 (LOOKUP fix) ── no blockers (partially superseded by 18.4)

7.3 (SPIKE: multi-tenancy) ── ✅ RESOLVED
16.0 (SPIKE: Go runner source) ── ✅ RESOLVED ──→ 16.1, 16.2 ──→ 16.3

---

## Open Questions (require spikes before dependent work can proceed)

| Question | Spike | Blocks |
|---|---|---|
| LEDGER.jsonl schema: plan item renumbering, stable refs | 20.1 | 20.2 |

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
- Ledger UI polish — superseded by ledger removal (Section 18)
- Backfill from activity.md — post-MVP per the PRD
- Ideas.md sync — described in spec but post-MVP
- Auto-open bug on failed interaction — no implementation path in Phase 0
- Streaming output, network isolation, resource caps for sandbox — post-MVP
- CI enforcement, API versioning — post-MVP
- Batch request middleware (`specs/system/batch-requests.md`) — no UI consumers in Phase 0
- Analytics dashboard UI (`specs/system/analytics-dashboard-ui.md`) — proposed status, not adopted
- Agent runs UI (`specs/system/agent-runs-ui.md`) — proposed status, not adopted
- Knowledge browser UI (`specs/system/knowledge-browser-ui.md`) — proposed status, not adopted; knowledge module being removed
- Log tail relay (`specs/system/log-tail-relay.md`) — proposed status with open questions
- Reference graph priorities 2–7 (Go parser, spec tags, CI drift, web UI, LLM acceptance tests) — future planning pass after priority 1
- Entrypoint dispatch pattern (`specs/practices/entrypoint-dispatch.md`) — current entrypoint works for Phase 0; multi-mode dispatch is a Phase 1+ concern
