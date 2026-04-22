# IMPLEMENTATION_PLAN.md

Generated: 2026-04-21
Phase: 0 — Local (Docker Compose only)
Scope: Phase 0 MVP per `specifications/project-requirements.md`

## Completed Work (discovered from code + git state at tag 0.0.63)

297 examples, 0 failures, 99.47% coverage.

- **Infrastructure:** `infra/Dockerfile`, `infra/Dockerfile.test`, `infra/docker-compose.yml`, `infra/docker-compose.test.yml`, entrypoints, pgvector/pg16, Go sidecar stubs annotated
- **Auth:** `AuthToken` (JWT encode/decode), `Secret` value object, `ApplicationController#authenticate!`, sidecar auth (`X-Sidecar-Token`), `Api::AuthController` (POST /api/auth/token), dev bypass (DISABLE_AUTH)
- **Security:** `Security::PromptSanitizer`, `Security::LogRedactor`, `filter_parameters`, `rack-attack` rate limiting
- **Agents module:** `AgentRun` model (modes, statuses, validations, unique run_id, agent_override), `AgentRunTurn` model (kinds, purged_at), `ProviderAdapter` base + `ClaudeAdapter` / `KiroAdapter` / `OpenAiAdapter` (build_prompt with pinned+sliding trimming, call_provider, parse_response), `PromptDeduplicator`, `RunStorageService` (start/complete/record_input, dedup, concurrent run check, LlmMetric creation), `AgentRunsController` (start/complete/input endpoints, org-scoped), `AgentRunJob` (Solid Queue, limits_concurrency, turn reconstruction, pause/resume, agent_override), `TurnContentGcJob` (30-day retention, skips failed/waiting)
- **Sandbox module:** `ContainerRun` model (statuses, duration_ms, optional agent_run, org_id), `DockerDispatcher` (argument array, Secret filtering, timeout, record creation)
- **Analytics module:** `AnalyticsEvent` (append-only, node_id indexed), `AuditEvent` (append-only, severities), `LlmMetric` (append-only), `FeatureFlag` (enabled?, auto-fires $feature_flag_called, archived returns false), `AuditLogger` (async, never raises), `AuditLogJob`, `MetricsController` (llm/loops/summary/events/flag_stats), `FeatureFlagsController` (index/create/update)
- **Health check:** `HealthCheckMiddleware` at position 0, GET /health → 200/503
- **Ledger/Knowledge removal:** Tables dropped, FKs replaced with source_ref string
- **Reference graph partial:** `LedgerAppender`, `scripts/controlled-commit.sh`
- **Module scaffold:** Namespace resolution, LOOKUP.md

## Spec Contradictions & Ambiguities

1. **FeatureFlagExposure model:** Rails platform override (`product/analytics.md`) references `Analytics::FeatureFlagExposure` model. Current implementation fires `$feature_flag_called` as an `AnalyticsEvent` — no separate model. The AnalyticsEvent approach is correct for Phase 0 (avoids speculative generality). Flag for review if query performance on exposures becomes an issue.

2. **FeatureFlag metadata.hypothesis:** `feature-flags/concept.md` says "optional in Phase 0", `product/analytics.md` says "required on creation → 422 if missing". Requirements file says "not required in Phase 0". **Resolution:** Follow requirements — optional in Phase 0. The `product/analytics.md` override is incorrect for Phase 0.

3. **Coverage floor:** `specifications/practices/verification.md` says 85% minimum. `spec_helper.rb` sets 90%. The code is more strict — keep 90% as the actual floor.

4. **Batch request middleware:** `specifications/system/batch-requests.md` is a concept with status `active` but has no requirements file and no phase assignment. Include as a lower-priority task.

5. **Go sidecars:** `specifications/project-requirements.md` lists Go 1.22 binaries under `go/` (runner sidecar, analytics ingest sidecar, reference-graph parser CLI). No `go/` directory exists. The infrastructure spec says the analytics ingest sidecar is Go on port 9100. Phase 0 scope: the Go sidecars are needed for the analytics ingest pipeline and the reference graph parser. However, building Go infrastructure is a significant effort. The docker-compose.yml already has stubs commented out. Plan Go sidecar tasks but mark them as lower priority — Rails can function without them in Phase 0 (analytics events are written directly to Postgres, not via sidecar).

6. **Repo map:** `specifications/system/repo-map/concept.md` is status `draft`. It requires a Go CLI binary. Defer to after Go infrastructure is established.

---

## Open Tasks

### Section 1 — Bugs & Inconsistencies (High Priority)

- [x] 1.1 — Fix FeatureFlagsController#create to use current_org_id instead of permitting org_id from params (`web/app/modules/analytics/controllers/feature_flags_controller.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`)
  Required tests: create with JWT sets org_id from token (not params), create with different org_id in params still uses token org_id, 401 without auth
  Required threat tests: caller cannot create flag for another org by passing org_id in params

### Section 2 — API Documentation & Request Testing (spec: `system/api/`)

rswag is not installed. No swagger/OpenAPI docs exist. The spec requires every endpoint documented and covered by rswag request specs.

- [x] 2.1 — Install rswag gems and configure Swagger UI at /api/docs (`web/Gemfile`, `web/Gemfile.lock`, `web/vendor/cache/`, `web/config/initializers/rswag.rb`, `web/spec/swagger_helper.rb`, `web/swagger/v1/swagger.yaml`)
  Required tests: `GET /api/docs` returns 200 without authentication, `rake rswag:specs:swaggerize` exits 0

- [x] 2.2 — Convert `spec/requests/api/auth_spec.rb` to rswag format (`web/spec/requests/api/auth_spec.rb`)
  Required tests: happy path 201, invalid secret 401, generated swagger includes POST /api/auth/token

- [x] 2.3 — Convert `spec/requests/agents/agent_runs_spec.rb` to rswag format (`web/spec/requests/agents/agent_runs_spec.rb`)
  Required tests: start 201, start dedup 200, start concurrent 409, start duplicate 422, start 401, complete 200, complete 401, input 200, input 404, generated swagger includes all agent_runs endpoints

- [x] 2.4 — Convert `spec/requests/analytics/metrics_spec.rb` to rswag format (`web/spec/requests/analytics/metrics_spec.rb`)
  Required tests: llm 200, llm 401, loops 200, loops 401, summary 200, summary 401, events 200, events 401, flag_stats 200, flag_stats 401, generated swagger includes all analytics endpoints

- [x] 2.5 — Convert `spec/requests/analytics/feature_flags_spec.rb` to rswag format (`web/spec/requests/analytics/feature_flags_spec.rb`)
  Required tests: index 200, index 401, create 201, create 422, update 200, update 404, generated swagger includes all feature_flags endpoints

- [x] 2.6 — Add rswag request spec for GET /health (`web/spec/requests/health_spec.rb`)
  Required tests: 200 when DB up, 503 when DB down, generated swagger includes GET /health

### Section 3 — Batch Request Middleware (spec: `system/batch-requests.md`)

- [ ] 3.1 — Implement BatchRequestMiddleware (`web/app/middleware/batch_request_middleware.rb`, `web/config/application.rb`, `web/config/routes.rb`, `web/spec/middleware/batch_request_middleware_spec.rb`)
  Required tests: fans out sub-requests and returns aggregated responses, preserves response ordering, individual sub-request failure doesn't fail batch, max batch size exceeded returns 422, malformed JSON returns 422, inherits auth from outer request, sub-requests run through full Rack stack

### Section 4 — Reference Graph (spec: `system/reference-graph/`)

The controlled-commit script and LedgerAppender exist. The Go reference parser is a significant effort requiring Go infrastructure. Phase 0 scope: ensure the file-based artifacts (LEDGER.jsonl, controlled-commit) are solid. The Go parser and web UI are deferred until Go infrastructure exists.

- [ ] 4.1 — Add spec: tag convention to RSpec tests for spec traceability (`web/spec/models/agents/agent_run_spec.rb`, `web/spec/models/analytics/feature_flag_spec.rb` — add `spec:` metadata tags linking to spec sections)
  Required tests: at least 3 spec files have `spec:` metadata tags that reference specification paths

- [ ] 4.2 — Validate LEDGER.jsonl schema in controlled-commit.sh (`scripts/controlled-commit.sh`, `scripts/test-controlled-commit.sh`)
  Required tests: controlled-commit.sh rejects invalid event types, appends valid events, idempotent on duplicate

### Section 5 — Agent Runner Gaps (spec: `system/agent-runner/`)

- [ ] 5.1 — Implement skill assembly in AgentRunJob#load_enrichment (`web/app/modules/agents/jobs/agent_run_job.rb`, `web/spec/jobs/agents/agent_run_job_spec.rb`)
  Required tests: load_enrichment reads skill file body from source_ref, loads context_chunks from practices files declared in skill frontmatter, loads principles files, returns [context_chunks, principles], returns empty arrays when source_ref is nil or file not found

- [ ] 5.2 — Add duration_ms and cost_estimate_usd recording in AgentRunJob (`web/app/modules/agents/jobs/agent_run_job.rb`, `web/spec/jobs/agents/agent_run_job_spec.rb`)
  Required tests: completed run has duration_ms set, completed run has cost_estimate_usd calculated from provider response tokens

- [ ] 5.3 — Add prompt_sha256 computation in RunStorageService.start (`web/app/modules/agents/services/run_storage_service.rb`, `web/spec/modules/agents/services/run_storage_service_spec.rb`)
  Required tests: when prompt_sha256 not provided, it is computed from assembled prompt; dedup still works with computed hash

### Section 6 — Analytics Gaps (spec: `system/analytics/`)

- [ ] 6.1 — Add mode filter to GET /api/analytics/llm endpoint (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/spec/requests/analytics/metrics_spec.rb`)
  Required tests: filters by mode param when provided, returns all modes when mode param absent

- [ ] 6.2 — Add mode and exit_code filters to GET /api/analytics/loops endpoint (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/spec/requests/analytics/metrics_spec.rb`)
  Required tests: filters by mode, filters by exit_code (status), returns all when no filter

### Section 7 — Infrastructure Gaps (spec: `system/infrastructure/`)

- [ ] 7.1 — Postgres port binding: verify postgres is not bound to 0.0.0.0 in docker-compose files (`infra/docker-compose.yml`, `infra/docker-compose.test.yml`)
  Required tests: no `ports:` directive on postgres service in either compose file (manual verification — postgres has no ports exposed, which is correct)
  **Status: DONE** — verified: neither compose file exposes postgres ports to the host. No change needed.

- [ ] 7.2 — Image tags: docker-compose.yml rails image uses `${GIT_SHA:-dev}` — verify this is consistent (`infra/docker-compose.yml`)
  **Status: DONE** — verified: `image: unpossible-rails:${GIT_SHA:-dev}` is set. The spec says "always git SHA, never latest" — the `dev` fallback is acceptable for local development.

- [ ] 7.3 — Add `db:schema:dump` or `db:structure:dump` to generate schema file (`web/db/schema.rb` or `web/db/structure.sql`)
  Required tests: schema file exists and is loadable (manual verification after running migrations)
  Note: No schema.rb or structure.sql exists. This is needed for `maintain_test_schema!` in rails_helper.rb to work correctly. The test container runs migrations via entrypoint-test.sh, but a committed schema file is standard Rails practice.

- [ ] 7.4 — Add recurring.yml entries for test and development environments (`web/config/recurring.yml`)
  Required tests: recurring.yml has entries for development environment (currently only production is defined)
  Note: TurnContentGcJob is only scheduled in production. Development should have it too for local testing.

### Section 8 — Go Sidecars (spec: `system/infrastructure/`, `system/analytics/`)

The analytics ingest sidecar (Go, port 9100) and runner sidecar (Go, port 8080) are specified but no Go code exists. The reference graph parser is also Go. These are significant efforts.

Phase 0 works without Go sidecars — analytics events are written directly to Postgres from Rails. The Go ingest sidecar adds non-blocking fire-and-forget semantics (POST /capture → 202, in-memory queue, batch flush). This is a performance optimization, not a correctness requirement for Phase 0.

- [ ] [SPIKE] 8.1 — Research Go sidecar architecture — run `./loop.sh research go-sidecars` (see specifications/skills/tools/research.md)
  Covers: go.mod setup, cmd/runner and cmd/analytics entry points, Dockerfile.go multi-stage build, integration with docker-compose.yml
  Blocks: 8.2, 8.3, 8.4

- [ ] 8.2 — Initialize Go module and analytics ingest sidecar (`go/go.mod`, `go/cmd/analytics/main.go`, `infra/Dockerfile.go`)
  Required tests: POST /capture returns 202, events flushed to Postgres within 5s or 100 events, buffers in memory on Postgres unavailability
  Blocked by: 8.1

- [ ] 8.3 — Initialize Go runner sidecar (`go/cmd/runner/main.go`)
  Required tests: accepts run dispatch requests, returns results
  Blocked by: 8.1

- [ ] 8.4 — Initialize Go reference graph parser CLI (`go/cmd/parser/main.go`)
  Required tests: parses spec files, LEDGER.jsonl, git log; produces deterministic JSON graph
  Blocked by: 8.1

- [ ] 8.5 — Uncomment and wire Go sidecar services in docker-compose.yml (`infra/docker-compose.yml`)
  Required tests: `docker compose config` validates, all services start
  Blocked by: 8.2, 8.3

### Section 9 — Proposed Specs (status: proposed — not blocking Phase 0)

These specs have status `proposed` and are not required for Phase 0 completion. Listed for completeness.

- [ ] ~~9.1 — Analytics Dashboard UI (`specifications/system/analytics-dashboard-ui.md`)~~ — status: proposed, deferred
- [ ] ~~9.2 — Agent Runs UI (`specifications/system/agent-runs-ui.md`)~~ — status: proposed, deferred
- [ ] ~~9.3 — Log Tail Relay (`specifications/system/log-tail-relay.md`)~~ — status: proposed, deferred
- [ ] ~~9.4 — Repo Map CLI (`specifications/system/repo-map/concept.md`)~~ — status: draft, requires Go infrastructure, deferred

### Section 10 — Phase Advancement

- [ ] 10.1 — Advance to Phase 1: all Phase 0 acceptance criteria passing, `docker compose up` starts all services, `docker compose run test` passes full suite, no placeholder values in infra files
  Blocked by: all Section 1–7 tasks complete

## Task Dependency Order

```
1.1 (bug fix — no dependencies)
  ↓
2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6 (rswag install then conversions)
  ↓
3.1 (batch middleware — independent)
  ↓
4.1, 4.2 (reference graph — independent)
  ↓
5.1 → 5.2, 5.3 (agent runner — 5.1 first, then 5.2/5.3 parallel)
  ↓
6.1, 6.2 (analytics filters — independent)
  ↓
7.3, 7.4 (infra — independent)
  ↓
8.1 → 8.2 → 8.3 → 8.4 → 8.5 (Go sidecars — sequential, spike first)
  ↓
10.1 (phase advancement — last)
```

Recommended build order: 1.1 → 2.1–2.6 → 3.1 → 4.1–4.2 → 5.1–5.3 → 6.1–6.2 → 7.3–7.4 → 8.1–8.5 → 10.1
