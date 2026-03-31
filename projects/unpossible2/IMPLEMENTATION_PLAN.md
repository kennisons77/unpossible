# Implementation Plan

Generated: 2026-03-29 (gap analysis pass)
Phase: 0 (Local Development)

> Scope: Full feature space. No audience.md — planning complete Phase 0 foundation.
> Phase rule: only `infra/Dockerfile`, `infra/Dockerfile.runner`, `infra/Dockerfile.analytics`,
> `infra/docker-compose.yml` for infrastructure. No CI, no k8s, no staging, no production config.

---

## Specs Index

| Spec | Module | Loop type |
|---|---|---|
| prd.md | all | Plan |
| knowledge.md | knowledge | Build |
| tasks.md | tasks | Build |
| agents.md | agents | Build |
| sandbox.md | sandbox | Build |
| analytics.md | analytics | Build |
| runner.md | go sidecar | Build |
| auth.md | shared | Build |
| security.md | shared | Build |
| loop.md | loop.sh | Build |
| research-loop.md | loop.sh + knowledge | Research |
| practices.md | practices/ | Plan + Build |
| lookup-tables.md | specs/, AGENTS.md, practices/ | Plan + Build |
| server-operations.md | loop.sh + sandbox | Build |
| infrastructure.md | infra/ | Plan |
| feature-lifecycle.md | tasks + analytics | Plan + Build |

---

## Section 1 — Infrastructure & Project Skeleton

- [x] Create Rails app skeleton (`app/Gemfile`, `app/config/application.rb`, `app/config/database.yml`)
- [x] Create `infra/Dockerfile` (multi-stage ruby:3.3-slim, non-root, exposes 3000)
- [x] Create `infra/docker-compose.yml` (test stack: test + postgres pgvector/pgvector:pg16 + redis)
- [x] Configure RSpec + Rubocop + SimpleCov (`app/.rspec`, `app/spec/spec_helper.rb`, `app/spec/rails_helper.rb`, `app/.rubocop.yml`)
- [ ] Configure Solid Queue (`app/config/application.rb` queue adapter, `app/config/queue.yml`, queues: default/knowledge/analytics/tasks)
  Replaces Sidekiq + Redis. Uses Postgres via `solid_queue` gem (Rails 8 built-in). No Redis dependency.
  Files: `app/config/queue.yml`, `app/config/application.rb` (update), solid_queue migrations via `bin/rails solid_queue:install:migrations`, `app/spec/config/solid_queue_spec.rb`
  Required tests: job enqueued on correct queue; job executes without error; no Redis dependency in test suite
- [x] Configure Lograge structured logging (`app/config/initializers/lograge.rb`)
- [x] Create `AGENTS.md`

- [ ] Enable pgvector extension
  Migration to enable `vector` extension. Confirm `pgvector` gem already in Gemfile (it is).
  Files: `app/db/migrate/YYYYMMDDHHMMSS_enable_pgvector.rb`, `app/config/database.yml`
  Required tests: migration runs without error; `ActiveRecord::Base.connection.execute("SELECT '[1,2,3]'::vector")` succeeds

- [ ] Create `infra/Dockerfile.runner` (Go runner sidecar)
  Multi-stage from `golang:1.22-alpine`. Copies `runner/`, runs `go build`. Final image `alpine:3.19`. Exposes 8080. Non-root.
  Files: `infra/Dockerfile.runner`
  Required tests: `docker build -f infra/Dockerfile.runner .` exits 0; `/healthz` returns 200

- [ ] Create `infra/Dockerfile.analytics` (Go analytics sidecar)
  Multi-stage from `golang:1.22-alpine`. Copies `analytics-sidecar/`, runs `go build`. Final image `alpine:3.19`. Exposes 9100. Non-root.
  Files: `infra/Dockerfile.analytics`
  Required tests: `docker build -f infra/Dockerfile.analytics .` exits 0; `/healthz` returns 200


## Section 2 — Security Foundation

- [ ] Create `Secret` value object
  `app/app/lib/secret.rb`. Wraps a value. Overrides `inspect`, `to_s`, `as_json` → `"[REDACTED]"`. `.expose` is the only way to access the raw value.
  Files: `app/app/lib/secret.rb`, `app/spec/lib/secret_spec.rb`
  Required tests: `Secret.new("k").inspect` → `"[REDACTED]"`; `Secret.new("k").to_s` → `"[REDACTED]"`; `Secret.new("k").as_json` → `"[REDACTED]"`; `Secret.new("k").expose` → `"k"`; JSON serialization returns `"[REDACTED]"`

- [ ] Create `Security::LogRedactor` middleware
  Wraps Lograge output stream. Applies regex patterns (OpenAI `sk-...`, `Bearer ...`, PEM headers, AWS `AKIA...`, JWT `eyJ...`, high-entropy strings >20 chars) and replaces with `[REDACTED:<type>]`.
  Files: `app/app/lib/security/log_redactor.rb`, `app/config/initializers/lograge.rb` (update)
  Required tests: JWT pattern redacted; OpenAI key pattern redacted; PEM header redacted; normal log lines pass through unchanged

- [ ] Create `Security::PromptSanitizer`
  `Security::PromptSanitizer.sanitize(text)` — applies gitleaks patterns plus PII patterns (email → `[EMAIL]`, phone → `[PHONE]`, IP → `[IP]`). Logs warning to audit log on match. Called by every provider adapter before sending to LLM.
  Files: `app/app/lib/security/prompt_sanitizer.rb`, `app/spec/lib/security/prompt_sanitizer_spec.rb`
  Required tests: email redacted; phone redacted; OpenAI key pattern redacted; clean text passes through; match triggers audit log warning

- [ ] Configure rack-attack rate limiting
  Throttle by IP. Return 429 on limit exceeded.
  Files: `app/config/initializers/rack_attack.rb`, `app/spec/config/initializers/rack_attack_spec.rb`
  Required tests: >N requests from same IP within window returns 429; normal traffic passes through

- [ ] Configure brakeman and bundler-audit Rake tasks
  Add Rake tasks that run both and exit non-zero on findings.
  Files: `app/lib/tasks/security.rake`
  Required tests: `bundle exec brakeman --exit-on-warn` exits 0 on clean app; `bundle exec bundler-audit check --update` exits 0 on clean Gemfile.lock


## Section 3 — Core Module Structure & Auth

- [ ] Scaffold module directory structure
  Create `app/modules/{knowledge,tasks,agents,sandbox,analytics}/` each with `models/`, `services/`, `jobs/`, `controllers/` subdirectories. Confirm `config/application.rb` already autoloads `app/modules/**/` (it does). Create `app/modules/LOOKUP.md`.
  Files: module `.keep` files, `app/app/modules/LOOKUP.md`
  Required tests: each module namespace resolves without error; `app/modules/LOOKUP.md` exists with all five modules

- [ ] Create JWT authentication
  `app/app/lib/auth_token.rb` — encodes/decodes JWT with `org_id`, `user_id`, `exp` claims. `ApplicationController#authenticate!` before_action. `X-Sidecar-Token` header auth for Go sidecar (shared secret from env). `POST /api/auth/token` issues tokens (Phase 0: shared secret for dev). Every route explicitly public or authenticated.
  Files: `app/app/lib/auth_token.rb`, `app/app/controllers/application_controller.rb` (update), `app/app/controllers/api/auth_controller.rb`, `app/config/routes.rb` (update), `app/spec/lib/auth_token_spec.rb`, `app/spec/requests/api/auth_spec.rb`
  Required tests: valid JWT authenticates; expired JWT → 401; tampered JWT → 401; missing token → 401; valid `X-Sidecar-Token` authenticates sidecar endpoints independently; wrong sidecar token → 401


## Section 4 — Knowledge Module

- [ ] Create `LibraryItem` model and migration
  Schema: `id`, `org_id`, `parent_id` (nullable, self-referential), `content_type` (enum: md_file/plain_text/link_reference), `title`, `body` (text), `url` (nullable), `file_path` (nullable), `content_sha256`, `archived_at` (nullable), `embedded_at` (nullable), `created_at`, `updated_at`.
  Files: `app/app/modules/knowledge/models/library_item.rb`, migration, `app/spec/models/knowledge/library_item_spec.rb`, factory
  Required tests: validates presence of title and content_type; enum rejects invalid values; parent_id self-reference works; archived items excluded from default scope; factory creates valid record

- [ ] Create `Embedding` model and migration with pgvector
  Schema: `id`, `library_item_id` (FK), `chunk_index` (int), `chunk_text` (text), `embedding` (vector(1536)), `created_at`. IVFFlat index on embedding column for cosine similarity.
  Files: `app/app/modules/knowledge/models/embedding.rb`, migration, `app/spec/models/knowledge/embedding_spec.rb`, factory
  Required tests: stores and retrieves 1536-dim vector; nearest-neighbor query returns results ordered by cosine distance; belongs_to library_item

- [ ] Create `EmbedderService` interface and OpenAI implementation
  `Knowledge::EmbedderService` abstract interface `embed(text) → Array<Float>`. `Knowledge::OpenAiEmbedder` implements it using `text-embedding-3-small`. API key passed as `Secret`. Swappable via `EMBEDDER_PROVIDER=openai|ollama`.
  Files: `app/app/modules/knowledge/services/embedder_service.rb`, `app/app/modules/knowledge/services/open_ai_embedder.rb`, `app/spec/modules/knowledge/services/open_ai_embedder_spec.rb`
  Required tests: returns array of 1536 floats (stub HTTP); raises on API error; API key never appears in logs or error messages; `Secret` wraps the key

- [ ] Create `MdChunker` service
  `Knowledge::MdChunker.chunk(text) → Array<String>`. Splits at paragraph/section boundaries. Preserves section headers with their content.
  Files: `app/app/modules/knowledge/services/md_chunker.rb`, `app/spec/modules/knowledge/services/md_chunker_spec.rb`
  Required tests: splits on blank lines between paragraphs; preserves section headers with content; single-paragraph file returns one chunk; empty input returns empty array

- [ ] Create `Knowledge::IndexerJob`
  Accepts file path. Computes SHA256. Skips if `content_sha256` matches existing `LibraryItem`. Chunks via `MdChunker`. Calls `EmbedderService#embed` per chunk. Upserts `Embedding` records. Updates `embedded_at`. Idempotent. Enqueued on `knowledge` queue.
  Files: `app/app/modules/knowledge/jobs/indexer_job.rb`, `app/spec/modules/knowledge/jobs/indexer_job_spec.rb`
  Required tests: unchanged file (same SHA256) skips embedding call; changed file re-embeds all chunks; idempotent (run twice = same DB state); job enqueued on `knowledge` queue

- [ ] Create `ContextRetriever` service
  `Knowledge::ContextRetriever#retrieve(query:, limit: 5)` — embeds query, runs pgvector cosine similarity search, returns top-N `LibraryItem` chunks with similarity scores. Excludes archived items.
  Files: `app/app/modules/knowledge/services/context_retriever.rb`, `app/spec/modules/knowledge/services/context_retriever_spec.rb`
  Required tests: returns results sorted by similarity descending; respects limit; returns empty array when no embeddings exist; archived items excluded

- [ ] Create `Knowledge::LibraryItemsController`
  index (paginated), show, create, update, destroy. Destroy accepts `on_parent_delete` param: cascade/archive/reassign. Requires JWT auth. Audit log on destroy.
  Files: `app/app/modules/knowledge/controllers/knowledge/library_items_controller.rb`, `app/config/routes.rb` (update), `app/spec/requests/knowledge/library_items_spec.rb`
  Required tests: index returns paginated items; destroy cascade deletes children; destroy archive sets archived_at on children; destroy reassign moves children; unauthenticated → 401; destroy calls AuditLogger


## Section 5 — Tasks Module

- [ ] Create `Task` model and migration
  Schema: `id`, `org_id`, `title`, `description` (text), `status` (enum: pending/in_progress/complete/failed/blocked), `loop_type` (enum: plan/build/review/reflect/research), `provider` (string, nullable), `model` (string, nullable), `prompt_template` (text, nullable), `reviewer_provider` (string, nullable), `reviewer_model` (string, nullable), `allowed_tools` (jsonb array, default []), `task_ref` (string, indexed), `depends_on_ids` (jsonb array, default []), `created_at`, `updated_at`.
  Files: `app/app/modules/tasks/models/task.rb`, migration, `app/spec/models/tasks/task_spec.rb`, factory
  Required tests: status enum validates; loop_type enum validates; allowed_tools defaults to []; depends_on_ids defaults to []; task_ref indexed; factory creates valid record

- [ ] Create `Tasks::PlanParserJob` and `PlanParser` service
  Reads `IMPLEMENTATION_PLAN.md` from configured workspace path. Parses `- [ ]` (pending) and `- [x]` (complete) checkboxes. Upserts `Task` records keyed on `task_ref` (SHA256 of checkbox text). Preserves manually set `provider`/`model` overrides. Idempotent.
  Files: `app/app/modules/tasks/jobs/plan_parser_job.rb`, `app/app/modules/tasks/services/plan_parser.rb`, `app/spec/modules/tasks/services/plan_parser_spec.rb`
  Required tests: unchecked → status: pending; checked → status: complete; idempotent; manual provider override not overwritten; malformed MD logs warning and continues without raising

- [ ] Create `Idea` model, migration, and `IdeaParserJob`
  Schema: `id`, `org_id`, `idea_ref` (string, SHA256 of title), `title`, `description` (text), `status` (enum: parked/ready/promoted), `created_at`, `promoted_at` (nullable). `IdeaParserJob` parses `IDEAS.md` and upserts records. `IDEAS.md` is source of truth.
  Files: `app/app/modules/tasks/models/idea.rb`, migration, `app/app/modules/tasks/jobs/idea_parser_job.rb`, `app/app/modules/tasks/services/idea_parser.rb`, `app/spec/models/tasks/idea_spec.rb`, factory
  Required tests: parked/ready/promoted statuses parse correctly; idempotent; only `ready` ideas can be promoted (validated); factory creates valid record

- [ ] Create `Tasks::TasksController` and `Tasks::IdeasController`
  `TasksController`: index (filter by status, loop_type), show, update (status, provider, model overrides). `IdeasController`: index, show. `POST /api/ideas/:id/promote` creates spec file and updates `IDEAS.md` atomically. `POST /api/tasks/:id/promote` advances to in_progress. All require JWT auth.
  Files: controllers, `app/config/routes.rb` (update), `app/spec/requests/tasks/tasks_spec.rb`, `app/spec/requests/tasks/ideas_spec.rb`
  Required tests: index filters by status and loop_type; task promote → in_progress; idea promote creates spec file and updates IDEAS.md atomically; unauthenticated → 401; promoting non-ready idea → 422


## Section 6 — Agents Module

- [ ] Create `AgentRun` model and migration
  Schema: `id`, `org_id`, `task_id` (FK, nullable), `parent_run_id` (FK self-referential, nullable), `run_id` (uuid), `iteration` (int), `mode` (enum: plan/build/review/reflect/research), `model` (string), `provider` (string), `prompt_sha256` (string, indexed), `input_tokens` (int), `output_tokens` (int), `cost_estimate_usd` (decimal 10,6), `exit_code` (int), `duration_ms` (int), `response_truncated` (boolean), `source_library_item_ids` (jsonb, default []), `created_at`. Unique index on (run_id, iteration).
  Files: `app/app/modules/agents/models/agent_run.rb`, migration, `app/spec/models/agents/agent_run_spec.rb`, factory
  Required tests: factory creates valid record; prompt_sha256 indexed; cost_estimate stores 6 decimal places; uniqueness on (run_id, iteration); parent_run_id self-reference works; source_library_item_ids defaults to []

- [ ] Create `Agents::PromptDeduplicator` service
  `#cached_result?(prompt_sha256:, mode:, max_age_hours: 24)` — queries AgentRun for recent successful run with matching prompt_sha256 and mode. Returns cached run or nil. Ignores failed runs and runs older than max_age.
  Files: `app/app/modules/agents/services/prompt_deduplicator.rb`, `app/spec/modules/agents/services/prompt_deduplicator_spec.rb`
  Required tests: returns nil when no match; returns run when match within max_age; ignores failed runs; ignores runs older than max_age

- [ ] Create `Agents::ProviderAdapter` base and `ClaudeAdapter`
  Base class with interface: `build_prompt`, `parse_response`, `cache_config`, `supports_caching?`, `max_context_tokens`. `ClaudeAdapter` applies `cache_control: {type: "ephemeral", ttl: "1h"}` to practices files and prd.md (>500 tokens). Does NOT cache task description or IMPLEMENTATION_PLAN.md. Aborts with RALPH_WAITING if prompt >150K tokens. Calls `Security::PromptSanitizer.sanitize` before sending. Never enables compaction.
  Files: `app/app/modules/agents/services/provider_adapter.rb`, `app/app/modules/agents/services/claude_adapter.rb`, `app/spec/modules/agents/services/claude_adapter_spec.rb`
  Required tests: `ProviderAdapter.for("claude")` returns ClaudeAdapter; cache_control applied to practices blocks; cache_control NOT applied to task description; prompt >150K tokens aborts with RALPH_WAITING; PromptSanitizer called before send; compaction never enabled

- [ ] Create `Agents::KiroAdapter`
  Invocation: `kiro-cli chat --no-interactive --trust-all-tools --model $MODEL -- "$PROMPT"`. Never passes `--resume`. Selects agent config by loop type. Aborts with RALPH_WAITING if prompt >150K tokens. Calls `Security::PromptSanitizer.sanitize`.
  Files: `app/app/modules/agents/services/kiro_adapter.rb`, `kiro-agents/ralph_build.json`, `kiro-agents/ralph_plan.json`, `kiro-agents/ralph_research.json`, `kiro-agents/ralph_review.json`, `app/spec/modules/agents/services/kiro_adapter_spec.rb`
  Required tests: `ProviderAdapter.for("kiro")` returns KiroAdapter; never passes --resume; selects correct agent config by loop type; prompt >150K tokens aborts; PromptSanitizer called

- [ ] Create `Agents::OpenAiAdapter`
  Uses `response_format: {type: "json_schema"}` for structured-output tasks. Enforces 75% context window cap. Calls `Security::PromptSanitizer.sanitize`.
  Files: `app/app/modules/agents/services/open_ai_adapter.rb`, `app/spec/modules/agents/services/open_ai_adapter_spec.rb`
  Required tests: `ProviderAdapter.for("openai")` returns OpenAiAdapter; response_format json_schema used for structured tasks; prompt >75% context cap aborts; PromptSanitizer called

- [ ] Create `Agents::AgentRunsController`
  `POST /api/agent_runs/start` — creates AgentRun, assembles prompt, checks dedup, calls Go sidecar `POST /run`. Returns cached run on dedup hit. `POST /api/agent_runs/:id/complete` — updates record, triggers `Tasks::PlanParserJob` if mode was plan, logs to audit. `POST /api/agent_runs` (sidecar direct POST) — authenticated via `X-Sidecar-Token`. Duplicate (run_id + iteration) → 422.
  Files: `app/app/modules/agents/controllers/agents/agent_runs_controller.rb`, `app/config/routes.rb` (update), `app/spec/requests/agents/agent_runs_spec.rb`
  Required tests: start creates AgentRun and calls sidecar; start returns cached run on dedup hit; complete updates record and triggers PlanParserJob on plan mode; duplicate (run_id+iteration) → 422; wrong sidecar token → 401; parent_run_id links subagent to parent; source_library_item_ids stored


## Section 7 — Analytics Module

- [ ] Create `analytics_events` table and migration
  Schema: `id` (uuid), `org_id` (uuid), `distinct_id` (string — opaque UUID), `event_name` (string, namespaced), `properties` (jsonb — filtered through PromptSanitizer before storage), `timestamp` (timestamptz), `received_at` (timestamptz). Index on (org_id, event_name, timestamp). Append-only.
  Files: `app/app/modules/analytics/models/analytics_event.rb`, migration, `app/spec/models/analytics/analytics_event_spec.rb`, factory
  Required tests: factory creates valid record; no update method exposed; no destroy method exposed; index on (org_id, event_name, timestamp); distinct_id validated as UUID format

- [ ] Create `feature_flag_exposures` table and migration
  Schema: `id` (uuid), `org_id` (uuid), `flag_key` (string), `variant` (string), `distinct_id` (string), `timestamp` (timestamptz). Index on (org_id, flag_key, distinct_id).
  Files: `app/app/modules/analytics/models/feature_flag_exposure.rb`, migration, factory
  Required tests: factory creates valid record; index exists; joins with analytics_events on distinct_id

- [ ] Create `AuditEvent` model and migration
  Schema: `id`, `org_id`, `actor_id` (string), `resource_type` (string), `resource_id` (string), `action` (string), `severity` (enum: info/warning/critical), `metadata` (jsonb — filtered through Secret redaction and PromptSanitizer before storage), `created_at`. Append-only.
  Files: `app/app/modules/analytics/models/audit_event.rb`, migration, `app/spec/models/analytics/audit_event_spec.rb`, factory
  Required tests: factory creates valid record; no update/destroy exposed; severity enum validates; index on (org_id, created_at); Secret values in metadata stored as "[REDACTED]"

- [ ] Create `FeatureFlag` model and migration
  Schema: `id`, `org_id`, `key` (string, unique per org), `enabled` (boolean, default false), `variant` (string, nullable), `metadata` (jsonb — `hypothesis` field required on creation), `status` (enum: active/archived, default active), `created_at`, `updated_at`. `FeatureFlag.enabled?` returns false for archived flags. Automatically fires `$feature_flag_called` event to analytics sidecar on evaluation.
  Files: `app/app/modules/analytics/models/feature_flag.rb`, migration, `app/spec/models/analytics/feature_flag_spec.rb`, factory
  Required tests: key unique per org; enabled defaults to false; metadata.hypothesis required on creation → 422 if missing; archived flag returns false from enabled? without raising; enabled? fires $feature_flag_called event; factory creates valid record

- [ ] Create `Analytics::AuditLogger` service
  `Analytics::AuditLogger.log(actor:, resource_type:, resource_id:, action:, severity: :info, metadata: {})` — async write to `audit_events`. Filters metadata through Secret redaction and PromptSanitizer. Never raises. Fire-and-forget.
  Files: `app/app/modules/analytics/services/audit_logger.rb`, `app/app/modules/analytics/jobs/audit_log_job.rb`, `app/spec/modules/analytics/services/audit_logger_spec.rb`
  Required tests: creates AuditEvent asynchronously; Secret values in metadata stored as "[REDACTED]"; PII in metadata redacted; failure to persist logs to Rails logger, does not raise

- [ ] Create `LlmMetric` model and migration
  Schema: `id`, `org_id`, `agent_run_id` (FK), `provider` (string), `model` (string), `input_tokens` (int), `output_tokens` (int), `cost_estimate_usd` (decimal 10,6), `task_type` (string), `created_at`. Index on (org_id, provider, model, created_at).
  Files: `app/app/modules/analytics/models/llm_metric.rb`, migration, factory
  Required tests: factory creates valid record; index exists; cost_estimate stores 6 decimal places

- [ ] Create `Analytics::MetricsController`
  `GET /api/analytics/llm` — aggregate cost/tokens by provider/model/date, filterable by date range. `GET /api/analytics/loops` — run counts and failure rates by mode. `GET /api/analytics/summary` — total cost this week, tasks completed, loop error rate. `GET /api/analytics/flags/:key` — exposure counts and conversion rates per variant. `GET /api/analytics/events` — paginated event list. All require JWT auth.
  Files: `app/app/modules/analytics/controllers/analytics/metrics_controller.rb`, `app/config/routes.rb` (update), `app/spec/requests/analytics/metrics_spec.rb`
  Required tests: llm returns costs grouped by provider; date range filtering works; summary returns three metrics; flags returns exposure counts; unauthenticated → 401; distinct_id in response is UUID not email


## Section 8 — Sandbox Module

- [ ] Create `ContainerRun` model and migration
  Schema: `id`, `org_id`, `agent_run_id` (FK, nullable), `image` (string), `command` (text), `status` (enum: pending/running/complete/failed), `exit_code` (int, nullable), `started_at`, `finished_at`, `created_at`, `updated_at`. Duration computed from started_at/finished_at.
  Files: `app/app/modules/sandbox/models/container_run.rb`, migration, `app/spec/models/sandbox/container_run_spec.rb`, factory
  Required tests: status enum validates; factory creates valid record; duration computed correctly; agent_run_id nullable

- [ ] Create `Sandbox::DockerDispatcher` service
  `#dispatch(image:, command:, env: {})`. Shells out to `docker run --rm`. Command passed as argument array — no shell interpolation. Env vars filtered through Secret redaction before logging. Returns `{exit_code:, stdout:, stderr:, duration_ms:}`. Times out after configurable seconds (default 300). Creates and updates `ContainerRun` record. Containers run as non-root, no `--privileged`.
  Files: `app/app/modules/sandbox/services/docker_dispatcher.rb`, `app/spec/modules/sandbox/services/docker_dispatcher_spec.rb`
  Required tests: successful command returns exit_code 0 and stdout; failed command returns non-zero exit_code without raising; Secret env vars not logged; times out after configured seconds; ContainerRun record created and updated with final status


## Section 9 — Go Runner Sidecar

- [ ] Scaffold Go runner (`runner/`)
  Responsibilities: receive `POST /run` (Basic Auth), execute `loop.sh` via `exec.CommandContext`, mutex (one run at a time), parse token counts from `--output-format=stream-json` stdout, call `POST /api/agent_runs/:id/complete` on Rails with results, expose `/healthz`, `/ready`, `/metrics` (prometheus/client_golang), `/run`. Metrics: `runs_total` (counter), `runs_failed_total` (counter), `run_duration_seconds` (histogram), `current_runs` (gauge).
  Files: `runner/main.go`, `runner/go.mod`, `runner/go.sum`
  Required tests: `go test ./...` exits 0; `/healthz` returns 200; `/metrics` returns valid Prometheus text; concurrent POST /run returns 409; POST /run without auth returns 401; calls Rails complete endpoint after loop exits (mock server test)

## Section 10 — Go Analytics Sidecar

- [ ] Scaffold Go analytics sidecar (`analytics-sidecar/`)
  `POST /capture` — accepts single event or batch array, returns 202 immediately. In-memory event queue. Batch flush to Postgres `analytics_events` every 5 seconds or 100 events. Buffers in memory if Postgres temporarily unavailable. `GET /healthz`. No auth on `/capture` — internal network only. `properties` jsonb filtered through gitleaks patterns before storage. `distinct_id` validated as UUID format before storage.
  Files: `analytics-sidecar/main.go`, `analytics-sidecar/go.mod`, `analytics-sidecar/go.sum`
  Required tests: `go test ./...` exits 0; POST /capture returns 202 immediately; events flushed within 5s or 100 events; events buffered on Postgres unavailability; /healthz returns 200; distinct_id non-UUID rejected


## Section 11 — Loop & Prompt Templates

- [ ] Create `loop.sh`
  Build mode (default), plan mode, reflect mode, research mode. `AGENT=kiro` and `AGENT=claude` support. Git stash guard per iteration (stash before, drop on success, pop on failure). Log rollback events via `curl POST /api/audit_events`. Create `ralph/{timestamp}` branch when running on main/master. Stop with exit 2 after 3 consecutive iterations without a RALPH signal. `RALPH_WAITING: <question>` pauses and prompts for human input.
  Files: `loop.sh`
  Required tests: `./loop.sh plan 1` runs one iteration and exits; `./loop.sh reflect` dispatches to PROMPT_reflect.md; failed iteration leaves working tree clean (stash pop); successful iteration leaves stash empty; RALPH_COMPLETE exits 0; 3 consecutive no-signal iterations exits 2; AGENT=kiro and AGENT=claude both work

- [ ] Create `PROMPT_reflect.md`
  Instructs agent to: read accumulated AgentRun records via Rails API, identify patterns in costs/errors/review feedback, propose ONE concrete improvement with (a) what will improve and (b) which metric verifies it. Proposal goes through plan/build/review — never self-applies. Exception: append gotchas directly to relevant practices file. Ends with RALPH_COMPLETE or RALPH_WAITING.
  Files: `PROMPT_reflect.md`
  Required tests: file exists; contains RALPH_COMPLETE signal instruction; contains one-proposal rule; contains measurable hypothesis requirement

- [ ] Create `PROMPT_research.md`
  Instructs agent to: read seed idea from IDEAS.md, pause with RALPH_WAITING to ask interview questions (scope, edge cases, failure modes, security surface, performance, prior art), collect sources (URL + summary + type tag), write/append research log at `specs/research/{feature}.md`, update spec with Research section and back-references, trigger IndexerJob if Rails is running. Video sources: title + URL only, no content fetch. Ends with RALPH_COMPLETE.
  Files: `PROMPT_research.md`
  Required tests: file exists; contains RALPH_WAITING interview instruction; contains source collection format; contains video-no-fetch rule; contains RALPH_COMPLETE instruction

- [ ] Update `PROMPT_build.md` and `PROMPT_plan.md` with `{practices}` and `{context}` slots
  Add `{practices}` and `{context}` slots to both prompts. Current prompts become default templates.
  Files: `PROMPT_build.md`, `PROMPT_plan.md`
  Required tests: files contain {practices} slot; files contain {context} slot


## Section 12 — Practices Files & Lookup Tables

- [ ] Create `practices/general/security.md`
  Rules: Secret value object for all API keys; `inspect`/`to_s` override pattern; `.expose` is the only exit; filter_parameters list; Lograge structured logging only; audit log entries filtered before storage; shell commands as argument arrays; `ENV.fetch` not `ENV[]`; `.env` in .gitignore always; rack-attack from day one; brakeman on every build; unauthenticated endpoints are the exception.
  Files: `practices/general/security.md`
  Required tests: file exists; references Secret class; references filter_parameters; references rack-attack; references brakeman

- [ ] Create `practices/general/reflect.md`
  Protocol: one proposal per reflect iteration; every proposal states (a) what will improve and (b) which metric verifies it; no change without measurable hypothesis; reflect output targets practices/, PROMPT_*.md, or config — not application code; exception: append gotchas directly to relevant practices file.
  Files: `practices/general/reflect.md`
  Required tests: file exists; contains one-proposal-per-iteration rule; contains measurable hypothesis requirement

- [ ] Update `practices/lang/ruby.md` with module boundary and shared service rules
  Add: Shared Service Pattern (request struct, single call site); Module Boundaries (cross-module calls through public service interface only, no direct AR queries across boundaries, public interface in `app/modules/{name}/services/{name}_service.rb`).
  Files: `practices/lang/ruby.md`
  Required tests: file contains module boundary rule; file contains shared service pattern

- [ ] Update `practices/lang/go.md` with HTTP client, instrumentation, sidecar discipline rules
  Add: HTTP Clients (shared constructor, consistent User-Agent/timeouts/retry); Instrumentation (structured logging context, log entry/exit for long-running ops, never log secrets); Sidecar Discipline (no business logic in Go, domain decisions belong in Rails).
  Files: `practices/lang/go.md`
  Required tests: file contains sidecar discipline rule; file contains HTTP client rule

- [ ] Update `practices/framework/rails.md` with new rules
  Add: Specs as Source of Truth; Route Authorization (every route explicitly public or authenticated); Audit on Destructive Actions (any delete/promote/security-relevant action calls AuditLogger); Migration Discipline; Lookup Table Maintenance.
  Files: `practices/framework/rails.md`
  Required tests: file contains route authorization rule; file contains audit-on-destructive rule; file contains migration discipline rule

- [ ] Create `practices/LOOKUP.md`
  Maps concepts to the practices file and section that defines them. Rows (alphabetical): `audit on destructive`, `cache_control`, `effort parameter`, `ENV.fetch`, `filter_parameters`, `module boundary`, `RALPH_COMPLETE`, `rack-attack`, `Secret`, `shared service pattern`, `Ultrathink`.
  Files: `practices/LOOKUP.md`
  Required tests: file exists; contains table with Secret, cache_control, RALPH_COMPLETE, Ultrathink, module boundary, audit on destructive

- [ ] Create `app/app/modules/LOOKUP.md`
  Maps module names to paths and public service interfaces. All five modules: agents, analytics, knowledge, sandbox, tasks.
  Files: `app/app/modules/LOOKUP.md`
  Required tests: file exists; contains all five modules with paths and public interfaces

- [ ] Update `specs/README.md` lookup table
  Ensure table maps all 16 spec files to their module and loop type.
  Files: `specs/README.md`
  Required tests: file exists; contains table with all 16 spec files; all five modules represented

---

## Resolved Ambiguities

- **Multi-tenancy scope for Phase 0:** Single org. `org_id = 1` hardcoded or from `ORG_ID` env var. No org creation UI.
- **MinIO usage:** Removed from Phase 0. No spec defines what would be stored there.
- **loop.sh location:** `projects/unpossible2/loop.sh` — within the project directory.
- **Go runner source:** Copy into `projects/unpossible2/runner/` — not a submodule.
- **Reviewer LLM Phase 0 scope:** Stub only. `reviewer_provider` and `reviewer_model` fields exist in schema; second AgentRun spawn not implemented until a plan loop explicitly adds it.
- **`GET /up` health endpoint:** Rails 8 includes this by default. Confirmed enabled in routes.rb and not behind authentication.

## Remaining Open Questions

> Do not implement until resolved.

- **`ACTIVE_PROJECT` env var:** `research-loop.md` references `ACTIVE_PROJECT` to scope research logs. Clarify: is this set in `.env`, in `loop.sh`, or passed as a CLI argument?
- **Kiro agent config location:** `agents.md` references `~/.kiro/agents/{name}.json`. Clarify: are these committed to the repo under `kiro-agents/` and symlinked, or managed outside the repo?
