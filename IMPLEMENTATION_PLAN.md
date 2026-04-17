# IMPLEMENTATION_PLAN.md

**Generated:** 2026-04-17
**Phase:** 0 (Local — Docker Compose only)
**Source of truth:** specs/ + web/ + git state

---

## Completed Work (discovered from code)

The following is implemented and tested (169 examples, 0 failures as of tag 0.0.43):

- Rails 8 skeleton with autoloading for `app/modules/`
- Auth: `AuthToken` (JWT encode/decode), `Secret` value object, `ApplicationController#authenticate!`, sidecar auth, `Api::AuthController`, dev bypass
- Security: `Security::PromptSanitizer`, `Security::LogRedactor`, lograge, `filter_parameters`
- Rate limiting: `Rack::Attack` (300/5min general, 10/min auth)
- Health check: `HealthCheckMiddleware` at position 0 (GET /health → 200/503)
- Agents module: `AgentRun`, `AgentRunTurn`, `ProviderAdapter` (Claude/Kiro/OpenAI), `PromptDeduplicator`, `RunStorageService`, `AgentRunsController` (start/complete/input)
- Sandbox module: `ContainerRun`, `DockerDispatcher`
- Analytics module: `AnalyticsEvent` (append-only), `AuditEvent` (append-only, severity enum), `FeatureFlag` (enabled?/lifecycle), `FeatureFlagsController` (CRUD)
- Ledger + Knowledge modules fully removed (migrations, models, services, controllers, jobs)
- AgentRun FK columns replaced with `source_ref` string
- Infrastructure: `Dockerfile`, `Dockerfile.test`, `docker-compose.yml`, `docker-compose.test.yml`
- Solid Queue configured (Postgres-backed, no Redis)
- Module LOOKUP.md

---

## Gap Analysis

### Section 1 — Reference Graph: Controlled Commit Skill (Priority 1)

**Spec:** `specs/system/reference-graph/spec.md` § Component 1
**Status:** Not started. No LEDGER.jsonl, no commit skill, no structured commit tooling.

This is a file-and-git-native skill, not a Rails model. It atomically stages code + appends LEDGER.jsonl + updates IMPLEMENTATION_PLAN.md + commits. The build loop currently uses raw `git commit`.

- [ ] 1.1 — [SPIKE] Research controlled commit skill design — run `./loop.sh research controlled-commit` (see specs/skills/tools/research.md)
  Spec has open questions about plan item renumbering and LEDGER.jsonl growth. Spike should resolve the file format, the shell script or Ruby script interface, and how the build loop invokes it.
  Required tests: n/a (spike produces a research finding, not code)

### Section 2 — Reference Graph: Go Reference Parser (Priority 2)

**Spec:** `specs/system/reference-graph/spec.md` § Component 2
**Status:** Not started. No `go/` directory exists. The parser is a standalone Go binary.

- [ ] 2.1 — [SPIKE] Research Go reference parser architecture — run `./loop.sh research go-parser` (see specs/skills/tools/research.md)
  Spike should define: input file formats, output JSON schema, node/edge types, how to parse LEDGER.jsonl + IMPLEMENTATION_PLAN.md + spec files + RSpec `spec:` tags + git log + git notes. Also resolve open question about plan item renumbering (title-based stable refs vs numeric IDs).
  Required tests: n/a (spike)

### Section 3 — Analytics: LlmMetric Model

**Spec:** `specs/platform/rails/system/analytics.md` — `Analytics::LlmMetric` per agent run cost/token record
**Status:** Not implemented. No `llm_metrics` table, no model.

- [ ] 3.1 — Create `Analytics::LlmMetric` model and migration (`web/app/modules/analytics/models/llm_metric.rb`, `web/db/migrate/`)
  Schema: `id (uuid), org_id (uuid), agent_run_id (uuid FK), provider (string), model (string), input_tokens (int), output_tokens (int), cost_estimate_usd (decimal 10,6), mode (string), node_id (string), duration_ms (int), timestamps`
  Index on `(org_id, provider, model, created_at)`
  Required tests: validations (org_id, provider, model required), agent_run association, cost_estimate_usd precision, node_id accepts string refs

### Section 4 — Analytics: AuditLogger Service

**Spec:** `specs/platform/rails/system/analytics.md` — `Analytics::AuditLogger.log(...)` async, never raises, fire-and-forget
**Status:** Not implemented. No `AuditLogger` service, no `AuditLogJob`.

- [ ] 4.1 — Create `Analytics::AuditLogger` service and `Analytics::AuditLogJob` (`web/app/modules/analytics/services/audit_logger.rb`, `web/app/modules/analytics/jobs/audit_log_job.rb`)
  `AuditLogger.log(org_id:, event_name:, severity:, properties: {})` enqueues `AuditLogJob` on `analytics` queue. Never raises — catches all exceptions and logs to Rails logger.
  Required tests: enqueues job, creates AuditEvent record when job runs, failure logs to Rails logger without raising, severity validation

### Section 5 — Analytics: MetricsController

**Spec:** `specs/platform/rails/system/analytics.md` — `Analytics::MetricsController` with JWT auth
**Status:** Not implemented. No controller, no routes.

Depends on: 3.1 (LlmMetric model)

- [ ] 5.1 — Create `Analytics::MetricsController` with LLM, loops, and summary endpoints (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/config/routes.rb`)
  Endpoints: `GET /api/analytics/llm`, `GET /api/analytics/loops`, `GET /api/analytics/summary`
  All require JWT auth. LLM endpoint aggregates by provider/model with date range filter. Loops endpoint returns run counts/failure rates by mode. Summary returns total cost this week + loop error rate.
  Required tests: 200 happy path for each endpoint, 401 without auth, date range filtering, correct aggregation math
  Required request spec: `web/spec/requests/analytics/metrics_spec.rb`

### Section 6 — Analytics: Events and Flags Query Endpoints

**Spec:** `specs/platform/rails/product/analytics.md` — `GET /api/analytics/events`, `GET /api/analytics/flags/:key`
**Status:** Not implemented. No events endpoint, no flags/:key endpoint.

- [ ] 6.1 — Add events and flags/:key endpoints to MetricsController (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/config/routes.rb`)
  `GET /api/analytics/events` — paginated event list, filterable by event_name, org_id, date range
  `GET /api/analytics/flags/:key` — exposure counts and conversion rates per variant
  Required tests: pagination, filtering by event_name and date range, flags/:key returns exposure counts, 401 without auth, 404 for unknown flag key

### Section 7 — Analytics: FeatureFlagExposure Model

**Spec:** `specs/platform/rails/product/analytics.md` — `Analytics::FeatureFlagExposure`
**Status:** Not implemented. No model, no migration.

- [ ] 7.1 — Create `Analytics::FeatureFlagExposure` model and migration (`web/app/modules/analytics/models/feature_flag_exposure.rb`, `web/db/migrate/`)
  Schema: `id (uuid), org_id (uuid), flag_key (string), distinct_id (string), variant (string), timestamps`
  Index on `(org_id, flag_key, distinct_id)`
  Required tests: validations, index uniqueness behavior, distinct_id is UUID not email

### Section 8 — Analytics: Auto-fire `$feature_flag_called` on FeatureFlag.enabled?

**Spec:** `specs/system/analytics/spec.md` — Feature flag evaluation automatically fires `$feature_flag_called`
**Spec:** `specs/platform/rails/product/analytics.md` — `enabled?` fires `$feature_flag_called` automatically
**Status:** Not implemented. `FeatureFlag.enabled?` does not fire any event.

Depends on: 7.1 (FeatureFlagExposure model)

- [ ] 8.1 — Update `FeatureFlag.enabled?` to auto-fire `$feature_flag_called` event (`web/app/modules/analytics/models/feature_flag.rb`)
  On every call to `enabled?`, create an `AnalyticsEvent` with `event_name: "$feature_flag_called"` and properties `{ flag_key:, variant:, enabled: }`. Fire-and-forget — never raise on failure.
  Required tests: calling `enabled?` creates an analytics event, event has correct properties, failure to create event does not raise, distinct_id is UUID

### Section 9 — Agent Runs: `iteration` Field and Unique Index

**Spec:** `specs/platform/rails/system/agents.md` — Unique index on `(run_id, iteration)`, duplicate → 422
**Status:** Partially implemented. `AgentRun` has `run_id` with uniqueness validation but no `iteration` column. The spec requires `(run_id, iteration)` composite uniqueness.

- [ ] 9.1 — Add `iteration` column to `agents_agent_runs` and update unique index (`web/db/migrate/`, `web/app/modules/agents/models/agent_run.rb`)
  Add `iteration` integer column (nullable for backward compat). Replace unique index on `run_id` with unique index on `(run_id, iteration)`. Update model validation.
  Required tests: duplicate (run_id, iteration) → DB-level rejection, different iterations for same run_id allowed, controller returns 422 on duplicate

### Section 10 — Agent Runs: `cost_estimate_usd` Column

**Spec:** `specs/platform/rails/system/agents.md` — `cost_estimate_usd` decimal(10,6)
**Status:** Implemented. Column exists in migration `20260409000003`. ✓ No action needed.

### Section 11 — Agent Runs: `source_library_item_ids` → `source_node_ids`

**Spec:** `specs/platform/rails/system/agents.md` — `source_library_item_ids` jsonb, default `[]`
**Status:** The spec says `source_library_item_ids` but the reference-graph spec superseded knowledge module. The column is already `source_node_ids` (jsonb, default `[]`) which aligns with the reference-graph spec's string refs. The platform override spec is stale on this name. No action needed — the implementation is correct for the superseding spec.

### Section 12 — Agent Runs: Complete Endpoint Calls AuditLogger

**Spec:** `specs/platform/rails/system/agents.md` — Complete endpoint calls `Analytics::AuditLogger`
**Status:** Not implemented. `AgentRunsController#complete` does not call `AuditLogger`.

Depends on: 4.1 (AuditLogger service)

- [ ] 12.1 — Add `AuditLogger.log` call to `AgentRunsController#complete` (`web/app/modules/agents/controllers/agent_runs_controller.rb`)
  After successful completion, call `Analytics::AuditLogger.log(org_id:, event_name: "agent_run.completed", severity: "info", properties: { run_id:, mode:, provider:, model: })`.
  Required tests: completing a run enqueues an audit log job, audit event created with correct properties

### Section 13 — Batch Request Middleware

**Spec:** `specs/system/batch-requests.md`
**Status:** Not implemented. No middleware, no route.

- [ ] 13.1 — Create batch request Rack middleware (`web/app/middleware/batch_request_middleware.rb`, `web/config/application.rb`)
  Intercepts `POST /api/batch`. Fans out sub-requests internally through the Rack stack. Returns aggregated responses. Max batch size 100 (422 if exceeded). Malformed JSON → 422. Individual sub-request failures captured in response array. Requires auth (inherits from outer request).
  Required tests: happy path with 2 sub-requests, max batch size exceeded → 422, malformed JSON → 422, individual sub-request failure captured, auth required, response ordering matches request ordering

### Section 14 — API Documentation (rswag)

**Spec:** `specs/system/api/spec.md`, `specs/platform/rails/system/api-standards.md`
**Status:** Not implemented. No rswag gem, no swagger config, no request specs using rswag DSL, no `/api/docs` endpoint.

- [ ] 14.1 — Add rswag gems and configure Swagger UI (`web/Gemfile`, `web/vendor/cache/`, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`)
  Add `rswag-api`, `rswag-ui`, `rswag-specs` gems. Download to vendor/cache. Configure Swagger UI at `/api/docs` (unauthenticated). Create `swagger_helper.rb`.
  Required tests: `GET /api/docs` returns 200 without auth, `rake rswag:specs:swaggerize` exits 0

- [ ] 14.2 — Convert existing request specs to rswag DSL (`web/spec/requests/`)
  Convert `api/auth_spec.rb`, `agents/agent_runs_spec.rb`, `analytics/feature_flags_spec.rb` to rswag format. Each spec both tests the endpoint and contributes to generated OpenAPI spec.
  Required tests: all existing request spec assertions still pass, `swagger/v1/swagger.yaml` generated and lists all endpoints

### Section 15 — Infrastructure: docker-compose.yml Gaps

**Spec:** `specs/system/infrastructure/spec.md`
**Status:** Partially compliant. Issues found:

1. **Postgres port binding** — Postgres in `docker-compose.yml` has no `ports:` section (good — internal only). ✓
2. **Image tags** — `docker-compose.yml` uses `${GIT_SHA:-dev}` for rails image. Spec says "always git SHA, never `latest`". The `:-dev` fallback is acceptable for local dev. ✓
3. **Go runner and analytics sidecars** — commented out in `docker-compose.yml`. Spec requires `go_runner` (port 8080) and `analytics` (port 9100) services. These are Go services that don't exist yet.
4. **Redis** — commented out. Not required by current code (Solid Queue is Postgres-backed). ✓

- [ ] 15.1 — [SPIKE] Research Go analytics sidecar design — run `./loop.sh research go-analytics-sidecar` (see specs/skills/tools/research.md)
  The analytics spec requires a Go ingest sidecar (`POST /capture`, port 9100) with in-memory queue and batch flush. This is a Go service. Spike should define: minimal Go service structure, flush strategy, Postgres connection, event schema, and how Rails fire-and-forget calls it.
  Required tests: n/a (spike)

### Section 16 — Infrastructure: Dockerfile Uses `ruby:3.3` Not `ruby:3.3-slim`

**Spec:** `specs/project-prd.md` — Base image: `ruby:3.3-slim`
**Status:** `Dockerfile` final stage uses `ruby:3.3-slim` ✓. Builder stage uses `ruby:3.3` (full, for compilation). This is correct — the builder needs build tools, the final image is slim.

### Section 17 — Spec Reference Tags in Tests (Priority 3)

**Spec:** `specs/system/reference-graph/spec.md` § Component 3
**Status:** Not started. No `spec:` metadata tags in any RSpec file.

Depends on: 2.1 (Go parser spike — defines the tag format the parser will consume)

- [ ] 17.1 — Add `spec:` metadata tags to existing RSpec files (`web/spec/`)
  Add `spec: "specs/system/..."` metadata to existing describe blocks. Start with agent_run, feature_flag, health_check, auth specs. Reference the spec section each test covers.
  Required tests: RSpec metadata is parseable, tags reference valid spec paths (validate with `scripts/validate-refs.sh` if applicable)

### Section 18 — Reference Graph: LEDGER.jsonl Bootstrap

**Spec:** `specs/system/reference-graph/spec.md` § File Schemas
**Status:** No LEDGER.jsonl exists.

Depends on: 1.1 (controlled commit skill spike)

- [ ] 18.1 — Create initial LEDGER.jsonl with bootstrap entries
  Create `LEDGER.jsonl` at project root. Backfill status entries for completed work from git history. Define the append-only convention.
  Required tests: LEDGER.jsonl is valid JSON-per-line, entries have required fields (ts, type, ref)

### Section 19 — Sandbox: ContainerRun `stdout`/`stderr` Columns

**Spec:** `specs/system/sandbox/prd.md` — ContainerRun record includes `stdout`, `stderr`
**Status:** `DockerDispatcher` writes `stdout` and `stderr` to the record, but need to verify the migration has these columns.

- [x] 19.1 — Verify `sandbox_container_runs` table has `stdout` and `stderr` text columns (`web/db/migrate/20260409000005_create_sandbox_container_runs.rb`)
  **Verified:** Migration includes `t.text :stdout` and `t.text :stderr`. Covered by `docker_dispatcher_spec.rb`.

### Section 20 — Agent Runs UI (Proposed)

**Spec:** `specs/system/agent-runs-ui.md` (status: proposed)
**Status:** Not implemented. No views, no HTML controllers.

- [ ] 20.1 — Create Agent Runs HTML views (`web/app/controllers/agent_runs_controller.rb`, `web/app/views/agent_runs/`)
  `GET /agent_runs` — paginated list (mode, status, provider/model, tokens, cost, duration, created_at), filterable by mode and status
  `GET /agent_runs/:id` — run detail with turns, markdown rendering, parent run link, source_ref
  Server-rendered ERB, no JS framework. Auth via `authenticate!`.
  Required tests: 200 for index and show, pagination, mode/status filtering, turn content rendered as markdown, 401 without auth

### Section 21 — Analytics Dashboard UI (Proposed)

**Spec:** `specs/system/analytics-dashboard-ui.md` (status: proposed)
**Status:** Not implemented. No views.

Depends on: 3.1 (LlmMetric model), 5.1 (MetricsController)

- [ ] 21.1 — Create Analytics Dashboard HTML views (`web/app/controllers/analytics_dashboard_controller.rb`, `web/app/views/analytics_dashboard/`)
  `GET /analytics` — summary cards (total cost, total runs, failure rate), cost by provider/model, recent runs
  `GET /analytics/llm` — cost/token breakdown by provider and model, date range filter
  Server-rendered ERB. Auth via `authenticate!`.
  Required tests: 200 for dashboard and llm views, summary cards show correct data, 401 without auth

### Section 22 — Log Tail Relay (Proposed)

**Spec:** `specs/system/log-tail-relay.md` (status: proposed)
**Status:** Not implemented. Spec has unresolved open questions.

- [ ] 22.1 — [SPIKE] Research log tail relay approach — run `./loop.sh research log-tail-relay` (see specs/skills/tools/research.md)
  Resolve: file relay vs HTTP endpoint vs clipboard/pipe, which services to cover, proactive vs triggered.
  Required tests: n/a (spike)

### Section 23 — Multi-tenancy: Add `org_id` to Agents and Sandbox Tables

**Spec:** `specs/practices/multi-tenancy.md`, `specs/project-prd.md` — `org_id` present on all records from day one
**Status:** Not implemented. `agents_agent_runs`, `agents_agent_run_turns`, and `sandbox_container_runs` have no `org_id` column. Analytics tables already have it.

- [ ] 23.1 — Add `org_id` to `agents_agent_runs` and `sandbox_container_runs` (`web/db/migrate/`)
  Add `org_id` (uuid, nullable initially for backward compat, with default from `DEFAULT_ORG_ID`). Backfill existing rows. Add index.
  Required tests: new records include org_id, queries can filter by org_id

### Section 24 — Turn Content GC Job

**Spec:** `specs/system/agent-runner/spec.md` § Turn Content GC
**Status:** Not implemented. `purged_at` column exists on `agents_agent_run_turns` but no GC job.

- [ ] 24.1 — Create `Agents::TurnContentGcJob` (`web/app/modules/agents/jobs/turn_content_gc_job.rb`, `web/config/recurring.yml`)
  Solid Queue recurring job. Purges turn content for completed runs older than 30 days. Sets `purged_at = now()` and clears `content`. Never purges failed or `waiting_for_input` runs.
  Required tests: purges content on old completed runs, retains turn record skeleton, skips failed runs, skips waiting_for_input runs, idempotent (re-running doesn't error)

### Section 25 — RunStorageService Unit Spec

**Spec:** `specs/platform/rails/system/api-standards.md` — every controller has a corresponding `spec/requests/` file
**Status:** `RunStorageService` has no dedicated spec (tested indirectly through controller spec). The service is internal — no request spec needed. However, a unit spec would improve coverage.

- [ ] 25.1 — Create `RunStorageService` unit spec (`web/spec/modules/agents/services/run_storage_service_spec.rb`)
  Required tests: start creates run with status running, dedup hit returns cached run, concurrent run raises ConcurrentRunError, duplicate run_id raises DuplicateRunError, complete updates status, record_input appends turn and sets status running

### Section 26 — Missing LOOKUP.md Files

**Spec:** `specs/practices/changeability.md` — every module directory gets a LOOKUP.md
**Status:** `web/app/modules/LOOKUP.md` exists (top-level). Individual module directories (`agents/`, `sandbox/`, `analytics/`) do not have their own LOOKUP.md files.

- [ ] 26.1 — Create per-module LOOKUP.md files (`web/app/modules/agents/LOOKUP.md`, `web/app/modules/sandbox/LOOKUP.md`, `web/app/modules/analytics/LOOKUP.md`)
  Each file: purpose (one sentence), public interface, cross-module rules.
  Required tests: n/a (documentation)

---

## Task Dependency Order

```
Independent (can start now):
  3.1  LlmMetric model
  4.1  AuditLogger service + AuditLogJob
  7.1  FeatureFlagExposure model
  9.1  AgentRun iteration column
  13.1 Batch request middleware
  14.1 rswag setup
  17.1 Spec reference tags (soft dependency on 2.1 for format, but can use draft format)
  19.1 Verify ContainerRun columns ✓ DONE
  23.1 Add org_id to agents/sandbox tables
  24.1 Turn Content GC job
  25.1 RunStorageService unit spec
  26.1 LOOKUP.md files
  20.1 Agent Runs UI

Spikes (block downstream work):
  1.1  Controlled commit skill spike → blocks 18.1
  2.1  Go parser spike → blocks 17.1 (format), Go implementation (Phase 0 scope TBD)
  15.1 Go analytics sidecar spike → blocks sidecar implementation
  22.1 Log tail relay spike → blocks relay implementation

After 3.1:
  5.1  MetricsController

After 4.1:
  12.1 AuditLogger call in complete endpoint

After 5.1:
  6.1  Events and flags/:key endpoints
  21.1 Analytics Dashboard UI

After 7.1:
  8.1  Auto-fire $feature_flag_called

After 14.1:
  14.2 Convert request specs to rswag

After 1.1:
  18.1 LEDGER.jsonl bootstrap
```

---

## Out of Scope (Phase 0)

- Go runner sidecar (`Dockerfile.runner`, port 8080) — Go binary not yet written
- Go analytics sidecar (`Dockerfile.analytics`, port 9100) — Go binary not yet written
- CI (Phase 1), staging (Phase 2), production (Phase 3)
- NixOS, k8s manifests, SOPS secrets
- Redis (not needed — Solid Queue is Postgres-backed)
- Streaming output, ActionCable, websockets
- Apache AGE graph extension
- Outbound analytics adapters (PostHog, Datadog)
- LLM-resolved acceptance tests
- Multi-provider fallback
- Percentage rollout for feature flags
- Knowledge module (removed, superseded by reference graph)
- Ledger module (removed, superseded by reference graph)

## Notes

- The reference-graph spec supersedes both ledger and knowledge specs. All ledger/knowledge code has been removed. The reference graph is file-and-git-native — the Go parser and LEDGER.jsonl are the new system.
- `source_library_item_ids` in `specs/platform/rails/system/agents.md` is stale — the field is `source_node_ids` (string refs) per the reference-graph spec. No action needed.
- The `specs/system/analytics-dashboard-ui.md` and `specs/system/agent-runs-ui.md` are marked `proposed`. Tasks are included but lower priority.
- `specs/system/log-tail-relay.md` is marked `proposed` with unresolved open questions. Spike task created.
