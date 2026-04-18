# IMPLEMENTATION_PLAN.md

Generated: 2026-04-18
Phase: 0 — Local (Docker Compose only)
Scope: Phase 0 MVP per `specifications/project-requirements.md`

## Completed Work (discovered from code + git)

The following is implemented and tested (270 examples, 0 failures, 99.21% coverage as of tag 0.0.57):

- **Infrastructure:** `infra/Dockerfile`, `infra/Dockerfile.test`, `infra/docker-compose.yml`, `infra/docker-compose.test.yml`, entrypoints, pgvector/pg16
- **Auth:** `AuthToken` (JWT encode/decode), `Secret` value object, `ApplicationController#authenticate!`, sidecar auth (`X-Sidecar-Token`), `Api::AuthController` (POST /api/auth/token), dev bypass (DISABLE_AUTH)
- **Security:** `Security::PromptSanitizer`, `Security::LogRedactor`, `filter_parameters`, `rack-attack` rate limiting
- **Agents module:** `AgentRun` model (modes, statuses, validations, unique run_id), `AgentRunTurn` model (kinds, purged_at), `ProviderAdapter` base + `ClaudeAdapter` / `KiroAdapter` / `OpenAiAdapter` (build_prompt with pinned+sliding trimming, parse_response normalised hash), `PromptDeduplicator`, `RunStorageService` (start/complete/record_input, dedup, concurrent run check), `AgentRunsController` (start/complete/input endpoints), `AgentRunJob` (Solid Queue, turn reconstruction, pause/resume), `TurnContentGcJob` (30-day retention, skips failed/waiting)
- **Sandbox module:** `ContainerRun` model (statuses, duration_ms, optional agent_run), `DockerDispatcher` (argument array, Secret filtering, timeout, record creation)
- **Analytics module:** `AnalyticsEvent` (append-only), `AuditEvent` (append-only, severities), `LlmMetric` (append-only), `FeatureFlag` (enabled?, auto-fires $feature_flag_called, archived returns false), `AuditLogger` (async, never raises), `AuditLogJob`, `MetricsController` (llm/loops/summary/events/flag_stats), `FeatureFlagsController` (index/create/update)
- **Health check:** `HealthCheckMiddleware` at position 0, GET /health → 200/503
- **Ledger/Knowledge removal:** Tables dropped, FKs replaced with source_ref string
- **Reference graph partial:** `LedgerAppender`, `scripts/controlled-commit.sh`
- **Module scaffold:** Namespace resolution, LOOKUP.md files

## Spec Contradictions & Ambiguities

1. **FeatureFlagExposure model:** Rails platform override (`product/analytics.md`) references `Analytics::FeatureFlagExposure` model and `feature_flag_exposures` table. However, the current implementation fires `$feature_flag_called` as an `AnalyticsEvent` — no separate model exists. The feature-flags requirements say exposure events go through the analytics ingest. **Resolution:** The AnalyticsEvent approach is correct for Phase 0. FeatureFlagExposure as a separate model is speculative generality — the AnalyticsEvent already captures the same data. Flag for review if query performance on exposures becomes an issue.

2. **FeatureFlag metadata.hypothesis:** `feature-flags/concept.md` says "optional in Phase 0", `product/analytics.md` says "required on creation → 422 if missing". The requirements file says "not required in Phase 0". **Resolution:** Follow requirements — optional in Phase 0.

3. **Batch request middleware:** `specifications/system/batch-requests.md` exists but has no requirements file and no acceptance criteria tied to a specific phase. It's a proposed feature. **Resolution:** Include as a task since it's a defined spec, but lower priority.

---

## Section 1 — Infrastructure Gaps

- [x] Dockerfile, docker-compose.yml, docker-compose.test.yml — all exist and functional
- [x] Postgres pgvector/pg16 — configured
- [x] Health check middleware — implemented

### 1.1 Docker Compose: uncomment Go sidecar stubs or remove them
The spec (`infrastructure/concept.md`) defines `go_runner` (port 8080) and `analytics` sidecar (port 9100) in the compose file. They are currently commented out. The `go/` directory does not exist. These sidecars are Go binaries — they cannot be built until `go/` exists.

- [ ] 1.1 — Remove or annotate commented Go sidecar stubs in `infra/docker-compose.yml` with explicit "Phase 0: Go sidecars not yet built" comments (`infra/docker-compose.yml`)
  Required tests: `docker compose config` validates without errors

### 1.2 Postgres port binding
Spec says "Postgres is never bound to 0.0.0.0 — internal network only." Current compose file does not expose postgres ports externally — **compliant**. No task needed.

### 1.3 Image tags
Spec says "always git SHA, never latest." Dev compose uses `${GIT_SHA:-dev}` — acceptable for Phase 0 local dev. Test compose has no image tag (builds inline). **Compliant for Phase 0.**

---

## Section 2 — Agents Module Gaps

- [x] AgentRun model, AgentRunTurn model
- [x] ProviderAdapter + 3 adapters (build_prompt, parse_response)
- [x] PromptDeduplicator, RunStorageService
- [x] AgentRunsController (start/complete/input)
- [x] AgentRunJob (turn reconstruction, pause/resume)
- [x] TurnContentGcJob

### 2.1 Solid Queue concurrency key not wired
`AgentRunJob.concurrency_key_for` exists as a class method but is not connected to Solid Queue's `limits_concurrency` DSL. The spec requires "one active run per agent config at a time, enforced via solid_queue concurrency key on source_ref." Currently, concurrent runs are only checked at the service layer (RunStorageService), not at the job queue level.

- [ ] 2.1 — Wire `limits_concurrency` in `AgentRunJob` using Solid Queue DSL (`web/app/modules/agents/jobs/agent_run_job.rb`)
  Required tests: job declares `limits_concurrency` with key from `concurrency_key_for`, second job for same source_ref is blocked (not run in parallel)

### 2.2 call_provider not implemented on concrete adapters
All three adapters inherit `call_provider` from the base class which raises `NotImplementedError`. The spec requires adapters to make HTTP calls to provider APIs. AgentRunJob calls `adapter.call_provider(prompt)`.

- [ ] 2.2 — Implement `call_provider` on `ClaudeAdapter`, `KiroAdapter`, `OpenAiAdapter` with HTTP calls to provider APIs (`web/app/modules/agents/services/claude_adapter.rb`, `kiro_adapter.rb`, `open_ai_adapter.rb`)
  Required tests: each adapter makes HTTP POST to correct provider URL, passes correct headers (API key via Secret), returns raw response hash, handles HTTP errors gracefully (returns error hash, does not raise)
  Required threat tests: API key never appears in logs or error messages

### 2.3 agent_override flag missing
Spec requires `AgentRun` to accept `agent_override: boolean` — when true, enrichment tools are skipped. No column exists, no logic implemented.

- [ ] 2.3 — Add `agent_override` boolean column to `agents_agent_runs` and skip enrichment when true (`web/db/migrate/`, `web/app/modules/agents/models/agent_run.rb`, `web/app/modules/agents/jobs/agent_run_job.rb`)
  Required tests: AgentRun accepts agent_override, AgentRunJob skips enrichment tools when agent_override is true, callable tools still passed when agent_override is true

### 2.4 LlmMetric not created on run completion
`AgentRunsController#complete` updates the run and logs an audit event, but never creates an `Analytics::LlmMetric` record. The spec requires per-run cost/token recording in LlmMetric.

- [ ] 2.4 — Create `Analytics::LlmMetric` record when an agent run completes (`web/app/modules/agents/controllers/agent_runs_controller.rb` or `web/app/modules/agents/services/run_storage_service.rb`)
  Required tests: completing a run creates an LlmMetric with correct provider, model, tokens, cost_estimate_usd, agent_run_id, org_id

### 2.5 Skill frontmatter parsing + assembly pipeline
The spec defines a 7-step assembly pipeline: load instruction body, retrieve context from practices files, load principles, run enrichment tools, wrap with prompt_template, compute prompt_sha256, check dedup. Currently, `AgentRunJob` passes empty arrays for `context_chunks` and `principles`. No skill file parsing exists.

- [ ] [SPIKE] 2.5 — Research skill frontmatter parsing and assembly pipeline — run `./loop.sh research skill-assembly` (see specifications/skills/tools/research.md)
  Blocks: 2.6

- [ ] 2.6 — Implement skill frontmatter parsing and assembly pipeline (`web/app/modules/agents/services/skill_assembler.rb`, `web/app/modules/agents/jobs/agent_run_job.rb`)
  Depends on: 2.5
  Required tests: parses YAML frontmatter from skill file, loads context_chunks from declared practices files, loads principles, computes prompt_sha256 from assembled content, enrichment tools run before first LLM call and results appear as tool_result turns

### 2.6b AgentRunsController: org_id scoping on set_agent_run
`set_agent_run` uses `AgentRun.find(params[:id])` without scoping to `current_org_id`. Cross-org access is possible.

- [x] 2.6b — Scope `set_agent_run` to `current_org_id` in `AgentRunsController` (`web/app/modules/agents/controllers/agent_runs_controller.rb`)
  Required tests: complete/input for a run belonging to a different org returns 404
  Required threat tests: cross-org agent run access returns 404

---

## Section 3 — Sandbox Module Gaps

- [x] ContainerRun model
- [x] DockerDispatcher (dispatch, timeout, secret filtering, record creation)

### 3.1 DockerDispatcher missing agent_run_id parameter
The spec says `agent_run_id` is an FK on ContainerRun. `DockerDispatcher#dispatch` accepts `org_id` but not `agent_run_id`. ContainerRun records are created without linking to the triggering agent run.

- [ ] 3.1 — Add `agent_run_id` parameter to `DockerDispatcher#dispatch` and pass it to `ContainerRun.create!` (`web/app/modules/sandbox/services/docker_dispatcher.rb`)
  Required tests: dispatch with agent_run_id creates ContainerRun linked to the agent run, dispatch without agent_run_id creates ContainerRun with nil agent_run_id

### 3.2 DockerDispatcher missing security flags
Spec requires containers to run "non-root, no `--privileged`". Current `build_args` does not pass `--user` or security flags.

- [ ] 3.2 — Add `--user` and `--security-opt=no-new-privileges` flags to `DockerDispatcher#build_args` (`web/app/modules/sandbox/services/docker_dispatcher.rb`)
  Required tests: docker command includes `--user` flag, docker command does not include `--privileged`

---

## Section 4 — Analytics Module Gaps

- [x] AnalyticsEvent, AuditEvent, LlmMetric, FeatureFlag models
- [x] AuditLogger, AuditLogJob
- [x] MetricsController (llm/loops/summary/events/flag_stats)
- [x] FeatureFlagsController (index/create/update)

### 4.1 FeatureFlagsController: org_id not set from auth on create
`create_params` permits `:org_id` from the request body. The org_id should come from the authenticated user's token (`current_org_id`), not from the request body — otherwise a client can create flags for any org.

- [ ] 4.1 — Set `org_id` from `current_org_id` in `FeatureFlagsController#create`, remove `:org_id` from `create_params` (`web/app/modules/analytics/controllers/feature_flags_controller.rb`)
  Required tests: creating a flag uses org_id from JWT, not from request body
  Required threat tests: cannot create a flag for a different org by passing org_id in body

### 4.2 MetricsController: events endpoint missing org_id scoping note
The events endpoint correctly scopes to `current_org_id`. **Compliant.** No task needed.

### 4.3 AnalyticsEvent: PII redaction on properties
Spec requires "properties filtered through PII redaction before storage." No redaction exists on AnalyticsEvent creation.

- [ ] 4.3 — Add PII redaction callback on `AnalyticsEvent` before create that scrubs known PII patterns from `properties` (`web/app/modules/analytics/models/analytics_event.rb`)
  Required tests: email addresses in properties are redacted before save, phone numbers in properties are redacted before save, non-PII properties are preserved

---

## Section 5 — Auth Gaps

- [x] AuthToken (encode/decode/secret)
- [x] Secret value object
- [x] ApplicationController#authenticate!
- [x] Api::AuthController
- [x] Sidecar auth (X-Sidecar-Token)

### 5.1 Route protection audit
Spec requires "every route is explicitly public or authenticated — no route is accidentally unprotected." Current routes: `/up` (public, Rails health), `/health` (public, middleware), `/api/auth/token` (public). All other routes go through controllers with `before_action :authenticate!`. **Compliant.**

No tasks needed for auth.

---

## Section 6 — API Documentation (rswag)

Spec requires rswag for OpenAPI docs at `/api/docs`, request specs using rswag DSL, and `rake rswag:specs:swaggerize` as a build gate.

### 6.1 Install rswag gems
rswag is not in the Gemfile. No swagger files exist. No rswag initializer exists.

- [ ] 6.1 — Add rswag gems to Gemfile, download to vendor/cache, install, generate initializer and swagger_helper (`web/Gemfile`, `web/Gemfile.lock`, `web/vendor/cache/`, `web/config/initializers/rswag.rb`, `web/spec/swagger_helper.rb`)
  Required tests: `rake rswag:specs:swaggerize` exits 0, GET /api/docs returns 200

### 6.2 Convert existing request specs to rswag DSL
Existing request specs (`spec/requests/agents/agent_runs_spec.rb`, `spec/requests/api/auth_spec.rb`, `spec/requests/analytics/feature_flags_spec.rb`, `spec/requests/analytics/metrics_spec.rb`) use plain RSpec. They need to be converted to rswag DSL so they generate OpenAPI documentation.

- [ ] 6.2 — Convert `spec/requests/api/auth_spec.rb` to rswag DSL (`web/spec/requests/api/auth_spec.rb`)
  Depends on: 6.1
  Required tests: spec passes, `rake rswag:specs:swaggerize` includes auth endpoint

- [ ] 6.3 — Convert `spec/requests/agents/agent_runs_spec.rb` to rswag DSL (`web/spec/requests/agents/agent_runs_spec.rb`)
  Depends on: 6.1
  Required tests: spec passes, `rake rswag:specs:swaggerize` includes agent_runs endpoints

- [ ] 6.4 — Convert `spec/requests/analytics/feature_flags_spec.rb` to rswag DSL (`web/spec/requests/analytics/feature_flags_spec.rb`)
  Depends on: 6.1
  Required tests: spec passes, `rake rswag:specs:swaggerize` includes feature_flags endpoints

- [ ] 6.5 — Convert `spec/requests/analytics/metrics_spec.rb` to rswag DSL (`web/spec/requests/analytics/metrics_spec.rb`)
  Depends on: 6.1
  Required tests: spec passes, `rake rswag:specs:swaggerize` includes metrics endpoints

---

## Section 7 — Batch Request Middleware

Spec: `specifications/system/batch-requests.md`. No requirements file exists. Proposed feature.

- [ ] 7.1 — Implement `BatchRequestMiddleware` for `POST /api/batch` (`web/app/middleware/batch_request_middleware.rb`, `web/config/application.rb`, `web/config/routes.rb`)
  Required tests: fans out sub-requests and returns aggregated responses, respects max batch size (422 on exceed), individual sub-request failures don't fail the batch, malformed JSON returns 422, sub-requests share auth context, responses ordered to match requests

---

## Section 8 — Reference Graph (Phase 0 scope only)

The reference graph spec (`specifications/system/reference-graph/concept.md`) defines 7 components. Phase 0 scope is limited to what's buildable without Go and without CI.

- [x] Controlled commit skill (`scripts/controlled-commit.sh`)
- [x] LedgerAppender

### 8.1 Go reference parser
The reference parser is a standalone Go binary. The `go/` directory does not exist. This is a significant piece of work requiring Go project setup.

- [ ] [SPIKE] 8.1 — Research Go reference parser architecture and file walking strategy — run `./loop.sh research reference-parser` (see specifications/skills/tools/research.md)
  Blocks: 8.2

- [ ] 8.2 — Bootstrap `go/` directory with `go.mod`, `cmd/parser/main.go` skeleton, and Dockerfile.go (`go/go.mod`, `go/cmd/parser/main.go`, `infra/Dockerfile.go`)
  Depends on: 8.1
  Required tests: `go build ./cmd/parser` succeeds, parser accepts a project root path argument

- [ ] 8.3 — Implement reference parser: walk spec files, parse frontmatter and links, produce JSON graph (`go/cmd/parser/`)
  Depends on: 8.2
  Required tests: parser produces deterministic JSON from test fixtures, spec files appear as nodes, markdown links appear as edges, IMPLEMENTATION_PLAN.md items parsed with status and blocked-by

- [ ] 8.4 — Implement reference parser: LEDGER.jsonl parsing and PR node reconstruction (`go/cmd/parser/`)
  Depends on: 8.3
  Required tests: status events parsed, PR events produce PR nodes with edges to commits/tasks/specs, git log integration produces commit nodes

### 8.5 Go analytics ingest sidecar
Spec requires a Go sidecar at port 9100 for `POST /capture` with in-memory queue and batch flush.

- [ ] [SPIKE] 8.5 — Research Go analytics ingest sidecar design — run `./loop.sh research analytics-ingest` (see specifications/skills/tools/research.md)
  Blocks: 8.6

- [ ] 8.6 — Implement Go analytics ingest sidecar (`go/cmd/analytics/main.go`)
  Depends on: 8.5
  Required tests: POST /capture returns 202 immediately, events flushed to Postgres within 5s or 100 events, events buffered in memory on Postgres unavailability, internal network only

### 8.7 Go runner sidecar
Spec requires a Go runner sidecar at port 8080. This is the agent execution sidecar.

- [ ] [SPIKE] 8.7 — Research Go runner sidecar scope and interface — run `./loop.sh research runner-sidecar` (see specifications/skills/tools/research.md)
  Blocks: 8.8

- [ ] 8.8 — Implement Go runner sidecar (`go/cmd/runner/main.go`)
  Depends on: 8.7
  Required tests: sidecar starts on port 8080, accepts run requests, calls back to Rails on completion with X-Sidecar-Token

---

## Section 9 — Spec Reference Tags in Tests

Spec requires `spec:` metadata tags in RSpec files linking tests to spec sections. No tests currently use this convention.

- [ ] 9.1 — Add `spec:` metadata tags to existing RSpec files linking to relevant spec sections (`web/spec/**/*_spec.rb`)
  Required tests: at least one spec per module uses `spec:` tag, tags reference valid spec file paths

---

## Section 10 — UI Views (proposed specs)

Three proposed UI specs exist: `agent-runs-ui.md`, `analytics-dashboard-ui.md`, and reference-graph web UI (component 5 in reference-graph/concept.md). All require server-rendered HTML (ERB). No views directory exists.

- [ ] 10.1 — Create `web/app/views/` directory structure and application layout (`web/app/views/layouts/application.html.erb`)
  Required tests: layout renders without error

- [ ] 10.2 — Implement Agent Runs UI: run history list and run detail views (`web/app/views/agent_runs/`, `web/app/controllers/agent_runs_controller.rb` or new HTML controller, `web/config/routes.rb`)
  Required tests: GET /agent_runs returns 200 with paginated list, GET /agent_runs/:id returns 200 with turn content, filterable by mode and status

- [ ] 10.3 — Implement Analytics Dashboard UI: summary cards, cost by provider, recent runs (`web/app/views/analytics/`, `web/app/controllers/analytics/dashboard_controller.rb`, `web/config/routes.rb`)
  Required tests: GET /analytics returns 200 with summary data, GET /analytics/llm returns 200 with cost breakdown

---

## Section 11 — Recurring Jobs Configuration

### 11.1 TurnContentGcJob recurring schedule
`config/recurring.yml` defines the GC job only for production. It should also run in development for local testing.

- [ ] 11.1 — Add development schedule for `TurnContentGcJob` in `config/recurring.yml` (`web/config/recurring.yml`)
  Required tests: recurring.yml is valid YAML, development section includes turn_content_gc

---

## Section 12 — Cross-Cutting Gaps

### 12.1 SimpleCov coverage floor
Spec requires 85% minimum coverage enforced by SimpleCov. Need to verify SimpleCov is configured with a floor.

- [ ] 12.1 — Configure SimpleCov with 85% minimum coverage floor in `spec/spec_helper.rb` (`web/spec/spec_helper.rb`)
  Required tests: SimpleCov configured, minimum_coverage set to 85

### 12.2 Lograge structured logging
Lograge is installed and configured. **Compliant.** No task needed.

---

## Task Dependency Order

```
Independent (can start immediately):
  1.1, 2.1, 2.3, 2.4, 2.6b, 3.1, 3.2, 4.1, 4.3, 6.1, 9.1, 10.1, 11.1, 12.1

After 6.1:
  6.2, 6.3, 6.4, 6.5

After spike 2.5:
  2.6

After spike 8.1:
  8.2 → 8.3 → 8.4

After spike 8.5:
  8.6

After spike 8.7:
  8.8

After 10.1:
  10.2, 10.3

Standalone (no blockers, lower priority):
  2.2 (call_provider — requires provider API keys in env)
  7.1 (batch middleware — proposed spec, no requirements file)
```

## Priority Order (recommended build sequence)

1. **Security fixes first:** 2.6b (cross-org access), 4.1 (org_id from auth)
2. **Data integrity:** 2.4 (LlmMetric on complete), 3.1 (agent_run_id linking)
3. **Spec compliance:** 2.1 (SQ concurrency), 2.3 (agent_override), 3.2 (container security flags), 4.3 (PII redaction)
4. **API docs:** 6.1 → 6.2–6.5
5. **Coverage:** 12.1 (SimpleCov floor)
6. **Spikes:** 2.5, 8.1, 8.5, 8.7
7. **Go sidecars:** 8.2–8.4, 8.6, 8.8
8. **UI:** 10.1–10.3
9. **Lower priority:** 1.1, 7.1, 9.1, 11.1
