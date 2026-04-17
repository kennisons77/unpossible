# IMPLEMENTATION_PLAN.md — Unpossible

**Phase:** 0 (Local — Docker Compose only)
**Generated:** 2026-04-17T15:57
**Scope:** Phase 0 tasks only. No CI, no staging, no production config.

## Completed Work (discovered from code + git)

The following is implemented and tested (267 RSpec examples, 0 failures per last run):

- **Infrastructure:** Dockerfile (ruby:3.3-slim), Dockerfile.test (ruby:3.3), docker-compose.yml (rails + postgres), docker-compose.test.yml (ephemeral test stack). Image tags use `${GIT_SHA:-dev}`. Postgres not bound to 0.0.0.0. No `infra/k8s/` or `infra/nixos/` directories.
- **Auth:** Secret value object, AuthToken (JWT HS256), ApplicationController#authenticate!, POST /api/auth/token, X-Sidecar-Token sidecar auth, DISABLE_AUTH dev bypass, rack-attack rate limiting.
- **Security:** Security::PromptSanitizer, Security::LogRedactor, lograge structured logging with redaction, filter_parameters configured.
- **Agents module:** AgentRun model (modes, statuses, org_id, source_ref, parent_run_id, prompt_sha256, source_node_ids), AgentRunTurn model (kinds, purged_at), RunStorageService (start/complete/record_input, dedup, concurrency check), PromptDeduplicator, ProviderAdapter base with pinned+sliding token budget, ClaudeAdapter, KiroAdapter, OpenAiAdapter (build_prompt + parse_response), AgentRunsController (start/complete/input endpoints), AgentRunJob (Solid Queue execution with pause/resume), TurnContentGcJob (30-day retention, skips failed/waiting_for_input).
- **Sandbox module:** ContainerRun model (statuses, org_id, agent_run_id nullable), DockerDispatcher (shells out to docker run --rm, argument array, secret filtering, timeout).
- **Analytics module:** AnalyticsEvent model (append-only, org_id, distinct_id, event_name, node_id indexed, properties jsonb), AuditEvent model (append-only, severity enum), LlmMetric model (append-only, org_id, provider, model, cost_estimate_usd decimal(10,6)), FeatureFlag model (key unique per org, enabled, status active/archived, auto-fires $feature_flag_called), AuditLogger (async via AuditLogJob, fail-open), MetricsController (llm, loops, summary, events, flag_stats endpoints), FeatureFlagsController (index/create/update).
- **Health check:** HealthCheckMiddleware at position 0, GET /health → 200/503.
- **Ledger/Knowledge removal:** All ledger and knowledge tables dropped, FKs removed from agent_runs, source_ref string column added.
- **Reference graph (partial):** LedgerAppender (append-only LEDGER.jsonl, valid event types, idempotent), controlled-commit.sh script (atomic commit + ledger + plan update).
- **Module scaffold:** LOOKUP.md, namespace resolution, autoload paths configured.

## Spec Contradictions

**FeatureFlag metadata.hypothesis:** Base spec (`specs/system/feature-flags/spec.md`) says `metadata.hypothesis` is optional in Phase 0. Rails platform override (`specs/platform/rails/product/analytics.md`) says it's required on creation → 422. Current code and tests treat it as optional. **Resolution: follow the base spec — optional in Phase 0.** The platform override appears to describe post-MVP behaviour. Flag for human review if this is wrong.

---

## Section 1 — Reference Graph: Controlled Commit & Ledger (Priority 1)

> Spec: `specs/system/reference-graph/spec.md` § Components 1–2

- [x] 1.1 LedgerAppender for LEDGER.jsonl (`web/app/lib/ledger_appender.rb`, `web/spec/lib/ledger_appender_spec.rb`)
- [x] 1.2 Controlled commit skill script (`scripts/controlled-commit.sh`, `scripts/test-controlled-commit.sh`)

---

## Section 2 — Provider Adapters: parse_response Normalisation

> Spec: `specs/system/agent-runner/spec.md` § Provider Adapter Interface
> The spec requires `parse_response` to return `{text:, input_tokens:, output_tokens:, stop_reason:}`.
> Current adapters return a plain string (e.g. `raw_response.dig("content", 0, "text")`).
> AgentRunJob already expects a hash (tests mock it as a hash). The adapters themselves are inconsistent.

- [x] 2.1 Fix ClaudeAdapter#parse_response to return normalised hash (`web/app/modules/agents/services/claude_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`)
  Required tests: parse_response returns hash with :text, :input_tokens, :output_tokens, :stop_reason keys; handles missing fields gracefully

- [x] 2.2 Fix KiroAdapter#parse_response to return normalised hash (`web/app/modules/agents/services/kiro_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`)
  Required tests: same as 2.1

- [x] 2.3 Fix OpenAiAdapter#parse_response to return normalised hash (`web/app/modules/agents/services/open_ai_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`)
  Required tests: same as 2.1

---

## Section 3 — Provider Adapters: call_provider HTTP Implementation

> Spec: `specs/system/agent-runner/spec.md` § Provider Adapter Interface
> `call_provider` is currently `raise NotImplementedError`. The spec requires direct HTTP calls to provider APIs.

- [ ] 3.1 Implement ClaudeAdapter#call_provider with HTTP POST to Anthropic API (`web/app/modules/agents/services/claude_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`)
  Required tests: sends correct headers (x-api-key, anthropic-version), sends correct body shape, returns raw response hash, API key wrapped in Secret and never logged
  Required threat tests: API key not present in logs or error messages

- [ ] 3.2 Implement OpenAiAdapter#call_provider with HTTP POST to OpenAI API (`web/app/modules/agents/services/open_ai_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`)
  Required tests: sends correct headers (Authorization: Bearer), sends correct body shape, returns raw response hash, API key wrapped in Secret and never logged
  Required threat tests: API key not present in logs or error messages

- [ ] 3.3 Implement KiroAdapter#call_provider — determine invocation method (`web/app/modules/agents/services/kiro_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`)
  Required tests: invocation works, returns raw response, API key not logged
  Note: Kiro invocation may differ from HTTP API pattern — check `specs/skills/providers/kiro.md` for details.

---

## Section 4 — API Documentation (rswag)

> Spec: `specs/system/api/spec.md`, `specs/system/api/prd.md`, `specs/platform/rails/system/api-standards.md`
> rswag is not installed. No swagger.yaml exists. No spec/requests/ files use rswag DSL.
> Existing request specs use plain RSpec request syntax.

- [ ] 4.1 Add rswag gems and configure (`web/Gemfile`, `web/Gemfile.lock`, `web/vendor/cache/`, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`, `swagger/v1/swagger.yaml`)
  Required tests: `GET /api/docs` returns 200 without authentication; `rake rswag:specs:swaggerize` exits 0
  Note: gems must be pre-downloaded to `web/vendor/cache/` per AGENTS.md § Adding New Gems

- [ ] 4.2 Convert existing request specs to rswag DSL — auth endpoints (`web/spec/requests/api/auth_spec.rb`)
  Required tests: existing test coverage preserved; spec contributes to swagger.yaml

- [ ] 4.3 Convert existing request specs to rswag DSL — agent_runs endpoints (`web/spec/requests/agents/agent_runs_spec.rb`)
  Required tests: existing test coverage preserved; spec contributes to swagger.yaml

- [ ] 4.4 Convert existing request specs to rswag DSL — feature_flags endpoints (`web/spec/requests/analytics/feature_flags_spec.rb`)
  Required tests: existing test coverage preserved; spec contributes to swagger.yaml

- [ ] 4.5 Convert existing request specs to rswag DSL — metrics endpoints (`web/spec/requests/analytics/metrics_spec.rb`)
  Required tests: existing test coverage preserved; spec contributes to swagger.yaml

- [ ] 4.6 Add rswag route for `/api/docs` and verify swagger.yaml generation (`web/config/routes.rb`, `swagger/v1/swagger.yaml`)
  Required tests: `GET /api/docs` returns 200; swagger.yaml lists all API endpoints

---

## Section 5 — Batch Request Middleware

> Spec: `specs/system/batch-requests.md`
> Not implemented. No middleware, no tests.

- [ ] 5.1 Implement BatchRequestMiddleware (`web/app/middleware/batch_request_middleware.rb`, `web/spec/middleware/batch_request_middleware_spec.rb`)
  Required tests: POST /api/batch fans out sub-requests and returns aggregated responses; responses ordered by request index; individual sub-request failures captured (not batch failure); max batch size enforced (422 on exceed); malformed JSON returns 422; sub-requests share auth context; batch endpoint requires authentication

- [ ] 5.2 Register BatchRequestMiddleware in application.rb and add route (`web/config/application.rb`, `web/config/routes.rb`)
  Required tests: POST /api/batch is routable and processed by middleware

---

## Section 6 — Go Sidecars & CLI

> Specs: `specs/platform/go/README.md`, `specs/platform/go/system/runner.md`, `specs/platform/go/system/analytics.md`, `specs/system/reference-graph/spec.md` § Go Reference Parser
> The entire `go/` directory does not exist. No Go code, no Dockerfile.go, no go.mod.

- [ ] [SPIKE] 6.1 Research Go project bootstrap — run `./loop.sh research go-bootstrap` (see specs/skills/tools/research.md)
  Scope: Determine Go module structure, dependency management for offline builds, multi-stage Dockerfile.go pattern, test strategy for sidecars (mock HTTP, mock Postgres). Blocks 6.2–6.8.

- [ ] 6.2 Bootstrap Go module and Dockerfile.go (`go/go.mod`, `go/go.sum`, `go/cmd/runner/main.go`, `go/cmd/analytics/main.go`, `go/cmd/parser/main.go`, `infra/Dockerfile.go`)
  Depends on: 6.1
  Required tests: `go build ./...` succeeds; `go test ./...` exits 0; Dockerfile.go multi-stage build produces runner, analytics, and parser binaries

- [ ] 6.3 Implement Go analytics ingest sidecar (`go/cmd/analytics/main.go`, `go/internal/`)
  Depends on: 6.2
  Required tests: POST /capture returns 202 immediately; events flushed within 5s or 100 events; events buffered on Postgres unavailability; GET /healthz returns 200; non-UUID distinct_id rejected; properties filtered through PII patterns
  Required threat tests: ingest endpoint not reachable from outside internal network (compose network config)

- [ ] 6.4 Implement Go runner sidecar (`go/cmd/runner/main.go`, `go/internal/`)
  Depends on: 6.2
  Required tests: POST /run without Basic Auth → 401; concurrent POST /run → 409; calls Rails complete endpoint after loop exits (mock server); token counts parsed from stream-json stdout; GET /healthz returns 200; GET /ready returns 200; GET /metrics returns Prometheus text format

- [ ] 6.5 Uncomment go_runner and analytics services in docker-compose.yml (`infra/docker-compose.yml`)
  Depends on: 6.3, 6.4
  Required tests: `docker compose up` starts all services including Go sidecars

- [ ] [SPIKE] 6.6 Research Go reference parser libraries — run `./loop.sh research go-parser-libs` (see specs/skills/tools/research.md)
  Scope: Evaluate Go libraries for markdown frontmatter parsing, JSONL parsing, git log/notes traversal. Blocks 6.7.

- [ ] 6.7 Implement Go reference parser CLI (`go/cmd/parser/main.go`, `go/internal/`)
  Depends on: 6.2, 6.6
  Required tests: parser produces deterministic JSON graph from files + git + LEDGER.jsonl; spec: tags in RSpec files parsed and appear as edges; blocked-by references parsed as dependency edges; PR events from LEDGER.jsonl produce PR nodes; parser runs as standalone binary with no runtime dependencies

---

## Section 7 — Agent Run: agent_override Flag

> Spec: `specs/system/agent-runner/spec.md` § Agent Override Flag
> Not implemented. No `agent_override` column on AgentRun, no skip logic in AgentRunJob.

- [ ] 7.1 Add agent_override boolean to AgentRun and wire skip logic (`web/db/migrate/YYYYMMDD_add_agent_override_to_agent_runs.rb`, `web/app/modules/agents/models/agent_run.rb`, `web/app/modules/agents/jobs/agent_run_job.rb`, `web/spec/models/agents/agent_run_spec.rb`, `web/spec/jobs/agents/agent_run_job_spec.rb`)
  Required tests: agent_override defaults to false; when true, enrichment tools are skipped; callable tools still passed to provider; AgentRunsController accepts agent_override param

---

## Section 8 — Agent Run: Enrichment & Callable Tools

> Spec: `specs/system/agent-runner/spec.md` § Skill Frontmatter — Tool Declaration, § Assembly Pipeline
> Not implemented. AgentRunJob does not load skill frontmatter, does not run enrichment tools, does not pass callable tools to provider.

- [ ] 8.1 Implement skill frontmatter parsing for tool declarations (`web/app/modules/agents/services/skill_loader.rb`, `web/spec/modules/agents/services/skill_loader_spec.rb`)
  Required tests: parses `tools.enrich` and `tools.callable` from YAML frontmatter; returns empty arrays when not present; handles malformed frontmatter gracefully

- [ ] 8.2 Wire enrichment tools into AgentRunJob assembly pipeline (`web/app/modules/agents/jobs/agent_run_job.rb`, `web/spec/jobs/agents/agent_run_job_spec.rb`)
  Depends on: 8.1
  Required tests: enrichment tools run before first LLM call; results appear as tool_result turns; skipped when agent_override is true

- [ ] 8.3 Pass callable tools to provider in build_prompt (`web/app/modules/agents/services/provider_adapter.rb`, adapters, `web/spec/modules/agents/services/provider_adapter_spec.rb`)
  Depends on: 8.1
  Required tests: callable tools array passed in provider-native format; empty array when no callable tools declared

---

## Section 9 — Agent Run: Assembly Pipeline Context Loading

> Spec: `specs/system/agent-runner/spec.md` § Assembly Pipeline steps 1–5
> AgentRunJob currently passes empty arrays for context_chunks and principles. The spec requires loading instruction body, context from practices files, and principles from skill frontmatter.

- [ ] 9.1 Load instruction body and context/principles from skill frontmatter in AgentRunJob (`web/app/modules/agents/jobs/agent_run_job.rb`, `web/spec/jobs/agents/agent_run_job_spec.rb`)
  Depends on: 8.1
  Required tests: instruction body loaded from skill file path; context_chunks populated from practices files declared in frontmatter; principles populated from principles files declared in frontmatter; missing files handled gracefully (logged, not raised)

---

## Section 10 — Analytics: LlmMetric Creation on Run Complete

> Spec: `specs/platform/rails/system/analytics.md` — LlmMetric is per agent run cost/token record.
> LlmMetric model exists but is never created. AgentRunsController#complete calls AuditLogger but does not create an LlmMetric.

- [ ] 10.1 Create LlmMetric record when agent run completes (`web/app/modules/agents/controllers/agent_runs_controller.rb` or `web/app/modules/agents/services/run_storage_service.rb`, `web/spec/requests/agents/agent_runs_spec.rb`)
  Required tests: completing an agent run creates an LlmMetric with correct provider, model, tokens, cost, org_id, agent_run_id; no LlmMetric created on failed runs

---

## Section 11 — Sandbox: ContainerRun stdout/stderr Capture

> Spec: `specs/system/sandbox/prd.md` — stdout and stderr captured in full after completion.
> DockerDispatcher captures stdout/stderr and stores in ContainerRun record. ✓ Implemented.
> However, the spec also requires `agent_run_id` to be set on dispatch. Currently DockerDispatcher does not accept agent_run_id.

- [ ] 11.1 Accept and store agent_run_id in DockerDispatcher#dispatch (`web/app/modules/sandbox/services/docker_dispatcher.rb`, `web/spec/modules/sandbox/services/docker_dispatcher_spec.rb`)
  Required tests: agent_run_id passed to dispatch is stored on ContainerRun; agent_run_id is optional (nullable)

---

## Section 12 — Reference Graph: Spec Reference Tags Convention

> Spec: `specs/system/reference-graph/spec.md` § Spec Reference Tags in Tests (Priority 3)
> Convention for `spec:` metadata tags in RSpec. No existing tests use this convention.

- [ ] 12.1 Add spec: metadata tags to existing RSpec files as exemplar (`web/spec/models/agents/agent_run_spec.rb`, `web/spec/models/analytics/feature_flag_spec.rb`)
  Required tests: spec: tag is valid RSpec metadata and does not break test execution; at least 2 spec files demonstrate the convention

---

## Section 13 — Reference Graph: Web UI (Read-Only)

> Spec: `specs/system/reference-graph/spec.md` § Read-Only Web UI (Priority 5)
> No views exist. Rails is configured as full-stack (not API-only). Views needed for: Current, Open, Condensed.
> Depends on Go reference parser (6.7) for JSON graph data.

- [ ] [SPIKE] 13.1 Research reference graph UI approach — run `./loop.sh research ref-graph-ui` (see specs/skills/tools/research.md)
  Scope: Determine how to render parser JSON output in server-rendered ERB views. Collapsible tree for condensed view. Text search without full-text index. Blocks 13.2–13.4.

- [ ] 13.2 Implement Current view — in-progress beat + ancestor chain (`web/app/controllers/reference_graph_controller.rb`, `web/app/views/reference_graph/current.html.erb`)
  Depends on: 6.7, 13.1
  Required tests: renders without JS; shows in-progress question with ancestor chain; markdown body rendered with syntax highlighting; unauthenticated requests redirect to login

- [ ] 13.3 Implement Open view — all non-closed questions (`web/app/views/reference_graph/open.html.erb`)
  Depends on: 6.7, 13.1
  Required tests: renders without JS; filterable by scope, level, status; sorted by oldest originated_at first; unauthenticated requests redirect to login

- [ ] 13.4 Implement Condensed view — full project tree with search (`web/app/views/reference_graph/condensed.html.erb`)
  Depends on: 6.7, 13.1
  Required tests: renders without JS; collapsible tree; text search filters by title and body (case-insensitive); closed nodes collapsed by default; unauthenticated requests redirect to login

---

## Section 14 — Agent Runs UI

> Spec: `specs/system/agent-runs-ui.md` (status: proposed)
> No views exist.

- [ ] 14.1 Implement Agent Run History view (`web/app/controllers/agent_runs_ui_controller.rb`, `web/app/views/agent_runs/index.html.erb`)
  Required tests: paginated list of runs, most recent first; columns: mode, status, provider/model, tokens, cost, duration, created_at; filterable by mode and status; server-rendered HTML; auth required

- [ ] 14.2 Implement Agent Run Detail view (`web/app/views/agent_runs/show.html.erb`)
  Required tests: run metadata displayed; ordered turns with kind badge; turn content rendered as markdown; link to parent run if present; source_ref displayed; auth required

---

## Section 15 — Analytics Dashboard UI

> Spec: `specs/system/analytics-dashboard-ui.md` (status: proposed)
> No views exist.

- [ ] 15.1 Implement Analytics Dashboard view (`web/app/controllers/analytics_ui_controller.rb`, `web/app/views/analytics/dashboard.html.erb`)
  Required tests: summary cards (total cost, total runs, failure rate); cost by provider/model table; recent runs list (last 20); server-rendered HTML; auth required

- [ ] 15.2 Implement LLM Metrics view (`web/app/views/analytics/llm.html.erb`)
  Required tests: cost and token breakdown by provider/model; filterable by date range; server-rendered HTML; auth required

---

## Section 16 — CI Drift Detection

> Spec: `specs/system/reference-graph/spec.md` § CI Drift Detection (Priority 4)
> Not implemented. Phase 0 scope: the script/tool itself, not CI integration (that's Phase 1).

- [ ] 16.1 Implement spec content hash recording in LEDGER.jsonl (`scripts/` or `web/app/lib/`)
  Depends on: 1.1
  Required tests: spec_changed events appended to LEDGER.jsonl when spec content changes; content_hash is SHA256 of section content; idempotent — unchanged specs produce no events

- [ ] 16.2 Implement drift detection script that compares spec hashes (`scripts/detect-drift.sh` or Go CLI)
  Depends on: 16.1
  Required tests: flags spec sections that changed since linked tests last passed; does not fail the build (informational only); deterministic output

---

## Section 17 — Recurring Jobs: Turn Content GC in recurring.yml

> Spec: `specs/system/agent-runner/spec.md` § Turn Content GC
> TurnContentGcJob exists and is tested. recurring.yml has it configured for production only.
> Verify it also runs in development (or is at least testable).

- [x] 17.1 TurnContentGcJob configured in recurring.yml — already done (production schedule: daily at midnight). No action needed for Phase 0.

---

## Section 18 — Infrastructure Gaps

> Spec: `specs/system/infrastructure/spec.md`

- [ ] 18.1 Verify Postgres port is not bound to 0.0.0.0 in docker-compose.yml — ✓ already correct (no `ports:` on postgres service). No action needed.

- [ ] 18.2 Add `ports:` binding restriction comment to docker-compose.yml for clarity (`infra/docker-compose.yml`)
  Required tests: N/A (documentation only)

Note: go_runner and analytics services are commented out in docker-compose.yml. They will be uncommented in task 6.5 after Go sidecars are built.

---

## Section 19 — Missing: Solid Queue Concurrency Key on AgentRunJob

> Spec: `specs/system/agent-runner/spec.md` § Concurrency — one active run per agent config via solid_queue concurrency key.
> AgentRunJob defines `concurrency_key_for` helper but does not actually use Solid Queue's `limits_concurrency` DSL.

- [ ] 19.1 Wire Solid Queue concurrency control on AgentRunJob (`web/app/modules/agents/jobs/agent_run_job.rb`, `web/spec/jobs/agents/agent_run_job_spec.rb`)
  Required tests: Solid Queue concurrency key is set using source_ref (or run_id fallback); concurrent job for same key is rejected/queued per Solid Queue semantics

---

## Section 20 — Missing: FeatureFlagExposure Model

> Spec: `specs/platform/rails/product/analytics.md` — lists `Analytics::FeatureFlagExposure` model.
> Not implemented. Currently, flag exposures are stored as AnalyticsEvent records with event_name `$feature_flag_called`.
> The platform override lists it as a separate model. However, the base analytics spec stores exposures as analytics events.
> **Resolution: the current approach (AnalyticsEvent) matches the base spec. FeatureFlagExposure as a separate model is likely a platform override detail that was specced but not needed — the join on AnalyticsEvent works. Flag for human review.**

No task — current implementation matches base spec. Flagged for review.

---

## Dependency Graph

```
6.1 (spike: Go bootstrap) → 6.2 → 6.3, 6.4, 6.7
6.6 (spike: Go parser libs) → 6.7
6.3 + 6.4 → 6.5
6.7 + 13.1 (spike: UI approach) → 13.2, 13.3, 13.4
8.1 → 8.2, 8.3, 9.1
7.1 → 8.2 (agent_override skip logic)
1.1 → 16.1 → 16.2
```

All other tasks are independent and can be executed in any order.

## Recommended Execution Order

1. **2.1–2.3** — parse_response normalisation (quick fixes, unblock correct AgentRunJob behaviour)
2. **19.1** — Solid Queue concurrency key (small fix, correctness)
3. **10.1** — LlmMetric creation on run complete (small, unblocks analytics accuracy)
4. **11.1** — DockerDispatcher agent_run_id (small fix)
5. **7.1** — agent_override flag
6. **8.1** — skill frontmatter parsing (unblocks 8.2, 8.3, 9.1)
7. **8.2, 8.3** — enrichment + callable tools
8. **9.1** — assembly pipeline context loading
9. **3.1–3.3** — call_provider HTTP implementation
10. **5.1–5.2** — batch request middleware
11. **4.1–4.6** — rswag API documentation
12. **12.1** — spec reference tags exemplar
13. **6.1** (spike) → **6.2** → **6.3, 6.4** → **6.5** — Go sidecars
14. **6.6** (spike) → **6.7** — Go reference parser
15. **14.1–14.2** — Agent Runs UI
16. **15.1–15.2** — Analytics Dashboard UI
17. **13.1** (spike) → **13.2–13.4** — Reference Graph UI
18. **16.1–16.2** — CI drift detection
