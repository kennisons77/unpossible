# Implementation Plan

Generated: 2026-03-27 (gap analysis pass)
Phase: 0 (Local Development)

> Scope: Full feature space. No audience.md — planning complete Phase 0 foundation.
> Phase rule: only `infra/Dockerfile`, `infra/Dockerfile.runner`, `infra/Dockerfile.analytics`,
> `infra/docker-compose.yml`, and `infra/docker-compose.test.yml` for infrastructure.
> K8s, NixOS, CI, staging, and production config are Phase 2+ — not listed here.

---

## Specs Index

| Spec | Module | Loop type |
|---|---|---|
| prd.md | all | Plan |
| knowledge.md | knowledge | Build |
| tasks.md | tasks | Build |
| feature-lifecycle.md | tasks + analytics + loop.sh | Plan + Build |
| agents.md | agents | Build |
| sandbox.md | sandbox | Build |
| analytics.md | analytics | Build |
| runner.md | go sidecar | Build |
| auth.md | shared | Build |
| security.md | shared | Build |
| loop.md | loop.sh | Build |
| research-loop.md | loop.sh + knowledge | Research |
| practices.md | practices/ | Plan + Build |
| lookup-tables.md | specs/, AGENTS.md, practices/, app/modules/ | Plan + Build |
| server-operations.md | loop.sh + sandbox | Build + Deploy |
| infrastructure.md | infra/ | Plan + Deploy |

---

## Section 1 — Infrastructure & Project Skeleton

- [x] Create Rails app skeleton
  `rails new unpossible2 --database=postgresql --skip-test` (full stack, not API-only — views needed). Gemfile: rails 8, pg, pgvector, rspec-rails, rubocop-rails-omakase, factory_bot_rails, shoulda-matchers, simplecov, lograge, sidekiq, redis, jwt, rack-attack, brakeman, bundler-audit.
  Files: `app/Gemfile`, `app/config/application.rb`, `app/config/database.yml`
  Tests: `bundle exec rspec` exits 0 on empty suite; `bundle exec rubocop` exits 0

- [ ] Create infra/Dockerfile (Rails)
  Multi-stage: builder installs gems, final is `ruby:3.3-slim`. Copies `app/`, runs `bundle install --without development test`. Exposes port 3000. Runs as non-root user. Image tagged by git SHA — never `latest`.
  Files: `infra/Dockerfile`
  Tests: `docker build -f infra/Dockerfile .` exits 0; container responds to `GET /up`

- [ ] Create infra/Dockerfile.runner (Go runner sidecar)
  Multi-stage Go build from `golang:1.22-alpine`. Copies `runner/`, runs `go build`. Final image is `alpine:3.19`. Exposes port 8080. Runs as non-root.
  Files: `infra/Dockerfile.runner`
  Tests: `docker build -f infra/Dockerfile.runner .` exits 0; `/healthz` returns 200

- [ ] Create infra/Dockerfile.analytics (Go analytics sidecar)
  Multi-stage Go build from `golang:1.22-alpine`. Copies `analytics-sidecar/`, runs `go build`. Final image is `alpine:3.19`. Exposes port 9100. Runs as non-root.
  Files: `infra/Dockerfile.analytics`
  Tests: `docker build -f infra/Dockerfile.analytics .` exits 0; `/healthz` returns 200

- [ ] Create infra/docker-compose.yml (local dev stack)
  Services: `rails` (ruby:3.3-slim, port 3000), `go_runner` (port 8080), `analytics` (port 9100), `postgres` (pgvector/pgvector:pg16, internal only), `redis` (redis:7-alpine, internal only). All on `unpossible2` bridge network. Postgres and Redis NOT bound to 0.0.0.0. Image tags use git SHA `$(git rev-parse --short HEAD)`. Rails depends_on postgres + redis. go_runner depends_on rails. analytics depends_on postgres.
  Files: `infra/docker-compose.yml`
  Tests: `docker compose up -d` exits 0; all services healthy; rails responds on port 3000; postgres/redis ports not reachable from host

- [ ] Create infra/docker-compose.test.yml (CI/test stack)
  Services: `test` (runs `bundle exec rspec`), `postgres` (same image, tmpfs volume), `redis` (same image, tmpfs volume). No ports exposed. Ephemeral volumes only.
  Files: `infra/docker-compose.test.yml`
  Tests: `docker compose -f infra/docker-compose.test.yml run --rm test` exits 0 on empty suite

- [ ] Configure RSpec + Rubocop + SimpleCov
  Install rspec-rails. Configure `.rspec`, `spec/spec_helper.rb`, `spec/rails_helper.rb` with FactoryBot, Shoulda Matchers, DatabaseCleaner. Configure `.rubocop.yml`. SimpleCov minimum coverage 90% on non-trivial files.
  Files: `app/.rspec`, `app/spec/spec_helper.rb`, `app/spec/rails_helper.rb`, `app/.rubocop.yml`
  Tests: `bundle exec rspec --format documentation` exits 0; `bundle exec rubocop` exits 0; SimpleCov reports ≥90%

- [ ] Configure Sidekiq + Redis
  Add sidekiq gem. `config/initializers/sidekiq.rb` pointing to Redis. `config/sidekiq.yml` with queue definitions: default, knowledge, analytics, tasks. Add Sidekiq web UI mounted at `/sidekiq` (authenticated).
  Files: `app/config/initializers/sidekiq.rb`, `app/config/sidekiq.yml`, `app/config/routes.rb`
  Tests: `Sidekiq::Client.push('class' => 'TestWorker', 'queue' => 'default', 'args' => [])` enqueues without error; Sidekiq web UI accessible

- [ ] Enable pgvector extension
  Migration to enable `vector` extension. Add `pgvector` gem. Configure `database.yml` to use pgvector image.
  Files: `app/db/migrate/YYYYMMDDHHMMSS_enable_pgvector.rb`, `app/config/database.yml`
  Tests: migration runs without error; `ActiveRecord::Base.connection.execute("SELECT '[1,2,3]'::vector")` succeeds

- [ ] Configure Lograge structured logging
  Add lograge gem. JSON format. `filter_parameters` includes `:api_key, :token, :password, :secret, :authorization, :access_token, :refresh_token, :private_key, :credential`. Never log request params containing secrets.
  Files: `app/config/initializers/lograge.rb`, `app/config/application.rb`
  Tests: log output is valid JSON; filtered params do not appear in logs

- [x] Create AGENTS.md
  Build/run/test commands. Codebase patterns lookup table. Server operations section (service name, health endpoint, deploy command, rollback command, log command). Under 100 lines.
  Files: `AGENTS.md`
  Tests: file exists; contains build/run/test commands; contains server operations section; contains codebase patterns table


## Section 2 — Security Foundation

- [ ] Create Secret value object
  `app/lib/secret.rb`. Wraps a value. Overrides `inspect`, `to_s`, `as_json` → `"[REDACTED]"`. `.expose` is the only way to access the raw value — explicit and grep-able. Used for all API keys, tokens, passwords.
  Files: `app/app/lib/secret.rb`
  Tests: `Secret.new("k").inspect` → `"[REDACTED]"`; `Secret.new("k").to_s` → `"[REDACTED]"`; `Secret.new("k").as_json` → `"[REDACTED]"`; `Secret.new("k").expose` → `"k"`; JSON serialization returns `"[REDACTED]"`

- [ ] Create Security::LogRedactor middleware
  Wraps Lograge output stream. Applies regex patterns (OpenAI `sk-...`, `Bearer ...` tokens, PEM headers `-----BEGIN ... KEY-----`, AWS `AKIA...`, JWT `eyJ...`, high-entropy strings >20 chars mixed case+digits+symbols) and replaces matches with `[REDACTED:<type>]` before the log line is written. Safety net — if it catches something, `Secret` or `filter_parameters` missed it upstream.
  Files: `app/app/lib/security/log_redactor.rb`, `app/config/initializers/lograge.rb`
  Tests: JWT pattern redacted; OpenAI key pattern redacted; PEM header redacted; normal log lines pass through unchanged

- [ ] Create Security::PromptSanitizer
  `Security::PromptSanitizer.sanitize(text)` — applies same gitleaks patterns as LogRedactor plus PII patterns (email → `[EMAIL]`, phone → `[PHONE]`, IP → `[IP]`). If match found, redacts and logs warning to audit log. Called by every provider adapter before `build_prompt` sends to LLM. Not optional, cannot be bypassed.
  Files: `app/app/lib/security/prompt_sanitizer.rb`
  Tests: email address redacted; phone number redacted; OpenAI key pattern redacted; clean text passes through unchanged; match triggers audit log warning

- [ ] Configure rack-attack rate limiting
  Add rack-attack gem. Configure in `config/initializers/rack_attack.rb`. Rate limit all public endpoints from day one. Throttle by IP. Return 429 on limit exceeded.
  Files: `app/config/initializers/rack_attack.rb`
  Tests: >N requests from same IP within window returns 429; normal traffic passes through

- [ ] Configure brakeman and bundler-audit
  Add brakeman and bundler-audit to Gemfile (development group). Add Rake tasks that run both and exit non-zero on findings. High-severity brakeman findings block the build. Known CVEs in bundler-audit block the build.
  Files: `app/Gemfile`, `app/lib/tasks/security.rake`
  Tests: `bundle exec brakeman --exit-on-warn` exits 0 on clean app; `bundle exec bundler-audit check --update` exits 0 on clean Gemfile.lock


## Section 3 — Core Module Structure & Auth

- [ ] Scaffold module directory structure
  Create `app/modules/{knowledge,tasks,agents,sandbox,analytics}/` each with `models/`, `services/`, `jobs/`, `controllers/` subdirectories. Update `config/application.rb` to autoload `app/modules/**`. Create `app/modules/LOOKUP.md` with module → path → public interface table.
  Files: `app/config/application.rb`, module `.keep` files, `app/modules/LOOKUP.md`
  Tests: `Rails.autoloaders.main.dirs` includes modules path; each module namespace resolves without error; `app/modules/LOOKUP.md` exists with all five modules

- [ ] Create JWT authentication
  `app/lib/auth_token.rb` — encodes/decodes JWT with `org_id`, `user_id`, `exp` claims. `ApplicationController#authenticate!` before_action. `X-Sidecar-Token` header auth for Go sidecar (independent of JWT, shared secret from env). `POST /api/auth/token` issues tokens (Phase 0: shared secret for dev). Every route is explicitly public or explicitly authenticated — no implicit defaults.
  Files: `app/app/lib/auth_token.rb`, `app/app/controllers/application_controller.rb`, `app/app/controllers/api/auth_controller.rb`, `app/config/routes.rb`
  Tests: valid JWT authenticates; expired JWT → 401; tampered JWT → 401; missing token → 401; valid `X-Sidecar-Token` authenticates sidecar endpoints independently; wrong sidecar token → 401


## Section 4 — Knowledge Module

- [ ] Create LibraryItem model and migration
  Schema: `id`, `org_id`, `parent_id` (nullable, self-referential), `content_type` (enum: md_file/plain_text/link_reference), `title`, `body` (text), `url` (nullable), `file_path` (nullable), `content_sha256`, `archived_at` (nullable — set on archive, excluded from retrieval), `embedded_at` (nullable), `created_at`, `updated_at`.
  Files: `app/modules/knowledge/models/library_item.rb`, migration
  Tests: validates presence of title and content_type; enum rejects invalid values; parent_id self-reference works; archived items excluded from default scope; factory creates valid record

- [ ] Create Embedding model and migration with pgvector
  Schema: `id`, `library_item_id` (FK), `chunk_index` (int), `chunk_text` (text), `embedding` (vector(1536)), `created_at`. IVFFlat index on embedding column for cosine similarity search.
  Files: `app/modules/knowledge/models/embedding.rb`, migration
  Tests: stores and retrieves 1536-dim vector; nearest-neighbor query returns results ordered by cosine distance; belongs_to library_item

- [ ] Create EmbedderService interface and OpenAI implementation
  `Knowledge::EmbedderService` — abstract interface `embed(text) → Array<Float>`. `Knowledge::OpenAiEmbedder` implements it using `text-embedding-3-small`. API key passed as `Secret`. Swappable via `EMBEDDER_PROVIDER=openai|ollama`.
  Files: `app/modules/knowledge/services/embedder_service.rb`, `app/modules/knowledge/services/open_ai_embedder.rb`
  Tests: returns array of 1536 floats (stub HTTP); raises on API error; API key never appears in logs or error messages; `Secret` wraps the key

- [ ] Create MdChunker service
  `Knowledge::MdChunker.chunk(text) → Array<String>`. Splits at paragraph/section boundaries (blank lines between paragraphs). Preserves section headers with their content. Each chunk is a semantically coherent unit.
  Files: `app/modules/knowledge/services/md_chunker.rb`
  Tests: splits on blank lines between paragraphs; preserves section headers with content; single-paragraph file returns one chunk; empty input returns empty array

- [ ] Create IndexerJob — git-change-detection re-indexer
  `Knowledge::IndexerJob`. Accepts file path. Computes SHA256. Skips if `content_sha256` matches existing `LibraryItem`. Chunks via `MdChunker`. Calls `EmbedderService#embed` per chunk. Upserts `Embedding` records. Updates `embedded_at`. Idempotent.
  Files: `app/modules/knowledge/jobs/indexer_job.rb`
  Tests: unchanged file (same SHA256) skips embedding call; changed file re-embeds all chunks; idempotent (run twice = same DB state); job enqueued on `knowledge` queue

- [ ] Create ContextRetriever service
  `Knowledge::ContextRetriever#retrieve(query:, limit: 5)` — embeds query, runs pgvector cosine similarity search against `embeddings`, returns top-N `LibraryItem` chunks with similarity scores. Excludes archived items.
  Files: `app/modules/knowledge/services/context_retriever.rb`
  Tests: returns results sorted by similarity descending; respects limit; returns empty array when no embeddings exist; archived items excluded from results

- [ ] Create Knowledge API controller
  `Knowledge::LibraryItemsController` — index (paginated), show, create, update, destroy. Destroy accepts `on_parent_delete` param: cascade (delete children), archive (set `archived_at` on children), reassign (move children to another parent). Destroy triggers async job. Requires JWT auth. Audit log on destroy.
  Files: `app/modules/knowledge/controllers/knowledge/library_items_controller.rb`, routes
  Tests: index returns paginated items; destroy cascade deletes children; destroy archive sets archived_at on children; destroy reassign moves children; unauthenticated → 401; destroy calls AuditLogger


## Section 5 — Tasks Module

- [ ] Create Task model and migration
  Schema: `id`, `org_id`, `title`, `description` (text), `status` (enum: pending/in_progress/complete/failed/blocked), `loop_type` (enum: plan/build/review/reflect/research), `provider` (string, nullable), `model` (string, nullable), `prompt_template` (text, nullable), `reviewer_provider` (string, nullable), `reviewer_model` (string, nullable), `allowed_tools` (jsonb array, default []), `task_ref` (string, indexed), `depends_on_ids` (jsonb array, default []), `created_at`, `updated_at`. Note: `blocked` state exists only in DB — never written back to IMPLEMENTATION_PLAN.md.
  Files: `app/modules/tasks/models/task.rb`, migration
  Tests: status enum validates; loop_type enum validates; allowed_tools defaults to []; depends_on_ids defaults to []; task_ref indexed; factory creates valid record

- [ ] Create PlanParserJob — parses IMPLEMENTATION_PLAN.md into tasks
  `Tasks::PlanParserJob`. Reads `IMPLEMENTATION_PLAN.md` from configured workspace path. Parses `- [ ]` (pending) and `- [x]` (complete) checkboxes. Upserts `Task` records keyed on `task_ref` (SHA256 of checkbox text). Preserves manually set `provider`/`model` overrides. Triggered after each plan loop completes and after each build loop commit. Idempotent.
  Files: `app/modules/tasks/jobs/plan_parser_job.rb`, `app/modules/tasks/services/plan_parser.rb`
  Tests: unchecked → status: pending; checked → status: complete; idempotent; manual provider override not overwritten; malformed MD logs warning and continues without raising

- [ ] Create Ideas model, migration, and IdeaParserJob
  `Ideas::Idea` model mirroring `IDEAS.md`. Schema: `id`, `org_id`, `idea_ref` (string, SHA256 of title), `title`, `description` (text), `status` (enum: parked/ready/promoted), `created_at`, `promoted_at` (nullable). `Ideas::IdeaParserJob` parses `IDEAS.md` and upserts records. `IDEAS.md` is source of truth — DB is query layer only.
  Files: `app/modules/tasks/models/idea.rb`, migration, `app/modules/tasks/jobs/idea_parser_job.rb`, `app/modules/tasks/services/idea_parser.rb`
  Tests: parked/ready/promoted statuses parse correctly; idempotent; only `ready` ideas can be promoted (validated); factory creates valid record

- [ ] Create Tasks and Ideas API controllers
  `Tasks::TasksController` — index (filter by status, loop_type), show, update (status, provider, model overrides). `Tasks::IdeasController` — index, show. `POST /api/ideas/:id/promote` — creates `specs/{feature}.md` and updates `IDEAS.md` atomically, transitions idea to promoted. `POST /api/tasks/:id/promote` — advances task status to in_progress. All require JWT auth.
  Files: controllers, routes
  Tests: index filters by status and loop_type; task promote → in_progress; idea promote creates spec file and updates IDEAS.md atomically; unauthenticated → 401; promoting non-ready idea → 422


## Section 6 — Agents Module

- [ ] Create AgentRun model and migration
  Schema: `id`, `org_id`, `task_id` (FK, nullable), `parent_run_id` (FK self-referential, nullable — for subagent runs), `run_id` (uuid), `iteration` (int), `mode` (enum: plan/build/review/reflect/research), `model` (string), `provider` (string), `prompt_sha256` (string, indexed), `input_tokens` (int), `output_tokens` (int), `cost_estimate_usd` (decimal 10,6), `exit_code` (int), `duration_ms` (int), `response_truncated` (boolean), `source_library_item_ids` (jsonb, default []), `created_at`. Unique index on (run_id, iteration). Note: raw prompt text is NOT stored — only the hash.
  Files: `app/modules/agents/models/agent_run.rb`, migration
  Tests: factory creates valid record; prompt_sha256 indexed; cost_estimate stores 6 decimal places; uniqueness on (run_id, iteration); parent_run_id self-reference works; source_library_item_ids defaults to []

- [ ] Create PromptDeduplicator service
  `Agents::PromptDeduplicator#cached_result?(prompt_sha256:, mode:, max_age_hours: 24)` — queries AgentRun for recent successful run with matching prompt_sha256 and mode. Returns cached run or nil. Ignores failed runs. Ignores runs older than max_age.
  Files: `app/modules/agents/services/prompt_deduplicator.rb`
  Tests: returns nil when no match; returns run when match within max_age; ignores failed runs; ignores runs older than max_age

- [ ] Create provider adapter base and Claude adapter
  `Agents::ProviderAdapter` base class with interface: `build_prompt(task:, context_chunks:, practices:)`, `parse_response(raw_output:)`, `cache_config`, `supports_caching?`, `max_context_tokens`. `Agents::ClaudeAdapter` implements it. Applies `cache_control: {type: "ephemeral", ttl: "1h"}` to stable blocks (practices files, prd.md, large tool definitions >500 tokens). Does NOT cache task description or IMPLEMENTATION_PLAN.md. Aborts with RALPH_WAITING if assembled prompt exceeds 150K tokens. Calls `Security::PromptSanitizer.sanitize` before sending. Never enables compaction in build/plan/review/research modes.
  Files: `app/modules/agents/services/provider_adapter.rb`, `app/modules/agents/services/claude_adapter.rb`
  Tests: `ProviderAdapter.for("claude")` returns ClaudeAdapter; cache_control applied to practices blocks; cache_control NOT applied to task description; prompt >150K tokens aborts with RALPH_WAITING; PromptSanitizer called before send; compaction never enabled

- [ ] Create Kiro adapter
  `Agents::KiroAdapter`. Invocation: `kiro-cli chat --no-interactive --trust-all-tools --model $MODEL -- "$PROMPT"`. Never passes `--resume` — each iteration is a fresh session. Selects agent config by loop type: `ralph_build`, `ralph_plan`, `ralph_research`, `ralph_review`. No `cache_control` annotations (Kiro abstracts caching internally). Cost efficiency via model selection. Aborts with RALPH_WAITING if prompt exceeds 150K tokens. Calls `Security::PromptSanitizer.sanitize`.
  Files: `app/modules/agents/services/kiro_adapter.rb`, `kiro-agents/ralph_build.json`, `kiro-agents/ralph_plan.json`, `kiro-agents/ralph_research.json`, `kiro-agents/ralph_review.json`
  Tests: `ProviderAdapter.for("kiro")` returns KiroAdapter; never passes --resume; selects correct agent config by loop type; prompt >150K tokens aborts; PromptSanitizer called

- [ ] Create OpenAI adapter
  `Agents::OpenAiAdapter`. Uses `response_format: {type: "json_schema"}` for structured-output tasks. No native prompt caching — relies on prompt_sha256 dedup. Enforces 75% context window utilisation cap. Calls `Security::PromptSanitizer.sanitize`.
  Files: `app/modules/agents/services/open_ai_adapter.rb`
  Tests: `ProviderAdapter.for("openai")` returns OpenAiAdapter; response_format json_schema used for structured tasks; prompt >75% context cap aborts; PromptSanitizer called

- [ ] Create AgentRuns API controller (start + complete flow)
  `Agents::AgentRunsController`. `POST /api/agent_runs/start` — creates AgentRun (status: pending), assembles prompt, checks dedup via PromptDeduplicator, calls Go sidecar `POST /run` with assembled prompt and config. Returns cached run if dedup hit. `POST /api/agent_runs/:id/complete` — updates record with results from sidecar (exit_code, duration_ms, input_tokens, output_tokens, response_truncated). Triggers `Tasks::PlanParserJob` if mode was plan. Logs to audit. `POST /api/agent_runs` (sidecar direct POST) — authenticated via `X-Sidecar-Token`. Duplicate (run_id + iteration) → 422.
  Files: `app/modules/agents/controllers/agents/agent_runs_controller.rb`, routes
  Tests: start creates AgentRun and calls sidecar; start returns cached run on dedup hit; complete updates record and triggers PlanParserJob on plan mode; duplicate (run_id+iteration) → 422; wrong sidecar token → 401; parent_run_id links subagent to parent; source_library_item_ids stored


## Section 7 — Analytics Module

- [ ] Create analytics_events table and migration
  Single-table event store. Schema: `id` (uuid), `org_id` (uuid), `distinct_id` (string — opaque UUID, never email/name), `event_name` (string, namespaced: "llm.run_completed", "task.promoted", etc.), `properties` (jsonb — filtered through PromptSanitizer before storage), `timestamp` (timestamptz), `received_at` (timestamptz). Index on (org_id, event_name, timestamp). Append-only — no update/delete exposed.
  Files: `app/modules/analytics/models/analytics_event.rb`, migration
  Tests: factory creates valid record; no update method exposed; no destroy method exposed; index on (org_id, event_name, timestamp); distinct_id validated as UUID format

- [ ] Create feature_flag_exposures table and migration
  Schema: `id` (uuid), `org_id` (uuid), `flag_key` (string), `variant` (string), `distinct_id` (string), `timestamp` (timestamptz). Separate from analytics_events for fast experiment analysis. Index on (org_id, flag_key, distinct_id).
  Files: `app/modules/analytics/models/feature_flag_exposure.rb`, migration
  Tests: factory creates valid record; index exists; joins with analytics_events on distinct_id

- [ ] Create AuditEvent model and migration
  Schema: `id`, `org_id`, `actor_id` (string), `resource_type` (string), `resource_id` (string), `action` (string), `severity` (enum: info/warning/critical), `metadata` (jsonb — filtered through Secret redaction and PromptSanitizer before storage), `created_at`. Append-only. Separate from analytics_events and Lograge.
  Files: `app/modules/analytics/models/audit_event.rb`, migration
  Tests: factory creates valid record; no update/destroy exposed; severity enum validates; index on (org_id, created_at); Secret values in metadata stored as "[REDACTED]"

- [ ] Create FeatureFlag model and migration
  Schema: `id`, `org_id`, `key` (string, unique per org), `enabled` (boolean, default false), `variant` (string, nullable), `metadata` (jsonb — `hypothesis` field required on creation), `status` (enum: active/archived, default active), `created_at`, `updated_at`. `FeatureFlag.enabled?(org_id:, key:)` returns false for archived flags without raising. Automatically fires `$feature_flag_called` event to analytics sidecar on evaluation.
  Files: `app/modules/analytics/models/feature_flag.rb`, migration
  Tests: key unique per org; enabled defaults to false; metadata.hypothesis required on creation → 422 if missing; archived flag returns false from enabled? without raising; enabled? fires $feature_flag_called event to analytics sidecar; factory creates valid record

- [ ] Create AuditLogger service
  `Analytics::AuditLogger.log(actor:, resource_type:, resource_id:, action:, severity: :info, metadata: {})` — async (Active Job) write to `audit_events`. Filters metadata through Secret redaction and PromptSanitizer before storage. Never raises — logs to Rails logger on failure. Fire-and-forget.
  Files: `app/modules/analytics/services/audit_logger.rb`, `app/modules/analytics/jobs/audit_log_job.rb`
  Tests: creates AuditEvent asynchronously; Secret values in metadata stored as "[REDACTED]"; PII in metadata redacted; failure to persist logs to Rails logger, does not raise

- [ ] Create LlmMetric model and migration
  Schema: `id`, `org_id`, `agent_run_id` (FK), `provider` (string), `model` (string), `input_tokens` (int), `output_tokens` (int), `cost_estimate_usd` (decimal 10,6), `task_type` (string), `created_at`. Denormalized from AgentRun for fast analytics queries. Index on (org_id, provider, model, created_at).
  Files: `app/modules/analytics/models/llm_metric.rb`, migration
  Tests: factory creates valid record; index exists; cost_estimate stores 6 decimal places

- [ ] Create Analytics API controller
  `Analytics::MetricsController`. `GET /api/analytics/llm` — aggregate cost/tokens by provider/model/date, filterable by date range. `GET /api/analytics/loops` — run counts and failure rates by mode. `GET /api/analytics/summary` — total cost this week, tasks completed this week, loop error rate. `GET /api/analytics/flags/:key` — exposure counts and conversion rates per variant. `GET /api/analytics/events` — paginated event list, filterable by event_name, org_id, date range. All require JWT auth. PII never returned — distinct_id is opaque UUID.
  Files: `app/modules/analytics/controllers/analytics/metrics_controller.rb`, routes
  Tests: llm returns costs grouped by provider; date range filtering works; summary returns three metrics; flags returns exposure counts; unauthenticated → 401; distinct_id in response is UUID not email


## Section 8 — Sandbox Module

- [ ] Create ContainerRun model and migration
  Schema: `id`, `org_id`, `agent_run_id` (FK, nullable), `image` (string), `command` (text), `status` (enum: pending/running/complete/failed), `exit_code` (int, nullable), `started_at`, `finished_at`, `created_at`, `updated_at`. Duration computed from started_at/finished_at.
  Files: `app/modules/sandbox/models/container_run.rb`, migration
  Tests: status enum validates; factory creates valid record; duration computed correctly; agent_run_id nullable

- [ ] Create DockerDispatcher service
  `Sandbox::DockerDispatcher#dispatch(image:, command:, env: {})`. Shells out to `docker run --rm` with given image and command. Command passed as argument array — no shell interpolation of user input. Env vars filtered through Secret redaction before logging. Captures stdout/stderr. Returns `{exit_code:, stdout:, stderr:, duration_ms:}`. Times out after configurable seconds (default 300). Creates and updates `ContainerRun` record. Containers run as non-root, no `--privileged`.
  Files: `app/modules/sandbox/services/docker_dispatcher.rb`
  Tests: successful command returns exit_code 0 and stdout; failed command returns non-zero exit_code without raising; Secret env vars not logged; times out after configured seconds; ContainerRun record created and updated with final status


## Section 9 — Go Runner Sidecar

- [ ] Scaffold Go runner (runner/)
  Adapt from unpossible1 dashboard Go binary. Responsibilities: receive `POST /run` (Basic Auth), execute `loop.sh` via `exec.CommandContext`, mutex (one run at a time), parse token counts from `--output-format=stream-json` stdout, call `POST /api/agent_runs/:id/complete` on Rails with results, expose `/healthz`, `/ready`, `/metrics` (prometheus/client_golang), `/run`. Replace hand-rolled Prometheus text exporter with `prometheus/client_golang`. Metrics: `runs_total` (counter), `runs_failed_total` (counter), `run_duration_seconds` (histogram), `current_runs` (gauge). Does NOT own business logic — all decisions are Rails.
  Files: `runner/main.go`, `runner/go.mod`, `runner/go.sum`
  Tests: `go test ./...` exits 0; `/healthz` returns 200; `/metrics` returns valid Prometheus text; concurrent POST /run returns 409; POST /run without auth returns 401; calls Rails complete endpoint after loop exits (mock server test)

## Section 10 — Go Analytics Sidecar

- [ ] Scaffold Go analytics sidecar (analytics-sidecar/)
  New Go service. `POST /capture` — accepts single event or batch array, returns 202 immediately. In-memory event queue. Batch flush to Postgres `analytics_events` table every 5 seconds or 100 events, whichever comes first. Buffers in memory if Postgres temporarily unavailable — no events dropped on brief outage. `GET /healthz` — liveness check. No auth on `/capture` — internal network only, never public. `properties` jsonb filtered through gitleaks patterns before storage (no PII). `distinct_id` validated as UUID format before storage.
  Files: `analytics-sidecar/main.go`, `analytics-sidecar/go.mod`, `analytics-sidecar/go.sum`
  Tests: `go test ./...` exits 0; POST /capture returns 202 immediately; events flushed within 5s or 100 events; events buffered on Postgres unavailability; /healthz returns 200; distinct_id non-UUID rejected


## Section 11 — Loop & Prompt Templates

- [ ] Update loop.sh — add reflect mode, research mode, stash guard, branch-per-run, AGENT support
  Add `reflect` mode dispatching to `PROMPT_reflect.md`. Add `research <id>` mode dispatching to `PROMPT_research.md` (always 1 iteration, reads idea from IDEAS.md). Add `AGENT=kiro` and `AGENT=claude` support (both work). Wrap each iteration in git stash guard: stash before, drop on success, pop on failure. Log rollback events via `curl POST /api/audit_events`. Create `ralph/{timestamp}` branch when running on main/master. Stop with exit 2 after 3 consecutive iterations without a RALPH signal. `RALPH_WAITING: <question>` pauses and prompts for human input.
  Files: `loop.sh`
  Tests: `./loop.sh plan 1` runs one iteration and exits; `./loop.sh reflect` dispatches to PROMPT_reflect.md; `./loop.sh research 1` runs 1 iteration; failed iteration leaves working tree clean (stash pop); successful iteration leaves stash empty; RALPH_COMPLETE exits 0; 3 consecutive no-signal iterations exits 2; AGENT=kiro and AGENT=claude both work

- [ ] Create PROMPT_reflect.md
  Reflect loop prompt. Instructs agent to: read accumulated AgentRun records via Rails API, identify patterns in costs/errors/review feedback, propose ONE concrete improvement with (a) what will improve and (b) which metric verifies it. Proposal goes through plan/build/review — never self-applies. Exception: if a gotcha or hard-won lesson is found, append directly to relevant practices file. Ends with RALPH_COMPLETE or RALPH_WAITING.
  Files: `PROMPT_reflect.md`
  Tests: file exists; contains RALPH_COMPLETE signal instruction; contains one-proposal rule; contains measurable hypothesis requirement

- [ ] Create PROMPT_research.md
  Research loop prompt. Instructs agent to: read seed idea from IDEAS.md, read existing spec and research log if present, pause with RALPH_WAITING to ask interview questions (scope, edge cases, failure modes, security surface, performance, prior art), collect sources (URL + summary + type tag), write/append research log at `specs/research/{feature}.md`, update spec with Research section and back-references, trigger IndexerJob if Rails is running. Video sources: title + URL only, no content fetch. Ends with RALPH_COMPLETE.
  Files: `PROMPT_research.md`
  Tests: file exists; contains RALPH_WAITING interview instruction; contains source collection format; contains video-no-fetch rule; contains RALPH_COMPLETE instruction

- [ ] Update PROMPT_build.md and PROMPT_plan.md with template slots
  Add `{practices}` and `{context}` slots to both prompts. Task schema declares which practices files are required. Plan loop assembles prompt dynamically from task type + knowledge base retrieval + declared practices. Current prompts become default templates.
  Files: `PROMPT_build.md`, `PROMPT_plan.md`
  Tests: files contain {practices} slot; files contain {context} slot


## Section 12 — Practices Files & Lookup Tables

- [ ] Create practices/general/security.md
  New file. Rules: Secret value object for all API keys (never raw strings); `inspect`/`to_s` override pattern; `.expose` is the only exit; filter_parameters list; Lograge structured logging only; audit log entries filtered before storage; shell commands as argument arrays; `ENV.fetch` not `ENV[]`; `.env` in .gitignore always; rack-attack from day one; brakeman on every build; unauthenticated endpoints are the exception.
  Files: `practices/general/security.md`
  Tests: file exists; references Secret class; references filter_parameters; references rack-attack; references brakeman

- [ ] Create practices/general/reflect.md
  New file. Protocol: one proposal per reflect iteration; every proposal states (a) what will improve and (b) which metric verifies it; no change without measurable hypothesis; reflect output targets practices/, PROMPT_*.md, or config — not application code; exception: append gotchas directly to relevant practices file.
  Files: `practices/general/reflect.md`
  Tests: file exists; contains one-proposal-per-iteration rule; contains measurable hypothesis requirement

- [ ] Update practices/lang/ruby.md with module boundary and shared service rules
  Add: Shared Service Pattern (request struct, single call site); Module Boundaries (cross-module calls through public service interface only, no direct AR queries across boundaries, public interface in `app/modules/{name}/services/{name}_service.rb`).
  Files: `practices/lang/ruby.md`
  Tests: file contains module boundary rule; file contains shared service pattern

- [ ] Update practices/lang/go.md with HTTP client, instrumentation, sidecar discipline rules
  Add: HTTP Clients (shared constructor, consistent User-Agent/timeouts/retry); Instrumentation (structured logging context, log entry/exit for long-running ops, never log secrets); Sidecar Discipline (no business logic in Go, domain decisions belong in Rails).
  Files: `practices/lang/go.md`
  Tests: file contains sidecar discipline rule; file contains HTTP client rule

- [ ] Update practices/framework/rails.md with new rules
  Add: Specs as Source of Truth (read spec before implementing, assume NOT implemented, check codebase first); Route Authorization (every route explicitly public or authenticated, no implicit defaults, update auth tests when routes change); Audit on Destructive Actions (any delete/promote/security-relevant action calls AuditLogger — not optional); Migration Discipline (all migrations in db/migrate/, no data changes in migrations, reversible by default, verify in Docker test container before committing); Lookup Table Maintenance (update lookup table in same commit as the thing being indexed).
  Files: `practices/framework/rails.md`
  Tests: file contains route authorization rule; file contains audit-on-destructive rule; file contains migration discipline rule

- [ ] Create practices/LOOKUP.md
  Maps concepts and rules to the practices file and section that defines them. Rows (alphabetical): `audit on destructive`, `cache_control`, `effort parameter`, `ENV.fetch`, `filter_parameters`, `module boundary`, `RALPH_COMPLETE`, `rack-attack`, `Secret`, `shared service pattern`, `Ultrathink`.
  Files: `practices/LOOKUP.md`
  Tests: file exists; contains table with Secret, cache_control, RALPH_COMPLETE, Ultrathink, module boundary, audit on destructive

- [ ] Create app/modules/LOOKUP.md
  Maps module names to paths and public service interfaces. All five modules: agents, analytics, knowledge, sandbox, tasks.
  Files: `app/modules/LOOKUP.md`
  Tests: file exists; contains all five modules with paths and public interfaces

- [ ] Update specs/README.md lookup table
  Ensure table maps all 16 spec files to their module and loop type. Update whenever a new spec is added.
  Files: `specs/README.md`
  Tests: file exists; contains table with all 16 spec files; all five modules represented


---

## Resolved Ambiguities

The following open questions from the initial planning pass are resolved by the specs:

- **Multi-tenancy scope for Phase 0:** Single org. `org_id = 1` hardcoded or from `ORG_ID` env var. No org creation UI. Auth spec confirms: "Phase 0 scope — single org, no user registration UI." Schema includes `org_id` from day one for additive migration path.
- **MinIO usage:** Removed from Phase 0. `infrastructure.md` Phase 0 service list does not include MinIO. No spec defines what would be stored there. Add when a spec requires it.
- **loop.sh location:** `projects/unpossible2/loop.sh` — within the project directory, consistent with the monorepo structure where each project owns its loop.
- **Go runner source:** Copy into `projects/unpossible2/runner/` — not a submodule. Adapt from unpossible1 dashboard binary. Submodule adds complexity with no benefit at Phase 0.
- **Reviewer LLM Phase 0 scope:** Stub only. `agents.md` explicitly states: "Phase 0: stub — implement in a later iteration." `reviewer_provider` and `reviewer_model` fields exist in the schema; the second AgentRun spawn is not implemented until a plan loop explicitly adds it.

## Remaining Open Questions

> Do not implement until resolved.

- **`ACTIVE_PROJECT` env var:** `research-loop.md` references `ACTIVE_PROJECT` to scope research logs. Clarify: is this set in `.env`, in `loop.sh`, or passed as a CLI argument?
- **Kiro agent config location:** `agents.md` references `~/.kiro/agents/{name}.json`. Clarify: are these committed to the repo under `kiro-agents/` and symlinked, or managed outside the repo?
- **`GET /up` health endpoint:** Rails 8 includes this by default. Confirm it is enabled and not behind authentication before using it in Dockerfile health checks.

