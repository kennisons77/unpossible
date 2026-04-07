# Implementation Plan

Generated: 2026-04-02 (gap analysis refresh)
Phase: 0 (Local Development — Docker Compose only)

> Scope: Phase 0 only. No CI, no k8s, no staging.
> Tasks module is out of scope — no spec exists. Do not plan tasks for it.
> `metadata.hypothesis` on FeatureFlag is NOT required in Phase 0 per the PRD. The platform override says required on creation, but the PRD is the higher authority and explicitly says optional.
> Go runner source is an open question — blocks all Go sidecar work until resolved.

---

## Gap Analysis Notes

**Confirmed implemented (Sections 1–6 of prior plan complete):**
- infra/Dockerfile (multi-stage ruby:3.3-slim, non-root, port 3000)
- infra/Dockerfile.test + infra/entrypoint-test.sh
- infra/docker-compose.yml (rails + postgres; go_runner and analytics commented out)
- infra/docker-compose.test.yml (ephemeral test stack)
- Rails skeleton: Gemfile, config, autoloading, Solid Queue
- RSpec + Rubocop + SimpleCov + Lograge configured
- Secret value object, Security::LogRedactor, Security::PromptSanitizer
- rack-attack rate limiting, brakeman + bundler-audit Rake tasks
- Module scaffold (knowledge, tasks, agents, sandbox, analytics, ledger) — namespace files + .keep dirs
- JWT authentication (AuthToken, ApplicationController#authenticate!, POST /api/auth/token)
- Sidecar token auth (X-Sidecar-Token header, sidecar_token/sidecar_secret methods)
- Ledger::Node model + 7 migrations
- Ledger::NodeEdge model
- Ledger::ActorProfile + Ledger::Actor models
- Ledger::NodeAuditEvent model (append-only, immutable)
- Ledger::NodeLifecycleService (transition, accept, rebut, create_child_question, attach_research, record_verdict)
- Ledger::NodesController (GET/POST /api/nodes, GET /api/nodes/:id, verdict, comments)
- Ledger::SpecWatcherJob (polls specs, creates nodes, detects changes/deletes/git reverts, triggers Knowledge::IndexerJob)
- Ledger::PlanFileSyncService (syncs plan file checkboxes to nodes, idempotent, orphan detection)
- Ledger UI views (current, open, tree, node detail) + MarkdownHelper
- Ledger::LedgerController (HTML views with session auth)
- Request specs for Ledger UI, Ledger Nodes API, API auth
- Model specs for Node, NodeEdge, NodeAuditEvent, Actor, ActorProfile
- Service specs for NodeLifecycleService, PlanFileSyncService
- Job specs for SpecWatcherJob
- Factory specs for module scaffold
- All bug fixes from prior plan Section 5 completed

**Remaining gaps:**
- Infrastructure: Go sidecars blocked on open question; docker-compose env vars incomplete; redis decision needed
- Ledger: NodesController#comment is a stub; missing test coverage for attach_research, research blocking, accepted dependency enforcement
- MarkdownHelper has no spec
- Knowledge module: entirely empty (.keep files only)
- Analytics module: entirely empty (.keep files only)
- Agents module: entirely empty (.keep files only)
- Sandbox module: entirely empty (.keep files only)
- Feature flags: no model, no controller, no tests
- rswag not configured (no swagger_helper.rb, no Swagger UI)
- LOOKUP.md has naming inconsistencies with actual specs
- Ledger UI missing has_blockers filter, resolution field on detail page

**Open questions (require spikes before dependent work can proceed):**
- Go runner source: copy from unpossible1 into runner/ or reference as submodule? → blocks Dockerfile.runner, Dockerfile.analytics, all Go sidecar tasks
- Multi-tenancy scope: single-org (hardcoded org_id = 1) or org creation flow? → blocks org provisioning work
- MinIO: needed in Phase 0? What is stored there? → blocks Knowledge::LibraryItem file attachment approach
- stable_ref agent title drift: semantic dedup strategy? → blocks stable_ref beyond plan file sync
- Redis in Phase 0: Solid Queue uses Postgres, no redis gem in Gemfile — is redis needed?

**Out of scope:**
- Tasks module — scaffolded but no spec exists anywhere. LOOKUP.md references Tasks::TaskLifecycleService but there is no spec defining what this module does. It may be subsumed by the Ledger (plan items are nodes). Do not plan tasks for it.
- Backfill from activity.md (UAT-5) — post-MVP per the PRD
- Ideas.md sync — described in spec but post-MVP
- Auto-open bug on failed interaction — described in PRD as MVP but depends on interaction scope nodes which have no implementation path in Phase 0
- Streaming output, network isolation, resource caps for sandbox — post-MVP
- CI enforcement, API versioning — post-MVP

---

## Section 7 — Spikes (Unblock Dependent Work)

- [ ] 7.1 — SPIKE: Go runner source decision <!-- ref: spike-go-runner-source -->
  Decide: copy Go runner from unpossible1 into `runner/` or reference as git submodule.
  Deliverable: written decision in `specs/research/go-runner-source.md` with rationale.
  **Blocks:** all Go sidecar tasks (Section 16).
  Files: `specs/research/go-runner-source.md`

- [ ] 7.2 — SPIKE: Redis necessity in Phase 0 <!-- ref: spike-redis-phase0 -->
  Solid Queue uses Postgres. No redis gem in Gemfile. Determine if any Phase 0 feature requires Redis.
  Deliverable: written decision in `specs/research/redis-phase0.md`. If not needed, remove commented redis from docker-compose files. If needed, add redis gem and uncomment.
  Files: `specs/research/redis-phase0.md`, `infra/docker-compose.yml`, `infra/docker-compose.test.yml`

- [ ] 7.3 — SPIKE: Multi-tenancy scope for Phase 0 <!-- ref: spike-multi-tenancy -->
  Decide: hardcoded `org_id = 1` everywhere, or minimal org creation flow?
  Deliverable: written decision in `specs/research/multi-tenancy-phase0.md`.
  Files: `specs/research/multi-tenancy-phase0.md`

---

## Section 8 — Infrastructure Fixes (High Priority)

- [ ] 8.1 — docker-compose.yml: extract AUTH_SECRET to env var with default <!-- ref: infra-auth-secret-env -->
  The hardcoded hex string works but should be `AUTH_SECRET=${AUTH_SECRET:-<default>}` for consistency.
  Add `DEFAULT_ORG_ID=1` and `SIDECAR_TOKEN` env vars to rails service.
  Files: `infra/docker-compose.yml`
  Required tests: `docker compose config` validates; existing test suite still passes.

- [ ] 8.2 — Fix LOOKUP.md naming inconsistencies <!-- ref: fix-lookup-naming -->
  Update both LOOKUP.md files to match actual spec names:
  - `Knowledge::RetrievalService` → `Knowledge::ContextRetriever`
  - `Sandbox::ContainerDispatchService` → `Sandbox::DockerDispatcher`
  - `Analytics::AuditLogService` → `Analytics::AuditLogger`
  - `Analytics::FeatureFlagService` → `Analytics::FeatureFlag` (model)
  - `Agents::RunStorageService` → `Agents::AgentRunsController`
  - Remove `Tasks::TaskLifecycleService` reference (no spec exists)
  - Update practices LOOKUP.md `Agents::RunStorageService` → `Agents::PromptDeduplicator`
  Files: `web/app/modules/LOOKUP.md`, `specs/practices/LOOKUP.md`
  Required tests: none (documentation only).

---

## Section 9 — Ledger Gaps (Missing Tests + Comment Rewrite)

- [ ] 9.1 — Rewrite NodesController#comment to create comment nodes <!-- ref: ledger-comment-rewrite -->
  Current action is a stub that enqueues IndexerJob and returns `{status: 'queued'}`.
  Per spec: comments are answer nodes (kind: answer, answer_type: terminal, scope: intent) attached to the parent node via a `contains` edge. The comment body should be indexed as a knowledge chunk via `Knowledge::IndexerJob`.
  Also: remove the incorrect guard that rejects comments on answer nodes — the spec says comments attach to "any node", and the comment itself is a new answer node, not a mutation of the parent.
  Files: `web/app/modules/ledger/controllers/nodes_controller.rb`
  Required tests (in `web/spec/requests/ledger/nodes_spec.rb`):
  - POST /api/nodes/:id/comments with valid body → 201, creates answer node with correct kind/answer_type/scope
  - Created comment node has `contains` edge to parent
  - `Knowledge::IndexerJob` enqueued with parent node ID after comment creation
  - Comment body stored in the created node
  - Missing body → 422
  - Unauthenticated → 401

- [ ] 9.2 — Add tests for NodeLifecycleService.attach_research (UAT-6 part 1) <!-- ref: ledger-test-attach-research -->
  The method exists but has zero test coverage.
  Files: `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb`
  Required tests:
  - `attach_research` creates a code-scoped question with `research` edge to parent
  - Created spike has status `proposed`
  - Created spike has kind `question` and scope `code`
  - NodeEdge with edge_type `research` links parent to spike

- [ ] 9.3 — Add tests for research spike blocking on `accepted` transition (UAT-6 part 2) <!-- ref: ledger-test-research-blocking -->
  Spec says: "A question cannot transition to `accepted` or `in_progress` while any `research` spike is not `closed`."
  `in_progress` blocking is tested; `accepted` is not.
  Files: `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb`
  Required tests:
  - Transition to `accepted` rejected when open research spike exists
  - Transition to `accepted` succeeds after research spike is closed

- [ ] 9.4 — Add tests for dependency enforcement on `accepted` transition <!-- ref: ledger-test-dep-accepted -->
  Spec says: "A question cannot transition to `accepted` or `in_progress` while any `depends_on` question is not `closed`."
  Only `in_progress` is tested.
  Files: `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb`
  Required tests:
  - Transition to `accepted` rejected when `depends_on` node is not closed
  - Transition to `accepted` succeeds after dependency is closed

- [ ] 9.5 — Add MarkdownHelper spec <!-- ref: ledger-markdown-helper-spec -->
  Files: `web/spec/helpers/markdown_helper_spec.rb`
  Required tests:
  - Renders markdown to HTML
  - Renders fenced code blocks with syntax highlighting
  - Sanitizes dangerous HTML

---

## Section 10 — API Documentation (rswag)

- [ ] 10.1 — Configure rswag and Swagger UI <!-- ref: api-rswag-setup -->
  Add rswag gems to Gemfile. Create swagger_helper.rb, rswag initializer. Mount Swagger UI at `/api/docs`.
  Ref: `specs/system/api/prd.md`, `specs/platform/rails/system/api-standards.md`
  Files: `web/Gemfile`, `web/Gemfile.lock`, `web/spec/swagger_helper.rb`, `web/config/initializers/rswag.rb`, `web/config/routes.rb`, `web/swagger/v1/swagger.yaml`
  Required tests:
  - `GET /api/docs` returns 200 without authentication
  - `rake rswag:specs:swaggerize` exits 0

- [ ] 10.2 — Convert existing request specs to rswag format <!-- ref: api-rswag-convert -->
  Convert `nodes_spec.rb`, `auth_spec.rb`, `ledger_spec.rb` to use rswag DSL so they contribute to the generated OpenAPI spec.
  Files: `web/spec/requests/ledger/nodes_spec.rb`, `web/spec/requests/api/auth_spec.rb`, `web/spec/requests/ledger/ledger_spec.rb`, `web/swagger/v1/swagger.yaml`
  Required tests: all existing tests still pass; `rake rswag:specs:swaggerize` exits 0 and lists all endpoints.

---

## Section 11 — Feature Flags Module

> Note: `metadata.hypothesis` is NOT required in Phase 0 per the PRD (`specs/system/feature-flags/prd.md`: "metadata optional — hypothesis, metric, owner fields available in metadata jsonb but not required in Phase 0"). The platform override (`specs/platform/rails/product/analytics.md`) says "hypothesis field required on creation → 422 if missing" but the PRD is the higher authority. Follow the PRD.

- [ ] 11.1 — Analytics::FeatureFlag model + migration <!-- ref: ff-model -->
  Schema per `specs/system/feature-flags/spec.md`: key (string, unique per org), enabled (boolean, default false), variant (string, nullable), metadata (jsonb), status (active/archived enum), org_id.
  `metadata.hypothesis` is optional — no validation on creation.
  `FeatureFlag.enabled?(org_id:, key:)` class method: returns false for unknown or archived flags without raising.
  Files: `web/app/modules/analytics/models/feature_flag.rb`, `web/db/migrate/XXX_create_analytics_feature_flags.rb`
  Required tests (`web/spec/models/analytics/feature_flag_spec.rb`):
  - `enabled?` returns false for unknown key
  - `enabled?` returns false for archived flag
  - `enabled?` returns true for active enabled flag
  - `enabled?` returns false for active disabled flag
  - Key unique per org — duplicate raises ActiveRecord::RecordNotUnique
  - Valid without `metadata.hypothesis`

- [ ] 11.2 — Feature flags API controller <!-- ref: ff-controller -->
  `POST /api/feature_flags` — create flag with key, org_id. Duplicate key → 422. `metadata.hypothesis` not required.
  `PATCH /api/feature_flags/:key` — update enabled field.
  `GET /api/feature_flags` — list active flags (archived excluded by default, `?status=archived` to include).
  JWT auth required on all endpoints.
  Files: `web/app/modules/analytics/controllers/feature_flags_controller.rb`, `web/config/routes.rb`
  Required tests (`web/spec/requests/analytics/feature_flags_spec.rb`):
  - POST with valid key → 201
  - POST with duplicate key → 422
  - POST without `metadata.hypothesis` → 201 (not 422)
  - PATCH sets enabled → 200
  - GET returns active flags, excludes archived
  - GET with `?status=archived` includes archived
  - Unauthenticated → 401

---

## Section 12 — Knowledge Module

- [ ] 12.1 — Knowledge::LibraryItem model + migration <!-- ref: knowledge-library-item -->
  Schema per `specs/system/knowledge/spec.md`: id (UUID), node_id (FK → Node, nullable), source_path (nullable), source_sha (nullable), chunk_index (integer), content_type (enum: markdown, plain_text, link_reference, llm_response, error_context), content (text), embedding (vector(1536)), org_id.
  Unique index on `(source_path, chunk_index)` for upsert idempotency.
  Enable pgvector extension in migration.
  Files: `web/app/modules/knowledge/models/library_item.rb`, `web/db/migrate/XXX_create_knowledge_library_items.rb`, `web/db/migrate/XXX_enable_pgvector.rb`
  Required tests (`web/spec/models/knowledge/library_item_spec.rb`):
  - Valid with all required fields
  - content_type enum validates
  - Upsert on `(source_path, chunk_index)` is idempotent
  - node_id and source_path are nullable

- [ ] 12.2 — Knowledge::MdChunker service <!-- ref: knowledge-md-chunker -->
  Splits markdown at paragraph/section boundaries. Returns array of `{content:, chunk_index:}`.
  Ref: `specs/system/knowledge/spec.md` — "Chunking unit: paragraph/section level — semantic boundaries"
  Files: `web/app/modules/knowledge/services/md_chunker.rb`
  Required tests (`web/spec/modules/knowledge/services/md_chunker_spec.rb`):
  - Splits markdown into paragraph-level chunks
  - Preserves section headers with their content
  - Returns chunk_index for each chunk
  - Empty input returns empty array

- [ ] 12.3 — Knowledge::EmbedderService + OpenAiEmbedder <!-- ref: knowledge-embedder -->
  Abstract interface: `embed(text) → Array<Float>`. OpenAiEmbedder calls `text-embedding-3-small` (1536 dims). API key wrapped in `Secret`. Swappable via `EMBEDDER_PROVIDER=openai|ollama`.
  Files: `web/app/modules/knowledge/services/embedder_service.rb`, `web/app/modules/knowledge/services/open_ai_embedder.rb`
  Required tests (`web/spec/modules/knowledge/services/embedder_service_spec.rb`):
  - `EmbedderService.for("openai")` returns OpenAiEmbedder
  - `EmbedderService.for("ollama")` returns OllamaEmbedder (or raises NotImplementedError for Phase 0)
  - API key never appears in logs or error messages (stub HTTP call, verify Secret wrapping)

- [ ] 12.4 — Knowledge::ContextRetriever service <!-- ref: knowledge-context-retriever -->
  `retrieve(query:, limit:, node_id: nil)` — embeds query, runs pgvector cosine similarity search. Optional `node_id` scopes to that node and its ancestors via `contains` edges.
  Files: `web/app/modules/knowledge/services/context_retriever.rb`
  Required tests (`web/spec/modules/knowledge/services/context_retriever_spec.rb`):
  - Returns top-N chunks ordered by cosine similarity
  - `node_id` scopes results to that node tree
  - Returns empty array when no matches

- [ ] 12.5 — Knowledge::IndexerJob <!-- ref: knowledge-indexer-job -->
  Receives a node ID or source_path. Computes SHA256, skips if unchanged. Splits via MdChunker, embeds via EmbedderService, upserts LibraryItem records.
  Files: `web/app/modules/knowledge/jobs/indexer_job.rb`
  Required tests (`web/spec/modules/knowledge/jobs/indexer_job_spec.rb`):
  - Indexes markdown file into paragraph-level chunks with embeddings
  - Unchanged file (same SHA256) skipped — no embedding call made
  - Upsert on `(source_path, chunk_index)` is idempotent
  - Enqueued on `knowledge` queue

---

## Section 13 — Analytics Module (Rails Query Side)

> The Go analytics ingest sidecar (Section 15) is blocked on the Go runner spike (7.1). The Rails side — models, query API, audit logger — can proceed independently.

- [ ] 13.1 — Analytics::AnalyticsEvent model + migration <!-- ref: analytics-event-model -->
  Schema per `specs/system/analytics/spec.md`: id (UUID), org_id, distinct_id (string — opaque UUID), event_name (string), node_id (UUID, nullable, indexed), properties (jsonb), timestamp (timestamptz), received_at (timestamptz).
  Append-only: no update or destroy methods exposed.
  Index on `(org_id, event_name, timestamp)`.
  Files: `web/app/modules/analytics/models/analytics_event.rb`, `web/db/migrate/XXX_create_analytics_events.rb`
  Required tests (`web/spec/models/analytics/analytics_event_spec.rb`):
  - Valid with required fields
  - No update method exposed
  - No destroy method exposed
  - `distinct_id` stored as UUID string

- [ ] 13.2 — Analytics::AuditEvent model + migration <!-- ref: analytics-audit-event-model -->
  Append-only. Severity enum: info, warning, critical. Separate from AnalyticsEvent.
  Index on `(org_id, created_at)`.
  Files: `web/app/modules/analytics/models/audit_event.rb`, `web/db/migrate/XXX_create_analytics_audit_events.rb`
  Required tests (`web/spec/models/analytics/audit_event_spec.rb`):
  - Valid with required fields
  - Severity enum validates
  - No update or destroy methods exposed

- [ ] 13.3 — Analytics::LlmMetric model + migration <!-- ref: analytics-llm-metric-model -->
  Per agent run: provider, model, input_tokens, output_tokens, cost_estimate_usd (decimal(10,6)), mode, node_id, duration_ms.
  Index on `(org_id, provider, model, created_at)`.
  Files: `web/app/modules/analytics/models/llm_metric.rb`, `web/db/migrate/XXX_create_analytics_llm_metrics.rb`
  Required tests (`web/spec/models/analytics/llm_metric_spec.rb`):
  - Valid with required fields
  - cost_estimate_usd stored as decimal(10,6)

- [ ] 13.4 — Analytics::AuditLogger service + AuditLogJob <!-- ref: analytics-audit-logger -->
  `AuditLogger.log(...)` — async, fire-and-forget, never raises. Enqueues AuditLogJob on `analytics` queue.
  Files: `web/app/modules/analytics/services/audit_logger.rb`, `web/app/modules/analytics/jobs/audit_log_job.rb`
  Required tests (`web/spec/modules/analytics/services/audit_logger_spec.rb`):
  - `AuditLogger.log` enqueues AuditLogJob
  - `AuditLogger.log` does not raise on failure (logs to Rails logger instead)
  - AuditLogJob creates an AuditEvent record

- [ ] 13.5 — Analytics::MetricsController (query API) <!-- ref: analytics-metrics-controller -->
  JWT auth required on all endpoints.
  `GET /api/analytics/llm` — cost/tokens by provider/model, filterable by date range.
  `GET /api/analytics/loops` — run counts, failure rates by mode.
  `GET /api/analytics/summary` — total cost this week, loop error rate.
  `GET /api/analytics/events` — paginated event list, filterable by event_name, org_id, date range.
  `GET /api/analytics/flags/:key` — exposure counts per variant (depends on 11.1).
  Files: `web/app/modules/analytics/controllers/metrics_controller.rb`, `web/config/routes.rb`
  Required tests (`web/spec/requests/analytics/metrics_spec.rb`):
  - GET /api/analytics/llm returns aggregated cost data
  - GET /api/analytics/loops returns run counts
  - GET /api/analytics/summary returns summary
  - GET /api/analytics/events returns paginated events
  - GET /api/analytics/flags/:key returns exposure counts
  - Unauthenticated → 401 on all endpoints

---

## Section 14 — Sandbox Module

- [ ] 14.1 — Sandbox::ContainerRun model + migration <!-- ref: sandbox-container-run -->
  Schema per `specs/system/sandbox/spec.md`: image, command, status (enum: pending/running/complete/failed), exit_code, stdout, stderr, started_at, finished_at, agent_run_id (FK, nullable).
  Files: `web/app/modules/sandbox/models/container_run.rb`, `web/db/migrate/XXX_create_sandbox_container_runs.rb`
  Required tests (`web/spec/models/sandbox/container_run_spec.rb`):
  - Status enum validates
  - agent_run_id is nullable
  - Duration computed from started_at/finished_at

- [ ] 14.2 — Sandbox::DockerDispatcher service <!-- ref: sandbox-docker-dispatcher -->
  `dispatch(image:, command:, env: {})` — shells out to `docker run --rm`, command as argument array (no shell interpolation). Returns `{exit_code:, stdout:, stderr:, duration_ms:}`. Configurable timeout. Env vars containing secret values filtered before logging. Creates ContainerRun record before dispatch, updates with final status.
  Files: `web/app/modules/sandbox/services/docker_dispatcher.rb`
  Required tests (`web/spec/modules/sandbox/services/docker_dispatcher_spec.rb`):
  - Successful command returns exit_code 0 and stdout
  - Failed command returns non-zero exit_code without raising
  - Env vars containing secret values not logged
  - Timeout kills container and returns non-zero exit
  - ContainerRun record created and updated with final status
  - Command passed as argument array — no shell interpolation

---

## Section 15 — Agents Module

- [ ] 15.1 — Agents::AgentRun model + migration <!-- ref: agents-agent-run -->
  Schema per `specs/system/agent-runner/spec.md`: run_id (UUID), actor_id (FK → Actor), node_id (FK → Node), parent_run_id (nullable), mode (enum: plan/build/review/reflect/research), provider, model, prompt_sha256, status (enum: running/waiting_for_input/completed/failed), input_tokens, output_tokens, cost_estimate_usd (decimal(10,6)), duration_ms, response_truncated (boolean), source_node_ids (jsonb).
  Unique index on `(run_id)`.
  Files: `web/app/modules/agents/models/agent_run.rb`, `web/db/migrate/XXX_create_agents_agent_runs.rb`
  Required tests (`web/spec/models/agents/agent_run_spec.rb`):
  - Mode enum validates
  - Status enum validates
  - parent_run_id is nullable
  - source_node_ids defaults to []

- [ ] 15.2 — Agents::AgentRunTurn model + migration <!-- ref: agents-agent-run-turn -->
  Schema per spec: id, run_id (FK → AgentRun), position (integer), kind (enum: agent_question/human_input/llm_response/tool_result), content (text), purged_at (nullable), created_at.
  Files: `web/app/modules/agents/models/agent_run_turn.rb`, `web/db/migrate/XXX_create_agents_agent_run_turns.rb`
  Required tests (`web/spec/models/agents/agent_run_turn_spec.rb`):
  - Kind enum validates
  - Belongs to AgentRun
  - purged_at nullable

- [ ] 15.3 — Agents::PromptDeduplicator service <!-- ref: agents-prompt-dedup -->
  Queries AgentRun for recent successful match on `prompt_sha256` + `mode` within max age (default 24h). Returns cached run or nil. Ignores failed runs.
  Files: `web/app/modules/agents/services/prompt_deduplicator.rb`
  Required tests (`web/spec/modules/agents/services/prompt_deduplicator_spec.rb`):
  - Returns cached run when SHA matches within 24h
  - Returns nil when no match
  - Ignores failed runs
  - Ignores runs older than max age

- [ ] 15.4 — Agents::ProviderAdapter + concrete adapters <!-- ref: agents-provider-adapters -->
  Base class with `build_prompt`, `parse_response`, `max_context_tokens`. `ProviderAdapter.for(provider_string)` returns correct adapter. ClaudeAdapter, KiroAdapter, OpenAiAdapter.
  Files: `web/app/modules/agents/services/provider_adapter.rb`, `web/app/modules/agents/services/claude_adapter.rb`, `web/app/modules/agents/services/kiro_adapter.rb`, `web/app/modules/agents/services/open_ai_adapter.rb`
  Required tests (`web/spec/modules/agents/services/provider_adapter_spec.rb`):
  - `ProviderAdapter.for("claude")` returns ClaudeAdapter
  - `ProviderAdapter.for("kiro")` returns KiroAdapter
  - `ProviderAdapter.for("openai")` returns OpenAiAdapter
  - `ProviderAdapter.for("unknown")` raises ArgumentError

- [ ] 15.5 — Agents::AgentRunsController <!-- ref: agents-controller -->
  `POST /api/agent_runs/start` — JWT auth. Creates AgentRun with status `running`, enqueues job. Concurrent run for same actor → 409. Dedup hit returns cached run.
  `POST /api/agent_runs/:id/complete` — sidecar token auth (X-Sidecar-Token). Updates record with results.
  `POST /api/agent_runs/:id/input` — JWT auth. Appends human_input turn, re-enqueues job.
  Duplicate run_id → 422.
  Files: `web/app/modules/agents/controllers/agent_runs_controller.rb`, `web/config/routes.rb`
  Required tests (`web/spec/requests/agents/agent_runs_spec.rb`):
  - POST /start creates AgentRun with status running → 201
  - POST /start with concurrent active run for same actor → 409
  - POST /start with dedup hit returns cached run → 200
  - POST /:id/complete updates record → 200
  - POST /:id/complete without sidecar token → 401
  - POST /:id/input appends human_input turn → 200
  - Duplicate run_id → 422
  - Unauthenticated → 401

- [ ] 15.6 — Kiro agent config files <!-- ref: agents-kiro-configs -->
  Per `specs/platform/rails/system/agents.md`: ralph_build.json, ralph_plan.json, ralph_research.json, ralph_review.json with their respective tool lists.
  Files: `kiro-agents/ralph_build.json`, `kiro-agents/ralph_plan.json`, `kiro-agents/ralph_research.json`, `kiro-agents/ralph_review.json`
  Required tests: none (static config files).

---

## Section 16 — Go Sidecars (BLOCKED on Spike 7.1)

> All tasks in this section are blocked until the Go runner source decision (7.1) is resolved.

- [ ] 16.1 — Go runner sidecar (Dockerfile.runner + source) <!-- ref: go-runner-sidecar -->
  **Blocked on:** 7.1 (Go runner source decision).
  Create `runner/main.go` (or configure submodule). Create `infra/Dockerfile.runner`. Uncomment go_runner service in docker-compose.yml.
  Endpoints: `POST /run` (Basic Auth), `GET /healthz`, `GET /ready`, `GET /metrics`.
  Files: `runner/main.go`, `runner/go.mod`, `infra/Dockerfile.runner`, `infra/docker-compose.yml`
  Required tests: `go test ./...` exits 0; POST /run without auth → 401; concurrent POST /run → 409.

- [ ] 16.2 — Go analytics ingest sidecar (Dockerfile.analytics + source) <!-- ref: go-analytics-sidecar -->
  **Blocked on:** 7.1 (Go runner source decision — same build toolchain).
  Create `analytics-sidecar/main.go`. Create `infra/Dockerfile.analytics`. Uncomment analytics service in docker-compose.yml.
  `POST /capture` returns 202 immediately. In-memory queue, batch flush every 5s or 100 events. Buffers on Postgres unavailability. `GET /healthz`.
  Files: `analytics-sidecar/main.go`, `analytics-sidecar/go.mod`, `infra/Dockerfile.analytics`, `infra/docker-compose.yml`
  Required tests: `go test ./...` exits 0; POST /capture returns 202; events flushed within 5s; events buffered on Postgres unavailability; non-UUID distinct_id rejected.

- [ ] 16.3 — Wire FeatureFlag.enabled? to fire $feature_flag_called via analytics sidecar <!-- ref: ff-exposure-event -->
  **Blocked on:** 16.2 (analytics sidecar must exist to receive the event).
  `FeatureFlag.enabled?` fires `$feature_flag_called` event to `POST /capture` on the analytics sidecar. No manual instrumentation at call sites.
  Files: `web/app/modules/analytics/models/feature_flag.rb`
  Required tests:
  - `enabled?` sends `$feature_flag_called` event to analytics sidecar
  - Event includes flag_key, variant, enabled fields

---

## Section 17 — Ledger UI Polish (Low Priority)

- [ ] 17.1 — Add has_blockers filter to LedgerController#open <!-- ref: ledger-ui-has-blockers -->
  Spec says Open view supports `has_blockers (yes/no)` filter. Not implemented.
  Files: `web/app/modules/ledger/controllers/ledger_controller.rb`
  Required tests (in `web/spec/requests/ledger/ledger_spec.rb`):
  - GET /ledger/open?has_blockers=yes returns only nodes with unresolved depends_on edges
  - GET /ledger/open?has_blockers=no returns only nodes without blockers

- [ ] 17.2 — Show resolution field on node detail page <!-- ref: ledger-ui-resolution -->
  Node detail template doesn't render the `resolution` field.
  Files: `web/app/modules/ledger/controllers/ledger_controller.rb` (or view template)
  Required tests: resolution field visible on node detail page for closed nodes.

---

## Dependency Graph

```
7.1 (Go runner spike) ──→ 16.1, 16.2 ──→ 16.3
7.2 (Redis spike) ──→ docker-compose cleanup
7.3 (Multi-tenancy spike) ──→ org provisioning (future)

8.1 (env vars) ── no blockers
8.2 (LOOKUP fix) ── no blockers

9.1 (comment rewrite) ── no blockers
9.2–9.4 (ledger test gaps) ── no blockers
9.5 (MarkdownHelper spec) ── no blockers

10.1 (rswag setup) ── no blockers
10.2 (rswag convert) ──→ depends on 10.1

11.1 (FeatureFlag model) ── no blockers
11.2 (FeatureFlag controller) ──→ depends on 11.1

12.1 (LibraryItem model) ── no blockers
12.2 (MdChunker) ── no blockers
12.3 (EmbedderService) ── no blockers
12.4 (ContextRetriever) ──→ depends on 12.1, 12.3
12.5 (IndexerJob) ──→ depends on 12.1, 12.2, 12.3

13.1–13.3 (analytics models) ── no blockers
13.4 (AuditLogger) ──→ depends on 13.2
13.5 (MetricsController) ──→ depends on 13.1, 13.3, 11.1

14.1 (ContainerRun model) ── no blockers
14.2 (DockerDispatcher) ──→ depends on 14.1

15.1 (AgentRun model) ── no blockers
15.2 (AgentRunTurn model) ──→ depends on 15.1
15.3 (PromptDeduplicator) ──→ depends on 15.1
15.4 (ProviderAdapter) ── no blockers
15.5 (AgentRunsController) ──→ depends on 15.1, 15.2, 15.3, 15.4
15.6 (kiro configs) ── no blockers

16.3 (FF exposure event) ──→ depends on 11.1, 16.2

17.1–17.2 (UI polish) ── no blockers
```