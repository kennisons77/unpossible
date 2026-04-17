# IMPLEMENTATION_PLAN.md

**Phase:** 0 — Local (Docker Compose only)
**Generated:** 2026-04-17
**Scope:** Phase 0 tasks only. No CI, no staging, no production config.

## Completed Work (discovered from code + git)

The following is implemented and tested (254 examples, 0 failures, 99.19% coverage at tag 0.0.54):

- **Infrastructure:** Dockerfile (ruby:3.3-slim), Dockerfile.test, docker-compose.yml (rails + postgres), docker-compose.test.yml, entrypoint scripts, offline gem/deb install
- **Auth:** Secret value object, AuthToken (JWT HS256), ApplicationController#authenticate! with bearer + sidecar token, DISABLE_AUTH dev bypass, POST /api/auth/token
- **Security:** PromptSanitizer, LogRedactor, lograge, rack-attack, filter_parameters
- **Agents module:** AgentRun model (org_id, source_ref, modes, statuses), AgentRunTurn model (purged_at, content nullable), ProviderAdapter base + ClaudeAdapter + KiroAdapter + OpenAiAdapter (build_prompt with pinned+sliding trimming, TokenBudgetExceeded), PromptDeduplicator, RunStorageService (start/complete/record_input, concurrency check, dedup), AgentRunsController (start/complete/input), AgentRunJob (Solid Queue, pause/resume), TurnContentGcJob (recurring daily, 30-day retention)
- **Sandbox module:** ContainerRun model (org_id, status enum), DockerDispatcher (timeout, secret filtering, argument array)
- **Analytics module:** AnalyticsEvent (append-only), AuditEvent (append-only, severity enum), LlmMetric (append-only), FeatureFlag (enabled?, auto-fire $feature_flag_called, unique key per org), AuditLogger + AuditLogJob (async, fail-open), MetricsController (llm, loops, summary, events, flag_stats), FeatureFlagsController (index, create, update)
- **Health check:** HealthCheckMiddleware at position 0 (GET /health → SELECT 1)
- **Ledger + Knowledge removal:** Tables dropped, FKs replaced with source_ref string, migrations complete
- **Solid Queue:** queue.yml, recurring.yml, agents + analytics queues

## Spec-vs-Code Gap Analysis

### 1. Reference Graph (specs/system/reference-graph/spec.md) — NEW, SUPERSEDES LEDGER

The reference graph spec supersedes the ledger. Ledger removal is complete. The reference graph itself has 7 components with priorities 1–7. Phase 0 scope covers priorities 1–6 (priority 7 is a future spike).

**1.1 Controlled Commit Skill (Priority 1)** — NOT IMPLEMENTED
No LEDGER.jsonl exists. No controlled commit skill. The build loop currently uses raw git commits.

**1.2 Go Reference Parser (Priority 2)** — NOT IMPLEMENTED
No `go/` directory exists at all. The Go reference parser, runner sidecar, and analytics sidecar are all unbuilt.

**1.3 Spec Reference Tags in Tests (Priority 3)** — NOT IMPLEMENTED
No `spec:` metadata tags in any RSpec files.

**1.4 CI Drift Detection (Priority 4)** — OUT OF SCOPE (Phase 1)
CI is Phase 1 infrastructure. The drift detection mechanism depends on CI.

**1.5 Read-Only Web UI (Priority 5)** — NOT IMPLEMENTED
No views exist (`web/app/views/` is empty). No UI controllers for ledger/reference-graph views.

**1.6 Ledger + Knowledge Module Removal (Priority 6)** — DONE
Tables dropped, FKs removed, code removed. Migrations exist and are tested.

### 2. Go Sidecars (specs/platform/go/)

**2.1 Go Runner Sidecar** — NOT IMPLEMENTED
No `go/` directory. Spec requires: POST /run (Basic Auth, mutex), token parsing from Claude stream-json, callback to Rails, health/ready/metrics endpoints.

**2.2 Go Analytics Ingest Sidecar** — NOT IMPLEMENTED
No `go/` directory. Spec requires: POST /capture (202, no auth), in-memory queue, batch flush (5s/100 events), PII filtering, UUID validation on distinct_id, GET /healthz.

**2.3 Go Reference Parser CLI** — NOT IMPLEMENTED
No `go/` directory. Spec requires: standalone binary, walks files + git + LEDGER.jsonl, produces JSON graph.

### 3. Infrastructure Gaps

**3.1 docker-compose.yml: Go services commented out** — go_runner and analytics sidecars are commented out. They need to be uncommented once Go binaries are built.

**3.2 docker-compose.yml: Image tags** — Rails image uses `${GIT_SHA:-dev}` which is correct. Go images (when uncommented) also use `${GIT_SHA:-dev}` — correct.

**3.3 Dockerfile.go** — Does not exist. Required by infra spec for Go multi-stage build.

**3.4 Postgres port binding** — Postgres has no `ports:` section in either compose file — correct (internal only per spec).

### 4. API Documentation (specs/system/api/spec.md + platform/rails/system/api-standards.md)

**4.1 rswag not installed** — No rswag gems in Gemfile. No swagger_helper.rb. No swagger/ directory. No /api/docs endpoint.

**4.2 Request specs exist** but are not rswag-format. Current request specs cover happy path and some error cases but don't generate OpenAPI docs.

### 5. Feature Flags Gaps

**5.1 metadata.hypothesis validation** — Rails platform override says `FeatureFlag with missing metadata.hypothesis → 422`. Current code does NOT validate hypothesis on creation. The FeatureFlagsController#create_params permits `metadata: {}` but doesn't enforce hypothesis presence.

**5.2 FeatureFlag.enabled? fires event via AnalyticsEvent.create!** — This works but the spec says it should fire via the analytics ingest sidecar, not directly to Postgres. Phase 0 acceptable since the sidecar doesn't exist yet, but should be noted.

### 6. Agent Runner Gaps

**6.1 call_provider not implemented** — All three adapters have `call_provider` raising NotImplementedError. The AgentRunJob calls it but it will fail at runtime. The HTTP calls to providers are not wired.

**6.2 parse_response incomplete** — ClaudeAdapter and KiroAdapter parse `content[0].text`, OpenAiAdapter parses `choices[0].message.content`. These return just the text string, not the full `{text:, input_tokens:, output_tokens:, stop_reason:}` hash that the spec requires and AgentRunJob expects.

**6.3 Enrichment tools and callable tools** — Not implemented. Spec requires `enrich` tools run before first LLM call, `callable` tools passed to provider. No tool execution infrastructure exists.

**6.4 agent_override flag** — Not implemented on AgentRun model or in the job.

### 7. Analytics Gaps

**7.1 No node_id column on analytics_events** — Wait, checking... the migration DOES create a `node_id` string column with an index. ✓ Done.

### 8. Batch Request Middleware (specs/system/batch-requests.md)

**8.1 Not implemented** — No batch middleware exists. Spec requires POST /api/batch with fan-out.

### 9. UI Specs (proposed status)

**9.1 Analytics Dashboard UI** — NOT IMPLEMENTED. Status: proposed. Requires server-rendered HTML views.

**9.2 Agent Runs UI** — NOT IMPLEMENTED. Status: proposed. Requires server-rendered HTML views.

### 10. Log Tail Relay (specs/system/log-tail-relay.md)

**10.1 Not implemented** — Status: proposed. Open questions unresolved.

### 11. Practices Spec (specs/system/practices.md)

Describes loading strategy for practices files. This is agent configuration, not code — no implementation needed.

### 12. Multi-tenancy

**12.1 org_id present on all models** — ✓ Done (AgentRun, ContainerRun, AnalyticsEvent, AuditEvent, LlmMetric, FeatureFlag all have org_id).

---

## Open Questions & Spikes

| Spec | Open Question | Impact |
|---|---|---|
| reference-graph/spec.md | Agent title drift — stable_ref design | Blocks nothing in Phase 0 (stable_ref is a parser concern) |
| reference-graph/spec.md | LEDGER.jsonl growth over time | Low risk Phase 0 |
| reference-graph/spec.md | Plan item renumbering | Parser concern |
| reference-graph/spec.md | Git notes merge conflicts | Low risk solo dev |
| ledger/spec.md | SUPERSEDED — all open questions moot |
| knowledge/spec.md | SUPERSEDED — module removed |
| analytics/prd.md | Event retention policy | Phase 1 concern |
| log-tail-relay.md | Which approach? | Unresolved, proposed status |
| feature-flags/prd.md | metadata.hypothesis required on archive? | Post-MVP |

---

## Tasks

### Section 1: Reference Graph — Controlled Commit Skill

- [x] 1.1 — Create LEDGER.jsonl schema and append utility (`web/app/lib/ledger_appender.rb`)
  Required tests: appends valid JSON line, validates event types (status/blocked/unblocked/spec_changed/pr_opened/pr_review/pr_merged), file is append-only, idempotent on duplicate entries
  Files: `web/app/lib/ledger_appender.rb`, `spec/lib/ledger_appender_spec.rb`, `LEDGER.jsonl`

- [x] 1.2 — Create controlled commit skill script (`scripts/controlled-commit.sh`)
  Required tests: atomically stages code + LEDGER.jsonl + IMPLEMENTATION_PLAN.md, commits with structured message, fails atomically (nothing committed on error), appends status event to LEDGER.jsonl
  Files: `scripts/controlled-commit.sh`, test via shell script or integration spec

### Section 2: Go Bootstrap

- [ ] [SPIKE] 2.0 — Research Go project setup for multi-binary repo — run `./loop.sh research go-bootstrap`
  Context: No `go/` directory exists. Need to establish go.mod, cmd/ layout, internal/ packages, Dockerfile.go multi-stage build. The Go platform spec (`specs/platform/go/README.md`) defines the layout. This spike confirms build tooling and dependency management approach.

- [ ] 2.1 — Initialize Go module and directory structure (`go/go.mod`, `go/cmd/runner/`, `go/cmd/analytics/`, `go/cmd/parser/`, `go/internal/`)
  Blocked by: 2.0
  Required tests: `go build ./...` succeeds, directory structure matches spec
  Files: `go/go.mod`, `go/cmd/runner/main.go`, `go/cmd/analytics/main.go`, `go/cmd/parser/main.go`, `go/internal/`

- [ ] 2.2 — Create Dockerfile.go multi-stage build (`infra/Dockerfile.go`)
  Blocked by: 2.1
  Required tests: `docker build -f infra/Dockerfile.go .` succeeds, produces runner/analytics/parser binaries
  Files: `infra/Dockerfile.go`

### Section 3: Go Analytics Ingest Sidecar

- [ ] 3.1 — Implement POST /capture endpoint with 202 response (`go/cmd/analytics/main.go`)
  Blocked by: 2.1
  Required tests: POST /capture returns 202, accepts single event, accepts batch array, GET /healthz returns 200
  Files: `go/cmd/analytics/main.go`, `go/cmd/analytics/main_test.go`

- [ ] 3.2 — Implement in-memory queue and batch flush to Postgres (`go/internal/ingest/`)
  Blocked by: 3.1
  Required tests: events flushed within 5s or 100 events, events buffered on Postgres unavailability, no events dropped on brief outage
  Files: `go/internal/ingest/queue.go`, `go/internal/ingest/queue_test.go`, `go/internal/ingest/flusher.go`

- [ ] 3.3 — PII filtering and distinct_id UUID validation (`go/internal/ingest/`)
  Blocked by: 3.2
  Required tests: non-UUID distinct_id rejected, PII patterns redacted from properties before storage
  Files: `go/internal/ingest/pii.go`, `go/internal/ingest/pii_test.go`

- [ ] 3.4 — Uncomment analytics service in docker-compose.yml
  Blocked by: 3.3, 2.2
  Required tests: `docker compose up` starts analytics sidecar on port 9100, healthz responds
  Files: `infra/docker-compose.yml`

### Section 4: Go Runner Sidecar

- [ ] 4.1 — Implement POST /run with Basic Auth and mutex (`go/cmd/runner/main.go`)
  Blocked by: 2.1
  Required tests: POST /run without Basic Auth → 401, concurrent POST /run → 409, GET /healthz returns 200, GET /ready returns 200
  Files: `go/cmd/runner/main.go`, `go/cmd/runner/main_test.go`

- [ ] 4.2 — Token parsing from Claude stream-json stdout (`go/internal/runner/`)
  Blocked by: 4.1
  Required tests: parses input_tokens and output_tokens from stream-json output, handles malformed output gracefully
  Files: `go/internal/runner/tokenparser.go`, `go/internal/runner/tokenparser_test.go`

- [ ] 4.3 — Callback to Rails POST /api/agent_runs/:id/complete (`go/internal/runner/`)
  Blocked by: 4.1
  Required tests: calls Rails complete endpoint after loop exits (mock server), sends correct payload (tokens, cost, duration, exit_code)
  Files: `go/internal/runner/callback.go`, `go/internal/runner/callback_test.go`

- [ ] 4.4 — Prometheus metrics endpoint (`go/cmd/runner/main.go`)
  Blocked by: 4.1
  Required tests: GET /metrics returns Prometheus text format, runs_total/runs_failed_total/run_duration_seconds/current_runs present
  Files: `go/cmd/runner/main.go`

- [ ] 4.5 — Uncomment go_runner service in docker-compose.yml
  Blocked by: 4.4, 2.2
  Required tests: `docker compose up` starts runner sidecar on port 8080, healthz responds
  Files: `infra/docker-compose.yml`

### Section 5: Go Reference Parser

- [ ] [SPIKE] 5.0 — Research Go markdown/frontmatter parsing libraries — run `./loop.sh research go-parser`
  Context: Parser needs to walk spec files (markdown), IMPLEMENTATION_PLAN.md, test files (RSpec), LEDGER.jsonl, and git log. Need to identify Go libraries for markdown parsing, frontmatter extraction, and git log traversal.

- [ ] 5.1 — Implement file walker and LEDGER.jsonl parser (`go/cmd/parser/`, `go/internal/parser/`)
  Blocked by: 5.0, 2.1
  Required tests: parser is deterministic (same inputs → same output), parses LEDGER.jsonl events, walks spec files and extracts section headers
  Files: `go/cmd/parser/main.go`, `go/internal/parser/walker.go`, `go/internal/parser/ledger.go`

- [ ] 5.2 — Parse IMPLEMENTATION_PLAN.md for beat items with metadata (`go/internal/parser/`)
  Blocked by: 5.1
  Required tests: extracts task IDs, status, blocked-by refs, spec refs from plan items
  Files: `go/internal/parser/plan.go`, `go/internal/parser/plan_test.go`

- [ ] 5.3 — Parse spec: tags from RSpec files (`go/internal/parser/`)
  Blocked by: 5.1
  Required tests: extracts spec: metadata from RSpec describe/context blocks, produces edges in graph
  Files: `go/internal/parser/rspec.go`, `go/internal/parser/rspec_test.go`

- [ ] 5.4 — Git log and git notes integration (`go/internal/parser/`)
  Blocked by: 5.1
  Required tests: extracts commits with SHAs, parses git notes on merge commits, produces commit nodes
  Files: `go/internal/parser/git.go`, `go/internal/parser/git_test.go`

- [ ] 5.5 — PR node reconstruction from LEDGER.jsonl events (`go/internal/parser/`)
  Blocked by: 5.1
  Required tests: reconstructs PR nodes from pr_opened/pr_review/pr_merged events, links to commits/tasks/specs
  Files: `go/internal/parser/pr.go`, `go/internal/parser/pr_test.go`

- [ ] 5.6 — JSON graph output assembly (`go/internal/parser/`)
  Blocked by: 5.1, 5.2, 5.3, 5.4, 5.5
  Required tests: produces valid JSON graph with nodes and edges, blocked-by refs appear as dependency edges, spec: tags appear as ref edges
  Files: `go/internal/parser/graph.go`, `go/internal/parser/graph_test.go`

### Section 6: Agent Runner — Provider HTTP Calls

- [ ] 6.1 — Implement ClaudeAdapter#call_provider with HTTP call to Anthropic API (`web/app/modules/agents/services/claude_adapter.rb`)
  Required tests: makes POST to Anthropic messages endpoint, sends correct headers (x-api-key, anthropic-version), returns raw response hash, handles HTTP errors gracefully
  Required threat tests: API key never logged, API key wrapped in Secret
  Files: `web/app/modules/agents/services/claude_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`

- [ ] 6.2 — Implement OpenAiAdapter#call_provider with HTTP call to OpenAI API (`web/app/modules/agents/services/open_ai_adapter.rb`)
  Required tests: makes POST to OpenAI chat completions endpoint, sends correct headers (Authorization: Bearer), returns raw response hash, handles HTTP errors gracefully
  Required threat tests: API key never logged, API key wrapped in Secret
  Files: `web/app/modules/agents/services/open_ai_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`

- [ ] 6.3 — Fix parse_response to return full result hash `{text:, input_tokens:, output_tokens:, stop_reason:}` across all adapters
  Required tests: parse_response returns hash with all four keys, stop_reason correctly identifies agent_question vs end_turn
  Files: `web/app/modules/agents/services/claude_adapter.rb`, `web/app/modules/agents/services/open_ai_adapter.rb`, `web/app/modules/agents/services/kiro_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`

### Section 7: Feature Flag — metadata.hypothesis Validation

- [ ] 7.1 — Enforce metadata.hypothesis presence on FeatureFlag creation (`web/app/modules/analytics/controllers/feature_flags_controller.rb`, `web/app/modules/analytics/models/feature_flag.rb`)
  Required tests: POST /api/feature_flags without metadata.hypothesis → 422, POST with hypothesis → 201
  Files: `web/app/modules/analytics/controllers/feature_flags_controller.rb`, `web/app/modules/analytics/models/feature_flag.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`, `web/spec/models/analytics/feature_flag_spec.rb`

### Section 8: API Documentation (rswag)

- [ ] 8.1 — Add rswag gems and configure (`web/Gemfile`, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`)
  Required tests: `rake rswag:specs:swaggerize` exits 0, GET /api/docs returns 200 without auth, swagger/v1/swagger.yaml generated
  Files: `web/Gemfile`, `web/Gemfile.lock`, `web/vendor/cache/` (rswag gems), `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`, `web/config/routes.rb`

- [ ] 8.2 — Convert existing request specs to rswag format (`web/spec/requests/`)
  Blocked by: 8.1
  Required tests: all existing endpoints documented in swagger.yaml, each controller has rswag request spec covering 200/201, 401, 422, 404
  Files: `web/spec/requests/api/auth_spec.rb`, `web/spec/requests/agents/agent_runs_spec.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`, `web/spec/requests/analytics/metrics_spec.rb`

### Section 9: Batch Request Middleware

- [ ] 9.1 — Implement POST /api/batch Rack middleware (`web/app/middleware/batch_request_middleware.rb`)
  Required tests: fans out sub-requests through full Rack stack, responses ordered (response[i] = request[i]), individual sub-request failures isolated, max batch size enforced (422 on exceed), malformed JSON → 422, inherits auth from outer request
  Files: `web/app/middleware/batch_request_middleware.rb`, `web/spec/middleware/batch_request_middleware_spec.rb`, `web/config/application.rb`

### Section 10: Spec Reference Tags in Tests

- [ ] 10.1 — Add spec: metadata tags to existing RSpec files linking to spec sections
  Required tests: at least one spec file per module has spec: tag, tags reference valid spec file paths
  Files: `web/spec/models/agents/agent_run_spec.rb`, `web/spec/models/analytics/feature_flag_spec.rb`, `web/spec/models/sandbox/container_run_spec.rb`, `web/spec/middleware/health_check_middleware_spec.rb`

### Section 11: Reference Graph Web UI

- [ ] [SPIKE] 11.0 — Research server-rendered graph UI approach — run `./loop.sh research ref-graph-ui`
  Context: The UI consumes the Go parser's JSON output. Need to decide: does Rails shell out to the parser binary, or read a cached JSON file? How to render collapsible tree views in server-rendered HTML without a JS framework?

- [ ] 11.1 — Current view: in-progress beat + ancestor chain (`web/app/controllers/reference_graph_controller.rb`, `web/app/views/reference_graph/`)
  Blocked by: 5.6, 11.0
  Required tests: renders without JS, shows in-progress beat, shows ancestor chain (spec → PRD → pitch), markdown body syntax-highlighted
  Files: `web/app/controllers/reference_graph_controller.rb`, `web/app/views/reference_graph/current.html.erb`

- [ ] 11.2 — Open view: non-done plan items, filterable (`web/app/views/reference_graph/`)
  Blocked by: 5.6, 11.0
  Required tests: lists all non-done items, filterable by status and scope, sorted by oldest originated_at first
  Files: `web/app/views/reference_graph/open.html.erb`

- [ ] 11.3 — Condensed view: full project tree with text search (`web/app/views/reference_graph/`)
  Blocked by: 5.6, 11.0
  Required tests: renders collapsible tree, closed nodes collapsed by default, text search filters by title and body (case-insensitive)
  Files: `web/app/views/reference_graph/condensed.html.erb`

### Section 12: UI — Agent Runs (proposed)

- [ ] 12.1 — Agent Runs index page: paginated list (`web/app/controllers/agent_runs_ui_controller.rb`, `web/app/views/agent_runs/`)
  Required tests: renders paginated list, columns: mode/status/provider/model/tokens/cost/duration/created_at, filterable by mode and status, auth required
  Files: `web/app/controllers/agent_runs_ui_controller.rb`, `web/app/views/agent_runs/index.html.erb`, `web/config/routes.rb`

- [ ] 12.2 — Agent Run detail page: turns rendered as markdown (`web/app/views/agent_runs/`)
  Blocked by: 12.1
  Required tests: shows run metadata, ordered turns with kind badge, turn content rendered as markdown, link to parent run if present, source_ref displayed
  Files: `web/app/views/agent_runs/show.html.erb`

### Section 13: UI — Analytics Dashboard (proposed)

- [ ] 13.1 — Analytics dashboard page: summary cards + cost table (`web/app/controllers/analytics_ui_controller.rb`, `web/app/views/analytics/`)
  Required tests: summary cards (total cost, total runs, failure rate), cost by provider/model table, recent runs list, auth required
  Files: `web/app/controllers/analytics_ui_controller.rb`, `web/app/views/analytics/dashboard.html.erb`, `web/config/routes.rb`

- [ ] 13.2 — LLM metrics page: cost/token breakdown filterable by date (`web/app/views/analytics/`)
  Blocked by: 13.1
  Required tests: cost and token breakdown by provider and model, date range filter
  Files: `web/app/views/analytics/llm.html.erb`

### Section 14: Infrastructure Hardening

- [ ] 14.1 — Verify Postgres port not bound to 0.0.0.0 in all compose files
  Status: ✓ DONE — Postgres has no `ports:` section. No task needed.

- [ ] 14.2 — Verify image tags use git SHA, not `latest`
  Status: ✓ DONE — `${GIT_SHA:-dev}` used. No task needed.

---

## Dependency Graph

```
2.0 (spike) → 2.1 → 2.2
                ↓
         ┌──────┼──────────┐
         ↓      ↓          ↓
        3.1    4.1        5.1 ← 5.0 (spike)
         ↓      ↓          ↓
        3.2    4.2        5.2, 5.3, 5.4, 5.5
         ↓      ↓          ↓
        3.3    4.3        5.6
         ↓      ↓          ↓
        3.4    4.4     11.0 (spike) → 11.1 → 11.2 → 11.3
               ↓
              4.5

1.1 → 1.2 (independent of Go work)
6.1, 6.2, 6.3 (independent)
7.1 (independent)
8.1 → 8.2
9.1 (independent)
10.1 (independent, but benefits from 5.3)
12.1 → 12.2 (independent)
13.1 → 13.2 (independent)
```

## Priority Order (recommended build sequence)

1. **1.1, 1.2** — Controlled commit skill (enables structured git history for everything else)
2. **7.1** — Feature flag hypothesis validation (small fix, spec compliance)
3. **6.1, 6.2, 6.3** — Provider HTTP calls (unblocks actual agent execution)
4. **8.1, 8.2** — rswag API docs (definition of done for all endpoints)
5. **9.1** — Batch request middleware
6. **10.1** — Spec reference tags
7. **2.0 (spike), 2.1, 2.2** — Go bootstrap
8. **3.1–3.4** — Analytics ingest sidecar
9. **4.1–4.5** — Runner sidecar
10. **5.0 (spike), 5.1–5.6** — Reference parser
11. **11.0 (spike), 11.1–11.3** — Reference graph UI
12. **12.1, 12.2** — Agent runs UI
13. **13.1, 13.2** — Analytics dashboard UI

## Notes

- **Log Tail Relay** (`specs/system/log-tail-relay.md`): status `proposed`, open questions unresolved. No tasks planned until questions are answered.
- **CI Drift Detection** (reference-graph priority 4): Phase 1 concern — requires CI infrastructure.
- **LLM-Resolved Acceptance Tests** (reference-graph priority 7): Future spike, explicitly out of scope.
- **KiroAdapter#call_provider**: Kiro invocation is via CLI (`kiro-cli`), not HTTP. Implementation deferred until kiro provider spec is clearer — see `specs/skills/providers/kiro.md`.
- **Enrichment/callable tools** (agent-runner spec): Not planned as standalone tasks. Tool execution infrastructure is a larger feature that depends on provider calls working first. Will be planned in a future iteration after 6.1–6.3 are complete.
- **agent_override flag**: Not planned as standalone task. Low priority — needed only for benchmark comparison. Will be added when tool infrastructure lands.

### Section 15: Structural Deepening — Review Beats

Refactors identified by codebase review (2026-04-17). Each beat is behavior-preserving
unless noted. No new features — these reduce navigation cost, clarify module boundaries,
and make the test suite more honest.

- [ ] 15.1 — Extract shared adapter logic into ProviderAdapter base class (template method)
  <!-- status: todo, spec: specs/system/agent-runner/spec.md#provider-adapter-interface -->
  **Problem:** `assemble_system` and `turn_role` are copy-pasted identically across ClaudeAdapter, KiroAdapter, and OpenAiAdapter. A change to role mapping or system assembly requires editing three files. The duplication is in production code; tests already share via `shared_examples`.
  **Change:** Pull `assemble_system` and `turn_role` into `ProviderAdapter` as concrete protected methods. Extract `build_prompt` into a template method on the base class that calls a new `format_payload(system_content:, messages:)` method — each subclass overrides only `format_payload`, `parse_response`, `max_context_tokens`, and a `model_name` accessor. No behavior change.
  **Test boundary:** Shared assembly logic tested once on `ProviderAdapter`. Adapter-specific tests cover only `format_payload` shape and `parse_response` extraction. Existing `shared_examples` block stays but shrinks.
  Required tests: base class `assemble_system` and `turn_role` tested directly, each adapter's `format_payload` returns correct provider-native shape, existing shared_examples still pass
  Files: `web/app/modules/agents/services/provider_adapter.rb`, `web/app/modules/agents/services/claude_adapter.rb`, `web/app/modules/agents/services/open_ai_adapter.rb`, `web/app/modules/agents/services/kiro_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`

- [ ] 15.2 — Extract MetricsController query logic and fix cross-module boundary violation
  <!-- status: todo, spec: specs/system/analytics/spec.md#query-api -->
  **Problem:** `Analytics::MetricsController` directly queries `Agents::AgentRun` in `loops` and `summary` actions — violating the LOOKUP.md cross-module rule. The controller is 130 lines of inline query building, aggregation, and JSON serialization. The `flag_stats` action has an N+1-prone conversion rate calculation.
  **Change:** (1) Add read methods to `Agents::RunStorageService`: `run_counts_by_mode(org_id:)` and `weekly_summary(org_id:)` — these are the public interface analytics calls. (2) Extract analytics-internal queries (`llm`, `events`, `flag_stats`) into `Analytics::MetricsQuery` (or individual query objects). Controller actions become one-liner delegates. Update LOOKUP.md to list the new `RunStorageService` read methods.
  **Test boundary:** Query objects unit-tested with factory data (no HTTP). Controller request specs verify HTTP status, auth, and response shape only — no query logic assertions. Cross-module read interface tested in `RunStorageService` spec.
  Required tests: `RunStorageService.run_counts_by_mode` returns correct aggregation, `RunStorageService.weekly_summary` returns correct totals, `MetricsQuery` (or per-query objects) tested independently, existing request specs still pass, no direct `Agents::AgentRun` references in analytics module
  Files: `web/app/modules/agents/services/run_storage_service.rb`, `web/app/modules/analytics/controllers/metrics_controller.rb`, `web/app/modules/analytics/services/metrics_query.rb`, `web/app/modules/LOOKUP.md`, `web/spec/modules/agents/services/run_storage_service_spec.rb`, `web/spec/modules/analytics/services/metrics_query_spec.rb`, `web/spec/requests/analytics/metrics_spec.rb`

- [ ] 15.3 — Separate FeatureFlag.enabled? query from analytics event side effect
  <!-- status: todo, spec: specs/system/feature-flags/spec.md, spec: specs/system/analytics/spec.md#feature-flag-exposures -->
  **Problem:** `FeatureFlag.enabled?` is a predicate that silently writes to the database (`AnalyticsEvent.create!`) on every call. The side effect is invisible to callers, creates test pollution (every `enabled?` call in tests creates a record), and the `rescue StandardError` swallows all errors — not just write failures.
  **Change:** Rename current method to `FeatureFlag.evaluate(org_id:, key:)` which returns the boolean AND fires the event. Add a pure `FeatureFlag.enabled?(org_id:, key:)` that only queries — no writes. The analytics spec says "callers don't instrument manually" — `evaluate` preserves this for call sites that need tracking (controllers, services). Internal code and tests that just need the boolean use `enabled?`. Narrow the rescue to `ActiveRecord::ActiveRecordError` instead of `StandardError`.
  **Test boundary:** `enabled?` tested as a pure query — no database side effects to account for. `evaluate` tested for both the return value and the event creation. Fail-open behavior tested by stubbing only ActiveRecord errors.
  Required tests: `enabled?` returns correct boolean without creating AnalyticsEvent records, `evaluate` returns correct boolean AND creates AnalyticsEvent, `evaluate` does not raise on ActiveRecord write failure (fail-open), existing feature_flag_spec and request specs updated
  Files: `web/app/modules/analytics/models/feature_flag.rb`, `web/spec/models/analytics/feature_flag_spec.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`

- [ ] 15.4 — Split RunStorageService.start into named pipeline steps
  <!-- status: todo, spec: specs/system/agent-runner/spec.md -->
  **Problem:** `RunStorageService.start` mixes four concerns in one method: dedup check (content identity via SHA), concurrency guard (execution identity via source_ref), record creation, and job dispatch. Two different identity concepts are used with no structural indication of why. The method is the only way to understand run startup, but it requires reading the controller and job to get the full picture.
  **Change:** Extract into three named objects: `Agents::DeduplicationCheck.call(prompt_sha256:, mode:)` (absorbs `PromptDeduplicator`), `Agents::ConcurrencyGuard.call(source_ref:)`, and keep `RunStorageService.start` as the coordinator that calls them in sequence. Each step returns a result the coordinator acts on. `PromptDeduplicator` becomes an implementation detail of `DeduplicationCheck` (or is inlined — it's 8 lines).
  **Test boundary:** `DeduplicationCheck` tested with SHA/mode combinations — no run creation needed. `ConcurrencyGuard` tested with active/inactive source_refs — no dedup setup needed. `RunStorageService.start` integration test verifies the pipeline. Existing request specs unchanged.
  Required tests: `DeduplicationCheck` returns cached run or nil, `ConcurrencyGuard` raises on active run / passes on no active run, `RunStorageService.start` still passes all existing tests, `PromptDeduplicator` spec removed or redirected
  Files: `web/app/modules/agents/services/run_storage_service.rb`, `web/app/modules/agents/services/deduplication_check.rb`, `web/app/modules/agents/services/concurrency_guard.rb`, `web/app/modules/agents/services/prompt_deduplicator.rb`, `web/spec/modules/agents/services/run_storage_service_spec.rb`, `web/spec/modules/agents/services/deduplication_check_spec.rb`, `web/spec/modules/agents/services/concurrency_guard_spec.rb`, `web/spec/modules/agents/services/prompt_deduplicator_spec.rb`

- [ ] 15.5 — Define ProviderResult value object and fix parse_response contract mismatch
  <!-- status: todo, spec: specs/system/agent-runner/spec.md#provider-adapter-interface -->
  **Problem:** `AgentRunJob` expects `parse_response` to return `{text:, input_tokens:, output_tokens:, stop_reason:}` but the real adapters return a plain string. Tests stub `parse_response` to return the hash, masking the mismatch. The test suite is green but the code can't actually execute an agent run. The job also has no error handling for provider HTTP failures — only `TokenBudgetExceeded` is rescued.
  **Change:** (1) Create `Agents::ProviderResult` value object (pure transform) with `text`, `input_tokens`, `output_tokens`, `stop_reason` attributes. (2) Update all `parse_response` implementations to return a `ProviderResult` from the raw provider response. (3) Add a shared example that verifies each adapter's `parse_response` returns a `ProviderResult` from realistic response fixtures. (4) Add `rescue StandardError` in the job for provider call failures — set run status to `failed` with error context. This beat does NOT implement `call_provider` (that's tasks 6.1–6.3) — it fixes the contract so that when `call_provider` is implemented, the pipeline works.
  **Test boundary:** `ProviderResult` tested as a value object. Each adapter's `parse_response` tested against fixture data, asserting it returns a `ProviderResult`. Job error handling tested by stubbing provider failures. Existing stubs in job spec updated to use `ProviderResult.new(...)` instead of raw hashes.
  Required tests: `ProviderResult` exposes all four attributes, each adapter `parse_response` returns `ProviderResult` from realistic fixture, `AgentRunJob` sets status to `failed` on provider error, existing job specs updated and still pass
  Files: `web/app/modules/agents/services/provider_result.rb`, `web/app/modules/agents/services/provider_adapter.rb`, `web/app/modules/agents/services/claude_adapter.rb`, `web/app/modules/agents/services/open_ai_adapter.rb`, `web/app/modules/agents/services/kiro_adapter.rb`, `web/app/modules/agents/jobs/agent_run_job.rb`, `web/spec/modules/agents/services/provider_result_spec.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`, `web/spec/jobs/agents/agent_run_job_spec.rb`
