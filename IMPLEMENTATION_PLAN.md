# Implementation Plan

Generated: 2026-04-02 (gap analysis refresh)
Phase: 0 (Local Development — Docker Compose only)

> Scope: Phase 0 only. No CI, no k8s, no staging.
> Infra in scope: `infra/Dockerfile`, `infra/Dockerfile.test`, `infra/Dockerfile.runner`,
> `infra/Dockerfile.analytics`, `infra/docker-compose.yml`, `infra/docker-compose.test.yml`.

---

## Gap Analysis Notes

**Confirmed implemented (Section 1–4 complete):**
- `infra/Dockerfile` — multi-stage ruby:3.3-slim, non-root, port 3000 ✓
- `infra/Dockerfile.test` + `infra/entrypoint-test.sh` ✓
- `infra/docker-compose.yml` — full dev stack (rails + go_runner + analytics + postgres + redis) ✓
- `infra/docker-compose.test.yml` — ephemeral test stack ✓
- Rails skeleton: Gemfile (solid_queue, jwt, rack-attack, lograge, redcarpet, rouge), config files ✓
- RSpec + Rubocop + SimpleCov + Lograge configured ✓
- `Secret` value object, `Security::LogRedactor`, `Security::PromptSanitizer` ✓
- rack-attack rate limiting, brakeman + bundler-audit Rake tasks ✓
- Module scaffold (knowledge, tasks, agents, sandbox, analytics) ✓
- JWT authentication (`AuthToken`, `ApplicationController#authenticate!`, `POST /api/auth/token`) ✓
- `Ledger::Node` model + migration ✓
- `Ledger::NodeEdge` model + migration ✓
- `Ledger::ActorProfile` + `Ledger::Actor` models + migrations ✓
- `Ledger::NodeLifecycleService` (transition, accept, rebut, create_child_question, attach_research) ✓
- `Ledger::NodesController` (GET/POST /api/nodes, GET /api/nodes/:id, verdict, comments) ✓
- `Ledger::SpecWatcherJob` ✓
- `Ledger::PlanFileSyncService` ✓
- Ledger UI views (current, open, tree, node detail) + `MarkdownHelper` ✓
- `Ledger::LedgerController` (HTML views) ✓
- Migrations 1–7 (nodes, edges, actor_profiles, actors, level+citations, audit_events, status redesign) ✓

**Critical bugs found (block all test runs):**

1. **`"open"` status used everywhere but removed from `Node::STATUSES` in migration 7.**
   Migration 7 renamed `open → proposed`, but `SpecWatcherJob`, `PlanFileSyncService`,
   `LedgerController`, factory default, and all specs still use `"open"`. Tests will fail
   with validation errors. Must fix before any other work.

2. **`NodeLifecycleService.record_verdict` called but never defined.**
   `NodesController#verdict` calls `NodeLifecycleService.record_verdict(...)` which does not
   exist. The service has `accept` and `rebut` but not `record_verdict`. The spec for
   `NodeLifecycleService` also tests `record_verdict` with `acceptance_threshold` and
   `accepted` columns that were dropped in migration 7. The verdict flow must be rewritten
   to use `accept`/`rebut` per the current spec.

3. **`accepted`, `acceptance_threshold` columns dropped in migration 7 but still referenced.**
   Factory traits (`:answer`, `:terminal_answer`, `:generative_answer`) set `accepted: "pending"`.
   `node_spec.rb` tests `accepted` field. `nodes_spec.rb` calls `answer.update!(accepted: 'true')`.
   `NodesController` permits `:accepted` and `:acceptance_threshold` in `node_params`.
   All these references must be removed.

4. **`LedgerController#open` queries `status: "open"` — invalid after migration 7.**
   Must query `status: %w[proposed refining in_review accepted in_progress blocked]` (all non-closed).

5. **`infra/docker-compose.yml` missing `Dockerfile.runner` and `Dockerfile.analytics`.**
   Both are referenced in `docker-compose.yml` but neither file exists. `docker compose up`
   will fail immediately.

**Open questions in specs (require spikes before build tasks):**

- `stable_ref` agent title drift — `specs/system/ledger/spec.md` open question. Spike required
  before any work that depends on stable_ref dedup beyond plan file sync.
- `specs/project-prd.md` open questions: multi-tenancy scope (single-org vs org creation),
  MinIO in Phase 0, Go runner source (copy vs submodule). These block Go runner and analytics
  sidecar tasks.

---

## Section 1 — Infrastructure (COMPLETE)

- [x] Create `infra/Dockerfile` (multi-stage ruby:3.3-slim, non-root, port 3000)
- [x] Create `infra/Dockerfile.test` + `infra/entrypoint-test.sh`
- [x] Configure RSpec + Rubocop + SimpleCov + Lograge
- [x] Create `AGENTS.md`
- [x] Fix Gemfile.lock — solid_queue, no sidekiq/redis
- [x] Rename docker-compose.yml → docker-compose.test.yml; create docker-compose.yml (full dev stack)
- [x] Configure Solid Queue (config/queue.yml, config/recurring.yml, migrations)

- [ ] Create `infra/Dockerfile.runner` (Go runner sidecar) <!-- ref: infra-dockerfile-runner -->
  Multi-stage golang:1.22-alpine builder → alpine:3.19 final, non-root, port 8080.
  Blocked by: spike on Go runner source (see Section 10).
  Files: `infra/Dockerfile.runner`
  Required tests: `docker build -f infra/Dockerfile.runner .` exits 0; `/healthz` returns 200

- [ ] Create `infra/Dockerfile.analytics` (Go analytics sidecar) <!-- ref: infra-dockerfile-analytics -->
  Multi-stage golang:1.22-alpine builder → alpine:3.19 final, non-root, port 9100.
  Blocked by: spike on Go runner source (see Section 10).
  Files: `infra/Dockerfile.analytics`
  Required tests: `docker build -f infra/Dockerfile.analytics .` exits 0; `/healthz` returns 200


## Section 2 — Security Foundation (COMPLETE)

- [x] Create `Secret` value object
- [x] Create `Security::LogRedactor`
- [x] Create `Security::PromptSanitizer`
- [x] Configure rack-attack rate limiting
- [x] Configure brakeman and bundler-audit Rake tasks


## Section 3 — Core Module Structure & Auth (COMPLETE)

- [x] Scaffold module directory structure + LOOKUP.md files
- [x] Create JWT authentication


## Section 4 — Ledger Module (COMPLETE — but has critical bugs, see Section 5)

- [x] [SPIKE] stable_ref dedup strategy — resolved: canonical ref comments
- [x] Create `Node` model and migration
- [x] Create `NodeEdge` model and migration
- [x] Create `ActorProfile` and `Actor` models and migrations
- [x] Implement `Ledger::NodeLifecycleService`
- [x] Create `Ledger::NodesController`
- [x] Create `Ledger::SpecWatcherJob`
- [x] Implement `Ledger::PlanFileSyncService`


## Section 5 — Ledger Bug Fixes (HIGH PRIORITY — blocks all test runs)

- [x] Fix `"open"` status references — replace with `"proposed"` throughout <!-- ref: ledger-fix-open-status -->
  Migration 7 renamed `open → proposed` but code and specs still use `"open"`. Fix all occurrences.
  Files: `web/app/modules/ledger/jobs/spec_watcher_job.rb`, `web/app/modules/ledger/services/plan_file_sync_service.rb`, `web/app/modules/ledger/controllers/ledger_controller.rb`, `web/spec/factories/ledger_nodes.rb`, `web/spec/modules/ledger/jobs/spec_watcher_job_spec.rb`, `web/spec/modules/ledger/services/plan_file_sync_service_spec.rb`, `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb`, `web/spec/models/ledger/node_spec.rb`, `web/spec/requests/ledger/nodes_spec.rb`
  Required tests: `bundle exec rspec` exits 0; no `"open"` in STATUSES constant; SpecWatcherJob creates node with status `"proposed"`; PlanFileSyncService creates unchecked node with status `"proposed"`

- [x] Fix `record_verdict` / `accepted` column references — align with current spec <!-- ref: ledger-fix-verdict -->
  `NodeLifecycleService.record_verdict` does not exist. `NodesController#verdict` must call `accept` or `rebut` based on verdict boolean. Remove `accepted`, `acceptance_threshold` from factory traits, node_spec, nodes_spec, and node_params. The verdict endpoint: `verdict=true` → `NodeLifecycleService.accept(node, answer_attrs)`; `verdict=false` → `NodeLifecycleService.rebut(node, answer_attrs)`. The `node_lifecycle_service_spec.rb` tests for `record_verdict` must be rewritten to test `accept`/`rebut` per `specs/system/ledger/spec.md` UAT-3.
  Files: `web/app/modules/ledger/controllers/nodes_controller.rb`, `web/app/modules/ledger/services/node_lifecycle_service.rb` (add `record_verdict` shim or remove callers), `web/spec/factories/ledger_nodes.rb`, `web/spec/models/ledger/node_spec.rb`, `web/spec/requests/ledger/nodes_spec.rb`, `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb`
  Required tests: `POST /api/nodes/:id/verdict` with `verdict=true` calls `accept`, closes parent question; `verdict=false` calls `rebut`, reopens parent; no `accepted` column references remain; `bundle exec rspec` exits 0

- [x] Fix `LedgerController#open` status query <!-- ref: ledger-fix-open-query -->
  `LedgerController#open` queries `status: "open"` which is no longer a valid status. Replace with all non-closed statuses: `%w[proposed refining in_review accepted in_progress blocked]`.
  Files: `web/app/modules/ledger/controllers/ledger_controller.rb`
  Required tests: `GET /ledger/open` returns nodes with any non-closed status; closed nodes excluded

- [x] Fix `NodeAuditEvent` spec — add missing spec file <!-- ref: ledger-node-audit-event-spec -->
  `NodeAuditEvent` model exists and migration exists but no spec file. Add spec covering: append-only (raises on update/destroy), validates changed_by, validates to_status, belongs_to node.
  Files: `web/spec/models/ledger/node_audit_event_spec.rb`
  Required tests: update raises `ActiveRecord::ReadOnlyRecord`; destroy raises `ActiveRecord::ReadOnlyRecord`; invalid changed_by → validation error; belongs_to node

- [x] Fix `NodeLifecycleService` — add `NodeAuditEvent` writes to `accept`/`rebut`/`transition` <!-- ref: ledger-audit-events -->
  Per spec: `NodeAuditEvent` must be written on every status transition. `transition` already writes it. `accept` and `rebut` call `_close_question` and `transition` respectively — verify audit events are written in both paths. Add spec coverage for audit event creation in `accept` and `rebut`.
  Files: `web/app/modules/ledger/services/node_lifecycle_service.rb`, `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb`
  Required tests: `accept` creates NodeAuditEvent with from_status and to_status `"closed"`; `rebut` creates NodeAuditEvent with to_status `"proposed"`; version increments on both

- [x] Fix `Node` model — add `level` validation and `citations` default <!-- ref: ledger-node-level-fix -->
  Migration 5 added `level` and `citations` columns. `Node` model has `LEVELS` constant and `level_only_for_intent` validation. Verify `citations` defaults to `[]` in DB and model. Add `node_spec.rb` coverage for level validation (level on non-intent → error; level nil on non-intent → valid; level on intent → valid).
  Files: `web/app/modules/ledger/models/node.rb`, `web/spec/models/ledger/node_spec.rb`
  Required tests: level on non-intent scope → validation error; level nil on non-intent → valid; citations defaults to []; LEVELS constant present


## Section 6 — Ledger UI (PARTIALLY COMPLETE)

- [x] Add `Ledger::LedgerController` (HTML views) and routes
- [x] Add markdown rendering + syntax highlighting (`MarkdownHelper`)
- [x] Views: current, open, tree, node detail

- [x] Add request specs for Ledger UI <!-- ref: ledger-ui-request-specs -->
  No `spec/requests/ledger/ledger_spec.rb` exists. Required per api-standards spec.
  Files: `web/spec/requests/ledger/ledger_spec.rb`
  Required tests: `GET /ledger` returns 200 with active node; `GET /ledger/open` returns 200; `GET /ledger/tree` returns 200; `GET /ledger/nodes/:id` returns 200 with audit trail; unauthenticated → redirect to login; text search on `/ledger/tree` filters results

- [ ] Add `MarkdownHelper` spec <!-- ref: ledger-ui-markdown-spec -->
  `web/app/helpers/markdown_helper.rb` exists but no spec.
  Files: `web/spec/helpers/markdown_helper_spec.rb`
  Required tests: fenced ruby block renders with syntax highlight classes; plain markdown renders headings and links; citations URL rendered as anchor tag; blank input returns empty string

- [x] Fix `node.html.erb` — remove stale `node.accepted` reference <!-- ref: ledger-ui-accepted-ref -->
  `node.html.erb` renders `@node.status || @node.accepted` — `accepted` column was dropped in migration 7. Remove the `|| @node.accepted` fallback.
  Files: `web/app/views/ledger/node.html.erb`
  Required tests: node detail page renders without NoMethodError on `accepted`


## Section 7 — Knowledge Module <!-- ref: knowledge-module -->

- [ ] [SPIKE] Research Active Storage replacement — local file store vs Active Storage <!-- ref: spike-active-storage -->
  `practices/framework/rails.md` notes "TO RESEARCH: replacing this with a local file store?" for Active Storage. Knowledge module needs to store/retrieve spec file content. Determine whether Active Storage + local disk adapter is sufficient for Phase 0 or if a simpler approach (direct File.read) is better.
  Run `./loop.sh research spike-active-storage`
  Blocks: Knowledge::LibraryItem file attachment approach

- [ ] Create `Knowledge::LibraryItem` model and migration <!-- ref: knowledge-library-item -->
  Schema per `specs/system/knowledge/spec.md` + `specs/platform/rails/system/knowledge.md`: id (uuid), node_id (FK→ledger_nodes, nullable), source_path (string, nullable), source_sha (string, nullable), chunk_index (integer), content_type (enum: md_file/plain_text/link_reference/llm_response/error_context), content (text), org_id (uuid). Unique index on (source_path, chunk_index). Separate `Knowledge::Embedding` model with `vector(1536)` column via pgvector, IVFFlat index for cosine similarity. `archived_at` nullable — default scope excludes archived.
  Files: `web/app/modules/knowledge/models/library_item.rb`, `web/app/modules/knowledge/models/embedding.rb`, migrations, `web/spec/models/knowledge/library_item_spec.rb`, factories
  Required tests: content_type enum validates; unique index on (source_path, chunk_index); default scope excludes archived; node_id nullable; factory valid

- [ ] Implement `Knowledge::MdChunker` <!-- ref: knowledge-md-chunker -->
  Splits markdown at paragraph/section boundaries into chunks. Returns array of strings.
  Files: `web/app/modules/knowledge/services/md_chunker.rb`, `web/spec/modules/knowledge/services/md_chunker_spec.rb`
  Required tests: splits at blank lines; splits at heading boundaries; single-paragraph file returns one chunk; empty string returns []

- [ ] Implement `Knowledge::EmbedderService` + `Knowledge::OpenAiEmbedder` <!-- ref: knowledge-embedder -->
  Abstract interface `embed(text) → Array<Float>`. `OpenAiEmbedder` calls OpenAI API, API key wrapped in `Secret`. Provider swappable via `EMBEDDER_PROVIDER=openai|ollama` env var.
  Files: `web/app/modules/knowledge/services/embedder_service.rb`, `web/app/modules/knowledge/services/open_ai_embedder.rb`, `web/spec/modules/knowledge/services/open_ai_embedder_spec.rb`
  Required tests: API key never appears in logs; stub HTTP call returns embedding array; wrong provider raises; `EMBEDDER_PROVIDER` env var selects implementation

- [ ] Implement `Knowledge::IndexerJob` <!-- ref: knowledge-indexer-job -->
  Active Job on `knowledge` queue. Given a node_id: reads associated spec file, computes SHA256, skips if unchanged, chunks with MdChunker, embeds each chunk, upserts LibraryItem records. Idempotent.
  Files: `web/app/modules/knowledge/jobs/indexer_job.rb`, `web/spec/modules/knowledge/jobs/indexer_job_spec.rb`
  Required tests: unchanged file (same SHA256) → no embedding call; changed file → upserts chunks; enqueued on `knowledge` queue; idempotent on re-run

- [ ] Implement `Knowledge::ContextRetriever` <!-- ref: knowledge-context-retriever -->
  `retrieve(query:, limit:, node_id: nil)` → `LibraryItem[]` ordered by cosine similarity. With `node_id`: scopes to that node and ancestors via NodeEdge traversal.
  Files: `web/app/modules/knowledge/services/context_retriever.rb`, `web/spec/modules/knowledge/services/context_retriever_spec.rb`
  Required tests: returns top-N by cosine similarity; node_id scopes to node tree; no node_id returns global results; empty knowledge base returns []


## Section 8 — Analytics Module <!-- ref: analytics-module -->

- [ ] Create `Analytics::AnalyticsEvent` model and migration <!-- ref: analytics-event-model -->
  Schema per `specs/system/analytics/spec.md` + `specs/platform/rails/system/analytics.md`: id (uuid), org_id (uuid), distinct_id (string), event_name (string), node_id (uuid, nullable, indexed), properties (jsonb), timestamp (timestamptz), received_at (timestamptz). Index on (org_id, event_name, timestamp). Append-only — no update/destroy exposed.
  Files: `web/app/modules/analytics/models/analytics_event.rb`, migration, `web/spec/models/analytics/analytics_event_spec.rb`, factory
  Required tests: no update method exposed; no destroy method exposed; node_id indexed; factory valid

- [ ] Create `Analytics::AuditEvent` model and migration <!-- ref: analytics-audit-event-model -->
  Append-only. severity enum: info/warning/critical. Index on (org_id, created_at).
  Files: `web/app/modules/analytics/models/audit_event.rb`, migration, `web/spec/models/analytics/audit_event_spec.rb`
  Required tests: severity validates; append-only; factory valid

- [ ] Create `Analytics::LlmMetric` model and migration <!-- ref: analytics-llm-metric-model -->
  Per-agent-run cost/token record. `cost_estimate_usd` decimal(10,6). Index on (org_id, provider, model, created_at).
  Files: `web/app/modules/analytics/models/llm_metric.rb`, migration, `web/spec/models/analytics/llm_metric_spec.rb`
  Required tests: cost_estimate_usd precision; factory valid

- [ ] Create `Analytics::FeatureFlag` model and migration <!-- ref: analytics-feature-flag-model -->
  Schema per `specs/system/feature-flags/spec.md` + `specs/platform/rails/product/analytics.md`: key (string, unique per org), enabled (boolean, default false), variant (string, nullable), metadata (jsonb), status (active/archived), org_id. `enabled?` fires `$feature_flag_called` automatically. Archived flags return false without raising. `metadata.hypothesis` required on creation → 422 if missing.
  Files: `web/app/modules/analytics/models/feature_flag.rb`, migration, `web/spec/models/analytics/feature_flag_spec.rb`, factory
  Required tests: `FeatureFlag.enabled?` returns false for unknown flag without raising; archived flag returns false; duplicate key per org → 422; missing metadata.hypothesis → 422; factory valid

- [ ] Implement `Analytics::AuditLogger` <!-- ref: analytics-audit-logger -->
  `AuditLogger.log(...)` — async via `AuditLogJob` on `analytics` queue. Never raises. Failure logs to Rails logger.
  Files: `web/app/modules/analytics/services/audit_logger.rb`, `web/app/modules/analytics/jobs/audit_log_job.rb`, `web/spec/modules/analytics/services/audit_logger_spec.rb`
  Required tests: enqueues AuditLogJob; failure does not raise; logs error to Rails logger on failure

- [ ] Create `Analytics::MetricsController` <!-- ref: analytics-metrics-controller -->
  JWT auth required. `GET /api/analytics/llm`, `GET /api/analytics/loops`, `GET /api/analytics/summary`, `GET /api/analytics/events`, `GET /api/analytics/flags/:key`.
  Files: `web/app/modules/analytics/controllers/analytics/metrics_controller.rb`, routes update, `web/spec/requests/analytics/metrics_spec.rb`
  Required tests: GET /api/analytics/llm returns cost by provider/model; GET /api/analytics/loops returns run counts; GET /api/analytics/summary returns totals; GET /api/analytics/events paginated; GET /api/analytics/flags/:key returns exposure counts; unauthenticated → 401


## Section 9 — Agents Module <!-- ref: agents-module -->

- [ ] Create `Agents::AgentRun` model and migration <!-- ref: agents-agent-run-model -->
  Schema per `specs/system/agent-runner/spec.md` + `specs/platform/rails/system/agents.md`: run_id (uuid), actor_id (FK→ledger_actors), node_id (FK→ledger_nodes), parent_run_id (uuid, nullable), mode (enum: plan/build/review/reflect/research), provider, model, prompt_sha256, status (running/waiting_for_input/completed/failed), input_tokens, output_tokens, cost_estimate_usd decimal(10,6), duration_ms, response_truncated (boolean), source_library_item_ids (jsonb, default []). Unique index on (run_id, iteration).
  Files: `web/app/modules/agents/models/agent_run.rb`, migration, `web/spec/models/agents/agent_run_spec.rb`, factory
  Required tests: mode enum validates; unique index on (run_id, iteration) enforced at DB; cost_estimate_usd precision; factory valid

- [ ] Create `Agents::AgentRunTurn` model and migration <!-- ref: agents-agent-run-turn-model -->
  Schema: id (uuid), run_id (FK→agent_runs), position (integer), kind (enum: agent_question/human_input/llm_response/tool_result), content (text), purged_at (timestamptz, nullable), created_at.
  Files: `web/app/modules/agents/models/agent_run_turn.rb`, migration, `web/spec/models/agents/agent_run_turn_spec.rb`
  Required tests: kind enum validates; purged_at nullable; factory valid

- [ ] Implement `Agents::PromptDeduplicator` <!-- ref: agents-prompt-deduplicator -->
  Queries AgentRun for recent successful match on `prompt_sha256` + `mode` within 24h. Returns cached run or nil.
  Files: `web/app/modules/agents/services/prompt_deduplicator.rb`, `web/spec/modules/agents/services/prompt_deduplicator_spec.rb`
  Required tests: returns cached run on hash match within 24h; returns nil on miss; ignores failed runs; ignores runs older than 24h

- [ ] Implement `Agents::ProviderAdapter` + adapters <!-- ref: agents-provider-adapters -->
  Base class with interface: `build_prompt(...)`, `parse_response(...)`, `max_context_tokens`. `ProviderAdapter.for("claude")` → `ClaudeAdapter`; `for("kiro")` → `KiroAdapter`; `for("openai")` → `OpenAiAdapter`. Unknown provider raises.
  Files: `web/app/modules/agents/services/provider_adapter.rb`, `web/app/modules/agents/services/claude_adapter.rb`, `web/app/modules/agents/services/kiro_adapter.rb`, `web/app/modules/agents/services/open_ai_adapter.rb`, `web/spec/modules/agents/services/provider_adapter_spec.rb`
  Required tests: `ProviderAdapter.for("claude")` returns ClaudeAdapter; `for("kiro")` returns KiroAdapter; `for("openai")` returns OpenAiAdapter; unknown provider raises; adding adapter requires no orchestration changes

- [ ] Create `Agents::AgentRunsController` <!-- ref: agents-agent-runs-controller -->
  `POST /api/agent_runs/start` (JWT auth), `POST /api/agent_runs/:id/complete` (sidecar token auth). Duplicate run_id+iteration → 422. Complete endpoint triggers `Ledger::SpecWatcherJob` when mode is plan. Complete endpoint calls `Analytics::AuditLogger`.
  Files: `web/app/modules/agents/controllers/agents/agent_runs_controller.rb`, routes update, `web/spec/requests/agents/agent_runs_spec.rb`
  Required tests: start creates AgentRun with status running; duplicate run_id+iteration → 422; complete updates status; complete with mode=plan triggers SpecWatcherJob; complete calls AuditLogger; unauthenticated start → 401; wrong sidecar token on complete → 401

- [ ] Create kiro-agents config files <!-- ref: agents-kiro-configs -->
  Per `specs/platform/rails/system/agents.md`: `kiro-agents/ralph_build.json`, `ralph_plan.json`, `ralph_research.json`, `ralph_review.json` with correct tool lists.
  Files: `kiro-agents/ralph_build.json`, `kiro-agents/ralph_plan.json`, `kiro-agents/ralph_research.json`, `kiro-agents/ralph_review.json`
  Required tests: JSON files parse without error; tool lists match spec


## Section 10 — Sandbox Module <!-- ref: sandbox-module -->

- [ ] Create `Sandbox::ContainerRun` model and migration <!-- ref: sandbox-container-run-model -->
  Schema per `specs/system/sandbox/spec.md` + `specs/platform/rails/system/sandbox.md`: id (uuid), image (string), command (jsonb — array), status (enum: pending/running/complete/failed), exit_code (integer, nullable), stdout (text, nullable), stderr (text, nullable), started_at (timestamptz, nullable), finished_at (timestamptz, nullable), agent_run_id (uuid, nullable FK). `duration` computed from started_at/finished_at.
  Files: `web/app/modules/sandbox/models/container_run.rb`, migration, `web/spec/models/sandbox/container_run_spec.rb`, factory
  Required tests: status enum validates; agent_run_id nullable at DB level; duration computed correctly; factory valid

- [ ] Implement `Sandbox::DockerDispatcher` <!-- ref: sandbox-docker-dispatcher -->
  `dispatch(image:, command:, env: {}, timeout: 300)` → `{exit_code:, stdout:, stderr:, duration_ms:}`. Shells out to `docker run --rm`. Command passed as argument array (no shell interpolation). Env vars with secret values filtered before logging. Containers run non-root, no `--privileged`. Timeout kills container and returns non-zero exit.
  Files: `web/app/modules/sandbox/services/docker_dispatcher.rb`, `web/spec/modules/sandbox/services/docker_dispatcher_spec.rb`
  Required tests: successful command returns exit_code 0 and stdout; failed command returns non-zero without raising; env vars with secret values not logged; timeout kills container and returns non-zero; ContainerRun record created before dispatch and updated after; command passed as array not shell string


## Section 11 — Go Runner + Analytics Sidecar <!-- ref: go-runner-analytics-sidecar -->

- [ ] [SPIKE] Research Go runner source and analytics sidecar architecture <!-- ref: spike-go-runner-source -->
  `specs/project-prd.md` open question: "Go runner: copy from unpossible1 into `runner/` or reference as submodule?" Also: analytics sidecar `POST /capture` endpoint design (in-memory queue, batch flush). Research both before writing any Go code.
  Run `./loop.sh research spike-go-runner-source`
  Blocks: `infra/Dockerfile.runner`, `infra/Dockerfile.analytics`, all Go source tasks

- [ ] Scaffold Go runner (`runner/`) <!-- ref: go-runner-scaffold -->
  Blocked by spike. Go 1.22, port 8080, `/healthz` endpoint. Minimal scaffold only — no business logic until agent runner spec is implemented.
  Files: `runner/main.go`, `runner/go.mod`, `infra/Dockerfile.runner`
  Required tests: `docker build -f infra/Dockerfile.runner .` exits 0; `GET /healthz` returns 200

- [ ] Scaffold Go analytics sidecar (`analytics-sidecar/`) <!-- ref: analytics-sidecar-scaffold -->
  Blocked by spike. Go 1.22, port 9100. `POST /capture` accepts single event or batch array, returns 202 immediately. In-memory queue, batch flush to Postgres every 5s or 100 events. Internal network only.
  Files: `analytics-sidecar/main.go`, `analytics-sidecar/go.mod`, `infra/Dockerfile.analytics`
  Required tests: `POST /capture` returns 202 immediately; events flushed within 5s or 100 events; `docker build -f infra/Dockerfile.analytics .` exits 0


## Section 12 — API Documentation (rswag) <!-- ref: api-docs -->

- [ ] Configure rswag <!-- ref: api-docs-rswag-config -->
  Add `rswag-api`, `rswag-ui`, `rswag-specs` to Gemfile. Create `web/spec/swagger_helper.rb`. Create `web/config/initializers/rswag.rb`. Swagger UI at `/api/docs` (unauthenticated). Raw spec at `swagger/v1/swagger.yaml`.
  Files: `web/Gemfile`, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`, routes update
  Required tests: `GET /api/docs` returns 200 without authentication; `rake rswag:specs:swaggerize` exits 0

- [ ] Convert existing request specs to rswag DSL <!-- ref: api-docs-convert-specs -->
  Convert `spec/requests/api/auth_spec.rb` and `spec/requests/ledger/nodes_spec.rb` to rswag DSL so they contribute to `swagger/v1/swagger.yaml`. Every endpoint must cover: 200/201 happy path, 401 unauthenticated, 422 invalid input, 404 where applicable.
  Files: `web/spec/requests/api/auth_spec.rb`, `web/spec/requests/ledger/nodes_spec.rb`, `web/swagger/v1/swagger.yaml`
  Required tests: `rake rswag:specs:swaggerize` exits 0; swagger.yaml lists all implemented endpoints; all existing test cases still pass


## Section 13 — Multi-tenancy Clarification <!-- ref: multi-tenancy -->

- [ ] [SPIKE] Resolve multi-tenancy scope for Phase 0 <!-- ref: spike-multi-tenancy -->
  `specs/project-prd.md` open question: "Multi-tenancy scope for Phase 0: single-org (hardcoded org_id = 1) or org creation flow?" Current code uses `DEFAULT_ORG_ID` env var in SpecWatcherJob. Clarify and document the decision. If single-org: add `DEFAULT_ORG_ID` to docker-compose env and document in AGENTS.md. If org creation: add org model and registration endpoint.
  Run `./loop.sh research spike-multi-tenancy`
  Blocks: any work that touches org_id provisioning

