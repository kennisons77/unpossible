# IMPLEMENTATION_PLAN.md — Unpossible

**Phase:** 0 (Local — Docker Compose only)
**Generated:** 2026-04-17
**Source of truth:** specs/ + web/ + go/ code state

## Scope

Phase 0 only. No CI, no k8s, no staging, no production config.
Ledger and Knowledge modules are **superseded** by `specs/system/reference-graph/spec.md` — all ledger/knowledge code has been removed. No tasks reference those modules.

## Completed Work (discovered from code)

The following are implemented and tested (169 examples, 0 failures, 98.68% coverage as of tag 0.0.43):

- [x] Rails 8 skeleton with module autoloading (`web/config/application.rb`)
- [x] Secret value object (`web/app/lib/secret.rb`) — redacts in inspect/to_s/as_json, .expose returns raw
- [x] AuthToken JWT encode/decode (`web/app/lib/auth_token.rb`) — HS256, 24h TTL
- [x] ApplicationController authenticate! with JWT + sidecar token + dev bypass
- [x] POST /api/auth/token endpoint (`web/app/controllers/api/auth_controller.rb`)
- [x] Security: PromptSanitizer, LogRedactor (`web/app/lib/security/`)
- [x] Rack::Attack rate limiting (`web/config/initializers/rack_attack.rb`)
- [x] Lograge structured logging (`web/config/initializers/lograge.rb`)
- [x] Agents::AgentRun model with validations, modes, statuses
- [x] Agents::AgentRunTurn model with kinds, purged_at
- [x] Agents::ProviderAdapter + ClaudeAdapter + KiroAdapter + OpenAiAdapter
- [x] Agents::PromptDeduplicator — SHA256 + mode lookup within 24h
- [x] Agents::RunStorageService — start (with dedup + concurrency check), complete, record_input
- [x] Agents::AgentRunsController — POST start/complete/input with auth
- [x] Sandbox::ContainerRun model with status enum, duration_ms
- [x] Sandbox::DockerDispatcher — shells out to docker run --rm, secret filtering, timeout
- [x] Analytics::FeatureFlag model — enabled?, archived returns false, unique key per org
- [x] Analytics::FeatureFlagsController — CRUD with auth
- [x] Analytics::AnalyticsEvent model — append-only, validations, node_id column
- [x] Analytics::AuditEvent model — append-only, severity enum
- [x] HealthCheckMiddleware — GET /health at position 0, SELECT 1, 200/503
- [x] Ledger + Knowledge module removal (migrations, code, tests all cleaned up)
- [x] AgentRun FK migration — actor_id/node_id removed, source_ref added
- [x] Solid Queue configured as ActiveJob adapter
- [x] filter_parameters includes all sensitive keys
- [x] Infra: Dockerfile (ruby:3.3-slim), Dockerfile.test (ruby:3.3)
- [x] Infra: docker-compose.yml (rails + postgres), docker-compose.test.yml (test + postgres)
- [x] Module scaffold spec verifying directory structure
- [x] MarkdownHelper with syntax highlighting (redcarpet + rouge)

## Open Tasks

### Section 1 — Infrastructure Gaps (High Priority)

- [ ] 1.1 — Uncomment and configure go_runner service in docker-compose.yml (`infra/docker-compose.yml`)
  Spec: `specs/system/infrastructure/spec.md` — Phase 0 requires go_runner on port 8080
  **Blocked by:** 6.1 (Go runner sidecar must exist first)
  Required tests: `docker compose up` starts go_runner, port 8080 reachable on internal network

- [ ] 1.2 — Uncomment and configure analytics sidecar service in docker-compose.yml (`infra/docker-compose.yml`)
  Spec: `specs/system/infrastructure/spec.md` — Phase 0 requires analytics sidecar on port 9100
  **Blocked by:** 7.1 (Go analytics sidecar must exist first)
  Required tests: `docker compose up` starts analytics sidecar, port 9100 reachable on internal network

### Section 2 — Multi-tenancy: Missing org_id Columns

- [x] 2.1 — Add org_id to agents_agent_runs table (`web/db/migrate/`, `web/app/modules/agents/models/agent_run.rb`)
  Spec: `specs/practices/multi-tenancy.md` — "org_id on every table from day one"; `specs/project-prd.md` — "org_id present on all records"
  Required tests: AgentRun validates org_id presence, factory includes org_id, request specs pass org_id from JWT

- [x] 2.2 — Add org_id to sandbox_container_runs table (`web/db/migrate/`, `web/app/modules/sandbox/models/container_run.rb`)
  Spec: `specs/practices/multi-tenancy.md`
  Required tests: ContainerRun validates org_id presence, factory includes org_id

### Section 3 — Analytics Module: Missing Components

- [x] 3.1 — Create Analytics::LlmMetric model (`web/db/migrate/`, `web/app/modules/analytics/models/llm_metric.rb`, `web/spec/models/analytics/llm_metric_spec.rb`)
  Spec: `specs/platform/rails/system/analytics.md` — per agent run cost/token record, cost_estimate_usd decimal(10,6), index on (org_id, provider, model, created_at)
  Required tests: validates org_id/provider/model presence, cost_estimate_usd stored as decimal(10,6), index exists, append-only enforcement

- [x] 3.2 — Create Analytics::AuditLogger service (`web/app/modules/analytics/services/audit_logger.rb`, `web/spec/modules/analytics/services/audit_logger_spec.rb`)
  Spec: `specs/platform/rails/system/analytics.md` — `AuditLogger.log(...)` async, never raises, fire-and-forget
  Required tests: AuditLogger.log creates AuditEvent, failure logs to Rails logger without raising, enqueues on analytics queue

- [x] 3.3 — Create Analytics::AuditLogJob (`web/app/modules/analytics/jobs/audit_log_job.rb`, `web/spec/jobs/analytics/audit_log_job_spec.rb`)
  Spec: `specs/platform/rails/system/analytics.md` — Active Job on `analytics` queue
  Required tests: job enqueues on analytics queue, creates AuditEvent record, handles errors without raising

- [x] 3.4 — Create Analytics::MetricsController with LLM, loops, and summary endpoints (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/spec/requests/analytics/metrics_spec.rb`, `web/config/routes.rb`)
  Spec: `specs/system/analytics/spec.md` — GET /api/analytics/llm, /loops, /summary; `specs/platform/rails/system/analytics.md` — JWT auth required
  Required tests: GET /api/analytics/llm returns cost by provider/model filterable by date, GET /api/analytics/loops returns run counts/failure rates by mode, GET /api/analytics/summary returns weekly totals, all return 401 without auth

- [ ] 3.5 — Add events and flags/:key endpoints to MetricsController (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/spec/requests/analytics/metrics_spec.rb`, `web/config/routes.rb`)
  Spec: `specs/system/analytics/spec.md` — GET /api/analytics/events (paginated, filterable), GET /api/analytics/flags/:key (exposure counts + conversion rates)
  Required tests: events endpoint paginates and filters by event_name/org_id/date, flags/:key returns exposure counts per variant, both return 401 without auth

- [ ] 3.6 — Auto-fire $feature_flag_called on FeatureFlag.enabled? (`web/app/modules/analytics/models/feature_flag.rb`, `web/spec/models/analytics/feature_flag_spec.rb`)
  Spec: `specs/system/analytics/spec.md` AC — "Feature flag evaluation automatically fires $feature_flag_called — no manual instrumentation"
  Note: In Phase 0 without the Go ingest sidecar, this should write directly to analytics_events or enqueue a job. The spec says fire-and-forget to the ingest endpoint, but the sidecar doesn't exist yet. Implement as a direct AnalyticsEvent.create (fail-open) until the sidecar is available.
  Required tests: FeatureFlag.enabled? creates a $feature_flag_called event with flag_key/variant/enabled, failure to create event does not raise

### Section 4 — Agent Runner: Missing Features

- [ ] 4.1 — AgentRunJob for Solid Queue execution (`web/app/modules/agents/jobs/agent_run_job.rb`, `web/spec/jobs/agents/agent_run_job_spec.rb`)
  Spec: `specs/system/agent-runner/spec.md` — "Job completes — no thread held", "Job resumes: reconstructs turn history"
  Required tests: job enqueues, calls provider adapter, records turns, handles pause/resume, concurrency key on source_ref

- [ ] 4.2 — Turn Content GC Job (`web/app/modules/agents/jobs/turn_content_gc_job.rb`, `web/spec/jobs/agents/turn_content_gc_job_spec.rb`, `web/config/recurring.yml`)
  Spec: `specs/system/agent-runner/spec.md` — "Background job purges turn content for completed runs older than N days (default: 30). Sets purged_at and clears content."
  Required tests: purges content on completed runs older than 30 days, sets purged_at, retains turn record, never purges failed or waiting_for_input runs, idempotent

- [ ] 4.3 — Complete endpoint calls AuditLogger (`web/app/modules/agents/controllers/agent_runs_controller.rb`)
  Spec: `specs/platform/rails/system/agents.md` — "Complete endpoint calls Analytics::AuditLogger"
  **Depends on:** 3.2
  Required tests: completing a run creates an audit event via AuditLogger

- [ ] 4.4 — Provider adapter build_prompt with pinned+sliding token budget (`web/app/modules/agents/services/provider_adapter.rb`, adapters)
  Spec: `specs/system/agent-runner/spec.md` — "build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)" with pinned+sliding strategy
  Note: Current adapters have a simplified build_prompt(messages) signature. The spec requires a richer interface with token budget management.
  Required tests: always includes system prompt + agent_question + human_input turns, trims llm_response/tool_result from oldest, aborts with RALPH_WAITING if still over budget after trimming

### Section 5 — Batch Request Middleware

- [ ] 5.1 — Batch request Rack middleware (`web/app/middleware/batch_request_middleware.rb`, `web/spec/middleware/batch_request_middleware_spec.rb`, `web/config/application.rb`)
  Spec: `specs/system/batch-requests.md` — POST /api/batch fans out sub-requests internally, returns aggregated responses
  Required tests: fans out sub-requests through full Rack stack, responses ordered (response[i] = request[i]), individual failures captured (not abort batch), max batch size enforced (422), malformed JSON returns 422, inherits auth from outer request

### Section 6 — Go Runner Sidecar

- [ ] 6.1 — [SPIKE] Research Go runner sidecar implementation — run `./loop.sh research go-runner` (see specs/skills/tools/research.md)
  Spec: `specs/platform/go/system/runner.md` — POST /run with Basic Auth, mutex, token parsing, callback to Rails
  Note: No Go code exists in the repo. This spike must determine: directory structure (runner/ vs go/runner/), build tooling, test approach, and how to integrate with the existing Docker Compose stack. The spec references `runner/main.go`.
  **Blocks:** 1.1, 6.2

- [ ] 6.2 — Build Go runner sidecar (`runner/main.go`, `runner/go.mod`, `infra/Dockerfile.runner`)
  Spec: `specs/platform/go/system/runner.md`
  **Depends on:** 6.1
  Required tests: go test ./... exits 0, POST /run without Basic Auth → 401, concurrent POST /run → 409, calls Rails complete endpoint after loop exits, token counts parsed from stream-json stdout, GET /healthz returns 200, GET /ready returns 200, GET /metrics returns Prometheus text

### Section 7 — Go Analytics Sidecar

- [ ] 7.1 — [SPIKE] Research Go analytics sidecar implementation — run `./loop.sh research go-analytics` (see specs/skills/tools/research.md)
  Spec: `specs/platform/go/system/analytics.md` — POST /capture returns 202, in-memory queue, batch flush, PII filtering
  Note: No Go code exists. Same structural questions as 6.1.
  **Blocks:** 1.2, 7.2

- [ ] 7.2 — Build Go analytics sidecar (`analytics-sidecar/main.go`, `analytics-sidecar/go.mod`, `infra/Dockerfile.analytics`)
  Spec: `specs/platform/go/system/analytics.md`
  **Depends on:** 7.1
  Required tests: go test ./... exits 0, POST /capture returns 202 immediately, events flushed within 5s or 100 events, events buffered on Postgres unavailability, GET /healthz returns 200, non-UUID distinct_id rejected

### Section 8 — API Documentation (rswag)

- [ ] 8.1 — Set up rswag gem and Swagger UI (`web/Gemfile`, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`, `web/swagger/v1/swagger.yaml`)
  Spec: `specs/system/api/spec.md`, `specs/platform/rails/system/api-standards.md` — rswag for OpenAPI docs at /api/docs
  Note: rswag gem is not in Gemfile and no rswag config exists. Gems must be pre-downloaded to vendor/cache (no outbound network in Docker).
  Required tests: GET /api/docs returns 200 without auth, rake rswag:specs:swaggerize exits 0

- [ ] 8.2 — Convert existing request specs to rswag format (`web/spec/requests/`)
  Spec: `specs/platform/rails/system/api-standards.md` — "Written using rswag DSL — each example both tests the endpoint and contributes to the generated spec"
  **Depends on:** 8.1
  Required tests: all existing endpoints appear in swagger.yaml, rake rswag:specs:swaggerize exits 0

### Section 9 — Reference Graph (Priority Components for Phase 0)

- [ ] 9.1 — [SPIKE] Research reference graph controlled commit skill — run `./loop.sh research ref-graph-commit` (see specs/skills/tools/research.md)
  Spec: `specs/system/reference-graph/spec.md` § Controlled Commit Skill (Priority 1)
  Note: This is the foundational component — all other reference graph work depends on it. The spike should determine: skill file format, LEDGER.jsonl schema, atomic commit sequence, and integration with loop.sh.
  **Blocks:** 9.2, 9.3

- [ ] 9.2 — Create LEDGER.jsonl and controlled commit skill (`specs/skills/tools/commit.md`, `scripts/commit.sh` or equivalent)
  Spec: `specs/system/reference-graph/spec.md` § Controlled Commit Skill
  **Depends on:** 9.1
  Required tests: commit atomically updates code + LEDGER.jsonl + IMPLEMENTATION_PLAN.md, LEDGER.jsonl is append-only, entries are valid JSON, status transitions recorded with sha/reason

- [ ] 9.3 — [SPIKE] Research Go reference parser — run `./loop.sh research ref-graph-parser` (see specs/skills/tools/research.md)
  Spec: `specs/system/reference-graph/spec.md` § Go Reference Parser (Priority 2)
  Note: The parser is a standalone Go binary. Spike should determine: input parsing strategy (markdown frontmatter, LEDGER.jsonl, git log), output JSON schema, and how PR nodes are reconstructed from ledger events.
  **Depends on:** 9.1
  **Blocks:** 9.4

- [ ] 9.4 — Build Go reference parser (`go/parser/main.go`, `go/parser/go.mod`)
  Spec: `specs/system/reference-graph/spec.md` § Go Reference Parser
  **Depends on:** 9.3
  Required tests: go test ./... exits 0, deterministic output (same inputs → same JSON), parses spec files for frontmatter/headers/links, parses LEDGER.jsonl for status/blocked/unblocked/pr events, parses IMPLEMENTATION_PLAN.md for beat items, emits PR nodes from pr_opened/pr_review/pr_merged events, resolves git notes on merge commits

- [ ] 9.5 — PR skill for creating pull requests with graph metadata (`specs/skills/tools/pr.md`, `scripts/pr.sh` or equivalent)
  Spec: `specs/system/reference-graph/spec.md` § PR Events in LEDGER.jsonl
  **Depends on:** 9.2
  Required tests: creates PR via gh pr create, appends pr_opened event to LEDGER.jsonl with task_ids/spec_refs/sha range, pr_merged event appended on merge

### Section 10 — UI Views (Proposed Specs)

- [ ] 10.1 — Agent Runs UI — run history and detail views (`web/app/controllers/agent_runs_controller.rb`, `web/app/views/agent_runs/`, `web/config/routes.rb`, `web/spec/requests/agent_runs_ui_spec.rb`)
  Spec: `specs/system/agent-runs-ui.md` — GET /agent_runs (paginated list), GET /agent_runs/:id (detail with turns)
  Required tests: index renders paginated list with mode/status/tokens/cost, detail renders turns with kind badges, markdown content rendered, filters by mode and status, auth required (or DISABLE_AUTH bypass)

- [ ] 10.2 — Analytics Dashboard UI — summary and LLM metrics views (`web/app/controllers/analytics_dashboard_controller.rb`, `web/app/views/analytics/`, `web/config/routes.rb`, `web/spec/requests/analytics_dashboard_ui_spec.rb`)
  Spec: `specs/system/analytics-dashboard-ui.md` — GET /analytics (summary cards + recent runs), GET /analytics/llm (cost breakdown)
  **Depends on:** 3.1, 3.4
  Required tests: dashboard renders summary cards (total cost, total runs, failure rate), LLM page renders cost by provider/model, filterable by date range, auth required

- [ ] 10.3 — Reference Graph read-only web UI — current, open, condensed views (`web/app/controllers/reference_graph_controller.rb`, `web/app/views/reference_graph/`, `web/config/routes.rb`)
  Spec: `specs/system/reference-graph/spec.md` § Read-Only Web UI (Priority 5)
  **Depends on:** 9.4
  Required tests: current view renders in-progress beat + ancestor chain, open view lists non-closed items with filters, condensed view renders collapsible tree with text search, all server-rendered HTML, auth required

### Section 11 — Spec-Level Gaps and Cleanup

- [ ] 11.1 — Add spec: tags to existing RSpec files linking to spec sections (`web/spec/`)
  Spec: `specs/system/reference-graph/spec.md` § Spec Reference Tags in Tests (Priority 3)
  Required tests: spec: metadata present on describe blocks, references valid spec paths

- [ ] 11.2 — LOOKUP.md files for each module directory (`web/app/modules/agents/LOOKUP.md`, `web/app/modules/analytics/LOOKUP.md`, `web/app/modules/sandbox/LOOKUP.md`)
  Spec: `specs/practices/changeability.md` § LOOKUP.md Convention
  Note: `web/app/modules/LOOKUP.md` exists at the top level but individual module LOOKUP.md files are missing.
  Required tests: n/a (documentation only)

## Ambiguities and Notes

1. **FeatureFlag.enabled? auto-fire without Go sidecar:** The spec says `$feature_flag_called` is fired via the analytics ingest sidecar (Go, port 9100). The sidecar doesn't exist yet. Task 3.6 implements a direct-write fallback. When the sidecar lands (7.2), the fire mechanism should switch to HTTP POST to the sidecar.

2. **Provider adapter signature mismatch:** Current adapters implement `build_prompt(messages)` but the spec requires `build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)`. Task 4.4 addresses this. The existing simplified interface works for current callers but doesn't implement pinned+sliding trimming.

3. **rswag gem availability:** rswag gems must be downloaded to `web/vendor/cache/` before the Docker build. Task 8.1 includes this step.

4. **Ledger UI spec is superseded:** `specs/system/ledger/ui.md` is marked superseded. The reference graph web UI (10.3) replaces it with current/open/condensed views consuming the Go parser's JSON output.

5. **Knowledge module is superseded:** `specs/system/knowledge/` is marked superseded. No tasks reference it.

6. **Log Tail Relay:** `specs/system/log-tail-relay.md` is status: proposed with open questions. No tasks planned — it needs a decision on approach before implementation.

7. **Analytics Dashboard UI and Agent Runs UI** are status: proposed. Tasks 10.1 and 10.2 are included because the PRD says "Rails 8 full stack — not API-only; views needed for UI" and these are the only UI specs defined.

## Dependency Graph

```
6.1 (spike: go runner) → 6.2 (build runner) → 1.1 (uncomment compose)
7.1 (spike: go analytics) → 7.2 (build analytics) → 1.2 (uncomment compose)
3.2 (AuditLogger) → 4.3 (complete calls AuditLogger)
3.1 (LlmMetric) + 3.4 (MetricsController) → 10.2 (Analytics Dashboard UI)
8.1 (rswag setup) → 8.2 (convert specs)
9.1 (spike: commit skill) → 9.2 (commit skill) → 9.5 (PR skill)
9.1 → 9.3 (spike: parser) → 9.4 (build parser) → 10.3 (ref graph UI)
```

All other tasks are independent and can be worked in any order.
