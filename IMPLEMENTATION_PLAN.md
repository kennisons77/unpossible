# IMPLEMENTATION_PLAN.md

**Phase:** 0 — Local (Docker Compose only)
**Generated:** 2026-04-16
**Scope:** Phase 0 tasks only. No CI, no k8s, no staging, no production config.

---

## Completed Work (discovered from code + git)

The following is implemented and tested (137+ examples, 0 failures, 98.48% coverage):

- **Auth:** `Secret`, `AuthToken` (JWT HS256), `ApplicationController#authenticate!`, sidecar token auth, `POST /api/auth/token`, rack-attack rate limiting
- **Security:** `Security::PromptSanitizer`, `Security::LogRedactor`, lograge integration, `filter_parameters`
- **Agents module:** `AgentRun` model (modes, statuses, source_ref string, source_node_ids jsonb), `AgentRunTurn` model (kinds, purged_at), `RunStorageService` (start/complete/input, dedup, concurrency), `PromptDeduplicator`, `ProviderAdapter` registry (Claude/Kiro/OpenAi), `AgentRunsController` (start/complete/input endpoints)
- **Sandbox module:** `ContainerRun` model, `DockerDispatcher` (timeout, secret filtering, argument array)
- **Analytics module:** `FeatureFlag` model + `enabled?` + controller (CRUD, index with archived filter), `AnalyticsEvent` model (append-only, UUID PK, node_id string, properties jsonb)
- **Ledger/Knowledge removal:** All ledger and knowledge tables dropped, FK references replaced with string refs
- **Infrastructure:** `Dockerfile` (ruby:3.3-slim, non-root), `Dockerfile.test`, `docker-compose.yml` (rails + postgres), `docker-compose.test.yml`, entrypoints

---

## Section 1 — Infrastructure Gaps

### 1.1 docker-compose.yml: Postgres port binding check
**Spec:** `specs/system/infrastructure/spec.md` — "Postgres and Redis ports are not bound to 0.0.0.0 in any compose file"
**Status:** Postgres has no `ports:` mapping in either compose file — ✅ compliant. No task needed.

### 1.2 docker-compose.yml: Image tags use git SHA
**Spec:** `specs/system/infrastructure/spec.md` — "Image tags in compose files use git SHA, not `latest`"
**Status:** Rails image uses `${GIT_SHA:-dev}` — compliant for Phase 0 (dev fallback is acceptable locally). No task needed.

### 1.3 docker-compose.yml: Go sidecar services are commented out
**Spec:** `specs/system/infrastructure/spec.md` — compose file should include `go_runner` (port 8080) and `analytics` sidecar (port 9100)
**Finding:** Both services are commented out in `docker-compose.yml`. The Go sidecars themselves don't exist yet (no `go/` directory). This is tracked in Section 7 (Go sidecars).

---

## Section 2 — Health Check Middleware

**Spec:** `specs/platform/rails/system/health-check.md`
**Finding:** Currently uses Rails 8 default `GET /up` via `rails/health#show`. Spec requires a custom Rack middleware at position 0 that intercepts `GET /health`, checks DB with `SELECT 1`, returns 200/503 with empty body, and bypasses all other middleware.

- [ ] 2.1 — Implement `HealthCheckMiddleware` as Rack middleware at position 0 (`web/app/middleware/health_check_middleware.rb`, `web/config/application.rb`)
  Required tests: `GET /health` returns 200 when DB is up, returns 503 when DB is down, response body is empty, no auth required, middleware runs before all other middleware
  Files: `web/app/middleware/health_check_middleware.rb`, `web/config/application.rb`, `web/spec/middleware/health_check_middleware_spec.rb`

---

## Section 3 — Analytics Module Gaps

### Analytics Query API

**Spec:** `specs/system/analytics/spec.md`, `specs/platform/rails/system/analytics.md`
**Finding:** No `Analytics::MetricsController` exists. No `Analytics::AuditEvent` model. No `Analytics::LlmMetric` model. No `Analytics::AuditLogger` service. The spec requires query endpoints and supporting models.

- [ ] 3.1 — Create `Analytics::AuditEvent` model (append-only, severity enum: info/warning/critical) (`web/app/modules/analytics/models/audit_event.rb`, `web/db/migrate/..._create_analytics_audit_events.rb`)
  Required tests: validations (org_id, event_name, severity required), append-only enforcement (update/destroy raise), severity enum validates inclusion, index on (org_id, created_at)
  Files: `web/app/modules/analytics/models/audit_event.rb`, `web/db/migrate/..._create_analytics_audit_events.rb`, `web/spec/models/analytics/audit_event_spec.rb`, `web/spec/factories/analytics_audit_events.rb`

- [ ] 3.2 — Create `Analytics::LlmMetric` model (per agent run cost/token record) (`web/app/modules/analytics/models/llm_metric.rb`, `web/db/migrate/..._create_analytics_llm_metrics.rb`)
  Required tests: validations (org_id, provider, model required), cost_estimate_usd decimal(10,6), index on (org_id, provider, model, created_at), FK to agent_run optional
  Files: `web/app/modules/analytics/models/llm_metric.rb`, `web/db/migrate/..._create_analytics_llm_metrics.rb`, `web/spec/models/analytics/llm_metric_spec.rb`, `web/spec/factories/analytics_llm_metrics.rb`

- [ ] 3.3 — Create `Analytics::AuditLogger` service (async, fire-and-forget, never raises) (`web/app/modules/analytics/services/audit_logger.rb`, `web/app/modules/analytics/jobs/audit_log_job.rb`)
  Required tests: `AuditLogger.log(...)` enqueues job on analytics queue, failure logs to Rails logger and does not raise, job creates AuditEvent record
  Files: `web/app/modules/analytics/services/audit_logger.rb`, `web/app/modules/analytics/jobs/audit_log_job.rb`, `web/spec/modules/analytics/services/audit_logger_spec.rb`

- [ ] 3.4 — Create `Analytics::MetricsController` with query endpoints (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/config/routes.rb`)
  Required tests: `GET /api/analytics/llm` returns cost by provider/model filterable by date, `GET /api/analytics/loops` returns run counts/failure rates by mode, `GET /api/analytics/summary` returns total cost/runs/failure rate, `GET /api/analytics/events` returns paginated events filterable by event_name/org_id/date, `GET /api/analytics/flags/:key` returns exposure counts per variant, all endpoints return 401 without auth
  Depends on: 3.1, 3.2
  Files: `web/app/modules/analytics/controllers/metrics_controller.rb`, `web/config/routes.rb`, `web/spec/requests/analytics/metrics_spec.rb`

### AuditLogger integration with AgentRunsController

**Spec:** `specs/platform/rails/system/agents.md` — "Complete endpoint calls `Analytics::AuditLogger`"
**Finding:** `AgentRunsController#complete` does not call `AuditLogger`.

- [ ] 3.5 — Wire `Analytics::AuditLogger` call into `AgentRunsController#complete` (`web/app/modules/agents/controllers/agent_runs_controller.rb`)
  Required tests: completing an agent run creates an audit event via AuditLogger
  Depends on: 3.3
  Files: `web/app/modules/agents/controllers/agent_runs_controller.rb`, `web/spec/requests/agents/agent_runs_spec.rb`

---

## Section 4 — Feature Flag Gaps

### FeatureFlag exposure event

**Spec:** `specs/system/feature-flags/spec.md`, `specs/system/analytics/spec.md` — "Feature flag evaluation automatically fires `$feature_flag_called`"
**Finding:** `FeatureFlag.enabled?` does not fire any analytics event. The spec requires automatic `$feature_flag_called` event on every evaluation.

- [ ] 4.1 — Add automatic `$feature_flag_called` event firing in `FeatureFlag.enabled?` via analytics ingest (`web/app/modules/analytics/models/feature_flag.rb`)
  Required tests: calling `FeatureFlag.enabled?` creates/enqueues a `$feature_flag_called` event with flag_key, variant, enabled fields; no manual instrumentation at call sites
  Depends on: Go analytics sidecar (7.1) for production path, but can fire via direct DB insert or job for Phase 0
  Files: `web/app/modules/analytics/models/feature_flag.rb`, `web/spec/models/analytics/feature_flag_spec.rb`

### FeatureFlag metadata.hypothesis validation

**Spec:** `specs/platform/rails/product/analytics.md` — "FeatureFlag with missing `metadata.hypothesis` → 422"
**Finding:** Current model spec explicitly tests that flags are valid *without* hypothesis. The platform override says hypothesis is required. **Contradiction:** The base spec (`specs/system/feature-flags/spec.md`) says "`metadata.hypothesis` is optional in Phase 0." The platform override (`specs/platform/rails/product/analytics.md`) says "required on creation → 422 if missing."

- [ ] 4.2 — Resolve `metadata.hypothesis` requirement contradiction and implement the decided behavior (`web/app/modules/analytics/models/feature_flag.rb`, `web/app/modules/analytics/controllers/feature_flags_controller.rb`)
  Required tests: depends on resolution — either validate hypothesis presence on create (422 if missing) or confirm optional behavior
  Files: `web/app/modules/analytics/models/feature_flag.rb`, `web/spec/models/analytics/feature_flag_spec.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`

---

## Section 5 — Agent Runner Gaps

### Turn Content GC Job

**Spec:** `specs/system/agent-runner/spec.md` — "A background job purges turn content for completed runs older than N days"
**Finding:** No GC job exists. `purged_at` column exists on `agents_agent_run_turns` but no job sets it.

- [ ] 5.1 — Create `Agents::TurnContentGcJob` (solid_queue recurring) (`web/app/modules/agents/jobs/turn_content_gc_job.rb`, `web/config/recurring.yml`)
  Required tests: sets `purged_at` and clears content on completed runs older than 30 days, never purges failed or waiting_for_input runs, idempotent (running twice produces same result), turn record itself is retained
  Files: `web/app/modules/agents/jobs/turn_content_gc_job.rb`, `web/config/recurring.yml`, `web/spec/modules/agents/jobs/turn_content_gc_job_spec.rb`

### Agent question turn + waiting_for_input status

**Spec:** `specs/system/agent-runner/spec.md` — "Agent question appends `agent_question` turn and sets status `waiting_for_input`"
**Finding:** `RunStorageService` has `record_input` (for human input) but no method to record an agent question and set status to `waiting_for_input`. The controller has no endpoint for this (it would be called by the runner job, not an HTTP endpoint).

- [ ] 5.2 — Add `RunStorageService.record_question` method to append `agent_question` turn and set status to `waiting_for_input` (`web/app/modules/agents/services/run_storage_service.rb`)
  Required tests: creates agent_question turn with correct position, sets run status to waiting_for_input, content is preserved
  Files: `web/app/modules/agents/services/run_storage_service.rb`, `web/spec/modules/agents/services/run_storage_service_spec.rb`

### Provider adapter: build_prompt signature mismatch

**Spec:** `specs/system/agent-runner/spec.md` — Provider adapter `build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)`
**Finding:** Current adapters implement `build_prompt(messages)` — a simplified signature. The spec requires a richer interface with token budget and pinned+sliding trimming. This is a structural gap but the current implementation is functional for Phase 0 basic usage.

- [ ] 5.3 — Update `ProviderAdapter#build_prompt` signature to match spec (node:, context_chunks:, principles:, turns:, token_budget:) and implement pinned+sliding trimming (`web/app/modules/agents/services/provider_adapter.rb`, `web/app/modules/agents/services/claude_adapter.rb`, `web/app/modules/agents/services/kiro_adapter.rb`, `web/app/modules/agents/services/open_ai_adapter.rb`)
  Required tests: always includes system prompt + agent_question + human_input turns, trims oldest llm_response and tool_result turns first, aborts with error if still over budget after trimming all non-pinned turns
  Files: `web/app/modules/agents/services/provider_adapter.rb`, `web/app/modules/agents/services/claude_adapter.rb`, `web/app/modules/agents/services/kiro_adapter.rb`, `web/app/modules/agents/services/open_ai_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`

---

## Section 6 — API Documentation (rswag)

**Spec:** `specs/system/api/spec.md`, `specs/platform/rails/system/api-standards.md`
**Finding:** No rswag gem in Gemfile. No swagger_helper.rb. No swagger YAML. No `/api/docs` endpoint. The spec requires rswag-based OpenAPI documentation generated from request specs.

- [ ] 6.1 — Add rswag gems and configure (`web/Gemfile`, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`)
  Required tests: `GET /api/docs` returns 200 without auth, `rake rswag:specs:swaggerize` exits 0
  Files: `web/Gemfile`, `web/Gemfile.lock`, `web/vendor/cache/rswag-*.gem`, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`, `web/config/routes.rb`

- [ ] 6.2 — Convert existing request specs to rswag DSL format (`web/spec/requests/**/*_spec.rb`)
  Required tests: all existing request specs pass in rswag format, `rake rswag:specs:swaggerize` generates `swagger/v1/swagger.yaml` listing all endpoints
  Depends on: 6.1
  Files: `web/spec/requests/api/auth_spec.rb`, `web/spec/requests/agents/agent_runs_spec.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`

---

## Section 7 — Go Sidecars

**Spec:** `specs/platform/go/system/analytics.md`, `specs/platform/go/system/runner.md`, `specs/system/infrastructure/spec.md`
**Finding:** No `go/` directory exists. No Go code at all. The spec defines two Go sidecars: analytics ingest (port 9100) and runner (port 8080). Both are commented out in docker-compose.yml.

### 7.1 — Analytics Ingest Sidecar (Go)

- [ ] 7.1.1 — [SPIKE] Research Go analytics sidecar implementation approach — run `./loop.sh research analytics-sidecar`
  Open questions: Go project structure for a minimal HTTP service with Postgres batch writes, PII filtering in Go, in-memory buffering strategy
  Files: `specs/research/analytics-sidecar.md`

- [ ] 7.1.2 — Implement Go analytics ingest sidecar (`go/analytics-sidecar/main.go`, `go/analytics-sidecar/go.mod`)
  Required tests: `POST /capture` returns 202 immediately, events flushed within 5s or 100 events, events buffered on Postgres unavailability, `GET /healthz` returns 200, non-UUID distinct_id rejected, `go test ./...` exits 0
  Depends on: 7.1.1
  Files: `go/analytics-sidecar/main.go`, `go/analytics-sidecar/go.mod`, `go/analytics-sidecar/go.sum`, `infra/Dockerfile.analytics`

- [ ] 7.1.3 — Uncomment analytics sidecar in docker-compose.yml and verify integration (`infra/docker-compose.yml`)
  Required tests: `docker compose up` starts analytics sidecar on port 9100, sidecar can write to Postgres analytics_events table
  Depends on: 7.1.2
  Files: `infra/docker-compose.yml`

### 7.2 — Runner Sidecar (Go)

- [ ] 7.2.1 — [SPIKE] Research Go runner sidecar implementation approach — run `./loop.sh research runner-sidecar`
  Open questions: Go HTTP server with mutex-based concurrency, Claude stream-json token parsing, callback to Rails complete endpoint
  Files: `specs/research/runner-sidecar.md`

- [ ] 7.2.2 — Implement Go runner sidecar (`go/runner/main.go`, `go/runner/go.mod`)
  Required tests: `POST /run` without Basic Auth → 401, concurrent `POST /run` → 409, calls Rails complete endpoint after loop exits, token counts parsed from stream-json stdout, `GET /healthz` returns 200, `GET /ready` returns 200, `go test ./...` exits 0
  Depends on: 7.2.1
  Files: `go/runner/main.go`, `go/runner/go.mod`, `go/runner/go.sum`, `infra/Dockerfile.runner`

- [ ] 7.2.3 — Uncomment runner sidecar in docker-compose.yml and verify integration (`infra/docker-compose.yml`)
  Required tests: `docker compose up` starts runner on port 8080, runner can call Rails API
  Depends on: 7.2.2
  Files: `infra/docker-compose.yml`

---

## Section 8 — Batch Request Middleware

**Spec:** `specs/system/batch-requests.md`
**Finding:** No batch request middleware exists.

- [ ] 8.1 — Implement `BatchRequestMiddleware` as Rack middleware (`web/app/middleware/batch_request_middleware.rb`, `web/config/application.rb`, `web/config/routes.rb`)
  Required tests: `POST /api/batch` fans out sub-requests and returns aggregated responses, responses ordered (response[i] = request[i]), individual sub-request failures captured (not abort batch), max batch size enforced (422 on exceed), malformed JSON returns 422, sub-requests share auth context, batch endpoint requires auth, 401 without auth
  Files: `web/app/middleware/batch_request_middleware.rb`, `web/config/application.rb`, `web/spec/middleware/batch_request_middleware_spec.rb`

---

## Section 9 — filter_parameters Gap

**Spec:** `specs/practices/security.md` — filter_parameters must include `:passw`, `:email`, `:secret`, `:token`, `:_key`, `:crypt`, `:salt`, `:certificate`, `:otp`, `:ssn`, `:cvv`, `:cvc`, `:otp_attempt`
**Finding:** Current list is `%i[api_key token password secret authorization access_token refresh_token private_key credential]`. Missing: `:passw` (partial match), `:email`, `:_key`, `:crypt`, `:salt`, `:certificate`, `:otp`, `:ssn`, `:cvv`, `:cvc`, `:otp_attempt`. The spec uses partial-match patterns; current list uses full names.

- [ ] 9.1 — Update `filter_parameters` to match security spec (`web/config/application.rb`)
  Required tests: verify `:email`, `:passw`, `:crypt`, `:salt`, `:certificate`, `:otp`, `:ssn`, `:cvv`, `:cvc`, `:otp_attempt` are filtered from logs
  Files: `web/config/application.rb`, `web/spec/config/filter_parameters_spec.rb`

---

## Section 10 — Reference Graph (Priority Components for Phase 0)

**Spec:** `specs/system/reference-graph/spec.md`
**Finding:** The reference graph spec defines 7 components with priorities 1-7. For Phase 0, the controlled commit skill (Priority 1) and LEDGER.jsonl schema are the foundation. The Go reference parser (Priority 2) depends on the Go sidecar infrastructure. The web UI (Priority 5) and CI drift detection (Priority 4) are lower priority.

### LEDGER.jsonl

- [ ] 10.1 — Create LEDGER.jsonl file and document the append-only schema (`LEDGER.jsonl`)
  Required tests: file exists, entries are valid JSON, append-only (no modification of existing entries)
  Files: `LEDGER.jsonl`

### Controlled Commit Skill

The controlled commit skill is an agent instruction (skill file), not application code. It defines the atomic sequence: stage code → append LEDGER.jsonl → update IMPLEMENTATION_PLAN.md → git commit. This is enforced by the build loop loading the skill, not by Rails code.

- [ ] 10.2 — Create controlled commit skill file (`specs/skills/tools/commit.md`)
  Required tests: N/A (skill file, not application code — validated by agent usage)
  Files: `specs/skills/tools/commit.md`

### Go Reference Parser

- [ ] 10.3 — [SPIKE] Research Go reference parser design — run `./loop.sh research reference-parser`
  Open questions: Markdown frontmatter parsing in Go, git log/notes traversal, JSON graph output format, deterministic output guarantee
  Depends on: 7.2.1 (Go infrastructure knowledge)
  Files: `specs/research/reference-parser.md`

---

## Section 11 — Proposed UI Specs (status: proposed)

**Specs:** `specs/system/agent-runs-ui.md`, `specs/system/analytics-dashboard-ui.md`, `specs/system/ledger/ui.md` (superseded → reference-graph web UI)
**Finding:** All three UI specs are `status: proposed`. No UI views exist (`web/app/views/` is empty). The project PRD says "Rails 8 full stack — not API-only; views needed for UI." These are real gaps but the specs are still proposed.

- [ ] 11.1 — Agent Runs UI: server-rendered run history and detail views (`web/app/modules/agents/controllers/agent_runs_ui_controller.rb`, `web/app/views/agents/agent_runs/`)
  Required tests: `GET /agent_runs` returns paginated list with mode/status/tokens/cost columns, `GET /agent_runs/:id` shows run metadata + ordered turns with kind badges, turns rendered as markdown, auth required (401 redirect without auth)
  Files: `web/app/modules/agents/controllers/agent_runs_ui_controller.rb`, `web/app/views/agents/agent_runs/index.html.erb`, `web/app/views/agents/agent_runs/show.html.erb`, `web/config/routes.rb`, `web/spec/requests/agents/agent_runs_ui_spec.rb`

- [ ] 11.2 — Analytics Dashboard UI: summary cards, cost breakdown, recent runs (`web/app/modules/analytics/controllers/dashboard_controller.rb`, `web/app/views/analytics/dashboard/`)
  Required tests: `GET /analytics` shows summary cards (total cost, total runs, failure rate), cost by provider/model table, recent runs list, `GET /analytics/llm` shows cost/token breakdown filterable by date, auth required
  Depends on: 3.2, 3.4
  Files: `web/app/modules/analytics/controllers/dashboard_controller.rb`, `web/app/views/analytics/dashboard/index.html.erb`, `web/app/views/analytics/dashboard/llm.html.erb`, `web/config/routes.rb`, `web/spec/requests/analytics/dashboard_spec.rb`

---

## Section 12 — Log Tail Relay

**Spec:** `specs/system/log-tail-relay.md` — `status: proposed`
**Finding:** Spec has unresolved open questions about approach (file relay vs HTTP endpoint vs clipboard). No implementation.

- [ ] 12.1 — [SPIKE] Research log tail relay approach — run `./loop.sh research log-tail-relay`
  Open questions: Which approach fits single-user local-only? Should agent request proactively or developer-triggered? Cover all services or just rails?
  Files: `specs/research/log-tail-relay.md`

---

## Section 13 — Makefile Consistency

**Spec:** `specs/practices/coding.md` § Makefile Consistency
**Finding:** Makefile has several `TODO` comments about agent-agnostic naming. The `sandbox` target uses `docker sandbox run kiro` which is Kiro-specific. These are cosmetic but flagged by the coding practices.

No task — these are agent-tooling concerns, not application code gaps.

---

## Section 14 — Authorization Enforcement

**Spec:** `specs/practices/security.md` § Authorization Enforcement
**Finding:** The spec requires structural authorization enforcement: `index` actions must call `policy_scope`, all other actions must call `authorize`, enforced by after-action hooks. No policy layer exists. No `pundit` or equivalent gem. Controllers use `authenticate!` but not `authorize`.

- [ ] 14.1 — [SPIKE] Research authorization approach for Phase 0 — run `./loop.sh research authorization`
  Open questions: Pundit vs custom policy layer, single-org Phase 0 simplification, after-action hook enforcement pattern
  Files: `specs/research/authorization.md`

---

## Task Dependency Summary

```
Independent (can start now):
  2.1  Health check middleware
  3.1  AuditEvent model
  3.2  LlmMetric model
  5.1  Turn content GC job
  5.2  RunStorageService.record_question
  9.1  filter_parameters update
  10.1 LEDGER.jsonl
  10.2 Controlled commit skill

Depends on 3.1 + 3.2:
  3.3  AuditLogger service → 3.4 MetricsController → 3.5 AuditLogger wiring

Depends on 3.3:
  3.5  AuditLogger wiring in AgentRunsController

Depends on 6.1:
  6.2  Convert request specs to rswag

Spike-blocked:
  7.1.2, 7.1.3  Analytics sidecar (blocked by 7.1.1 spike)
  7.2.2, 7.2.3  Runner sidecar (blocked by 7.2.1 spike)
  10.3+          Reference parser (blocked by spike)
  12.1+          Log tail relay (blocked by spike)
  14.1+          Authorization (blocked by spike)

Lower priority (proposed specs):
  11.1  Agent Runs UI
  11.2  Analytics Dashboard UI
```

---

## Spec Contradictions

1. **`metadata.hypothesis` on FeatureFlag:** Base spec says optional in Phase 0. Platform override says required → 422. Tracked in task 4.2. Resolve before implementing.

## Notes

- No `go/` directory exists — both Go sidecars are unbuilt
- `web/app/views/` is empty — no UI views exist yet
- rswag is not installed — no API documentation infrastructure
- The `specs/system/ledger/` and `specs/system/knowledge/` specs are marked SUPERSEDED — code removal is complete
- `specs/system/reference-graph/spec.md` Component 6 (Ledger + Knowledge Removal) is complete
- `specs/system/reference-graph/spec.md` Component 7 (LLM-Resolved Acceptance Tests) is explicitly a future spike, not in scope
