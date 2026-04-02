# Implementation Plan

Generated: 2026-04-01 (gap analysis pass — full refresh)
Phase: 0 (Local Development — Docker Compose only)

> Scope: Phase 0 only. No CI, no k8s, no staging, no production config.
> Infra files in scope: `infra/Dockerfile`, `infra/Dockerfile.test`, `infra/Dockerfile.runner`,
> `infra/Dockerfile.analytics`, `infra/docker-compose.yml`, `infra/docker-compose.test.yml`.

---

## Gap Analysis Notes

**Confirmed implemented (do not re-implement):**
- `infra/Dockerfile` — multi-stage ruby:3.3-slim, non-root, port 3000
- `infra/Dockerfile.test` — test image with entrypoint
- `infra/docker-compose.yml` — test stack (test + postgres pgvector/pgvector:pg16)
- `infra/entrypoint-test.sh`
- Rails app skeleton: Gemfile, Gemfile.lock, config/application.rb, config/database.yml, config/puma.rb, config/routes.rb, config/environments/test.rb
- RSpec + Rubocop + SimpleCov configured (spec_helper.rb, rails_helper.rb, .rubocop.yml, .rspec)
- Lograge initializer (config/initializers/lograge.rb)
- AGENTS.md
- ApplicationController, ApplicationRecord, ApplicationJob (base stubs)

**Critical inconsistencies found:**
1. `Gemfile` declares `solid_queue ~> 1.1` but `Gemfile.lock` resolves `sidekiq 7.3.9` — Gemfile.lock is stale. `solid_queue` is NOT in the lock file. Must be fixed before any job work.
2. `infra/docker-compose.yml` is test-only. The infrastructure spec requires a separate dev compose file (`docker-compose.yml` = full dev stack; `docker-compose.test.yml` = test stack). Currently only the test stack exists.
3. No Redis service in docker-compose.yml but AGENTS.md references `REDIS_URL`. Solid Queue uses Postgres — Redis not needed. AGENTS.md is wrong.
4. `app/app/lib/`, `app/app/modules/`, `app/db/migrate/` are all empty — no domain code exists.
5. `specs/platform/rails/system/tasks.md` references `specs/system/tasks.md` which does not exist. Tasks spec is platform-override-only. Plan tasks from the platform override directly.
6. The Ledger spec (`specs/system/ledger/`) is a major new spec not in the previous plan. It is the foundational data model. All other modules depend on it.

**Spike required:**
- Ledger `stable_ref` design has an open question (agent title drift / semantic dedup). A spike is required before implementing `stable_ref` computation and plan file sync.

---

## Section 1 — Infrastructure Fixes (HIGH PRIORITY)

- [x] Create `infra/Dockerfile` (multi-stage ruby:3.3-slim, non-root, port 3000)
- [x] Create `infra/docker-compose.yml` (test stack: test + postgres pgvector/pgvector:pg16)
- [x] Configure RSpec + Rubocop + SimpleCov
- [x] Configure Lograge structured logging
- [x] Create `AGENTS.md`

- [x] Fix Gemfile.lock — resolve solid_queue, remove sidekiq
  `Gemfile` declares `solid_queue ~> 1.1` but `Gemfile.lock` resolves `sidekiq 7.3.9`. Run `bundle install` inside the container to regenerate the lock file with solid_queue. Remove `redis` gem if not needed (Solid Queue uses Postgres). Update AGENTS.md to remove Redis references.
  Files: `app/Gemfile`, `app/Gemfile.lock`, `AGENTS.md`
  Required tests: `bundle exec rspec` exits 0 in container; `bundle list` shows solid_queue, not sidekiq; no Redis dependency in test suite

- [ ] Rename docker-compose.yml → docker-compose.test.yml; create docker-compose.yml (full dev stack)
  Per `specs/system/infrastructure/spec.md`: `docker-compose.yml` = full dev stack (rails + go_runner + analytics + postgres + redis); `docker-compose.test.yml` = ephemeral test stack. Current file is test-only. Rename it. Create new `docker-compose.yml` with rails (ruby:3.3-slim, port 3000), go_runner (port 8080), analytics (port 9100), postgres (pgvector/pgvector:pg16, internal only), redis (redis:7-alpine, internal only). Postgres and Redis NOT bound to 0.0.0.0. Image tags use git SHA. Update AGENTS.md and PROMPT_build.md to reference docker-compose.test.yml for test runs.
  Files: `infra/docker-compose.yml` (new), `infra/docker-compose.test.yml` (renamed), `AGENTS.md`, `PROMPT_build.md`
  Required tests: `docker compose -f infra/docker-compose.test.yml run --rm test` exits 0; postgres port not bound to 0.0.0.0 in either file; image tags reference git SHA not `latest`

- [ ] Configure Solid Queue
  Add `config.active_job.queue_adapter = :solid_queue` to application.rb. Create `config/queue.yml` with queues: default, knowledge, analytics, tasks. Run `bin/rails solid_queue:install:migrations` to generate migrations. Confirm no Redis dependency.
  Files: `app/config/application.rb`, `app/config/queue.yml`, solid_queue migrations in `app/db/migrate/`
  Required tests: job enqueued on correct queue name; job executes without error in test suite; no Redis connection attempted in tests

- [ ] Create `infra/Dockerfile.runner` (Go runner sidecar)
  Multi-stage: `golang:1.22-alpine` builder copies `runner/`, runs `go build -o /runner`. Final stage `alpine:3.19`, non-root user, exposes 8080. Requires `runner/` source to exist (depends on Section 9).
  Files: `infra/Dockerfile.runner`
  Required tests: `docker build -f infra/Dockerfile.runner .` exits 0; `/healthz` returns 200

- [ ] Create `infra/Dockerfile.analytics` (Go analytics sidecar)
  Multi-stage: `golang:1.22-alpine` builder copies `analytics-sidecar/`, runs `go build -o /analytics`. Final stage `alpine:3.19`, non-root user, exposes 9100. Requires `analytics-sidecar/` source to exist (depends on Section 10).
  Files: `infra/Dockerfile.analytics`
  Required tests: `docker build -f infra/Dockerfile.analytics .` exits 0; `/healthz` returns 200


## Section 2 — Security Foundation

- [ ] Create `Secret` value object
  `app/app/lib/secret.rb`. Wraps a value. Overrides `inspect`, `to_s`, `as_json` → `"[REDACTED]"`. `.expose` is the only way to access the raw value. Used by all provider adapters and anywhere an API key is held.
  Files: `app/app/lib/secret.rb`, `app/spec/lib/secret_spec.rb`
  Required tests: `Secret.new("k").inspect` → `"[REDACTED]"`; `Secret.new("k").to_s` → `"[REDACTED]"`; `Secret.new("k").as_json` → `"[REDACTED]"`; `Secret.new("k").expose` → `"k"`; JSON serialization returns `"[REDACTED]"`

- [ ] Create `Security::LogRedactor` middleware
  Wraps Lograge output. Applies regex patterns (OpenAI `sk-...`, `Bearer ...`, PEM headers, AWS `AKIA...`, JWT `eyJ...`) and replaces with `[REDACTED:<type>]`. Plugged into lograge initializer.
  Files: `app/app/lib/security/log_redactor.rb`, `app/config/initializers/lograge.rb` (update), `app/spec/lib/security/log_redactor_spec.rb`
  Required tests: JWT pattern redacted; OpenAI key pattern redacted; PEM header redacted; normal log lines pass through unchanged

- [ ] Create `Security::PromptSanitizer`
  `Security::PromptSanitizer.sanitize(text)` — applies gitleaks patterns plus PII patterns (email → `[EMAIL]`, phone → `[PHONE]`, IP → `[IP]`). Logs warning to audit log on match. Called by every provider adapter before sending to LLM.
  Files: `app/app/lib/security/prompt_sanitizer.rb`, `app/spec/lib/security/prompt_sanitizer_spec.rb`
  Required tests: email redacted; phone redacted; OpenAI key pattern redacted; clean text passes through; match triggers audit log warning

- [ ] Configure rack-attack rate limiting
  Throttle by IP. Return 429 on limit exceeded. Initializer at `config/initializers/rack_attack.rb`.
  Files: `app/config/initializers/rack_attack.rb`, `app/spec/config/initializers/rack_attack_spec.rb`
  Required tests: >N requests from same IP within window returns 429; normal traffic passes through

- [ ] Configure brakeman and bundler-audit Rake tasks
  Add Rake tasks that run both and exit non-zero on findings.
  Files: `app/lib/tasks/security.rake`
  Required tests: `bundle exec brakeman --exit-on-warn` exits 0 on clean app; `bundle exec bundler-audit check --update` exits 0 on clean Gemfile.lock


## Section 3 — Core Module Structure & Auth

- [ ] Scaffold module directory structure
  Create `app/modules/{knowledge,tasks,agents,sandbox,analytics}/` each with `models/`, `services/`, `jobs/`, `controllers/` subdirectories. Confirm `config/application.rb` already autoloads `app/modules/**/` (it does). Create `app/app/modules/LOOKUP.md`.
  Files: module `.keep` files, `app/app/modules/LOOKUP.md`
  Required tests: each module namespace resolves without NameError; `app/app/modules/LOOKUP.md` exists listing all five modules with paths and public interfaces

- [ ] Create JWT authentication
  `app/app/lib/auth_token.rb` — encodes/decodes JWT with `org_id`, `user_id`, `exp` claims using `jwt` gem. `ApplicationController#authenticate!` before_action sets `current_org_id` and `current_user_id`. `X-Sidecar-Token` header auth for Go sidecar (shared secret from `SIDECAR_TOKEN` env var via `ENV.fetch`). `POST /api/auth/token` issues tokens (Phase 0: shared secret from `AUTH_SECRET` env var). Every route explicitly public or authenticated.
  Files: `app/app/lib/auth_token.rb`, `app/app/controllers/application_controller.rb` (update), `app/app/controllers/api/auth_controller.rb`, `app/config/routes.rb` (update), `app/spec/lib/auth_token_spec.rb`, `app/spec/requests/api/auth_spec.rb`
  Required tests: valid JWT authenticates; expired JWT → 401; tampered JWT → 401; missing token → 401; valid `X-Sidecar-Token` authenticates sidecar endpoints independently; wrong sidecar token → 401; `POST /api/auth/token` with valid shared secret returns JWT


## Section 4 — Ledger Module (NEW — foundational, blocks Sections 5–8)

> The Ledger is the universal data model. All other modules store their artifacts as Nodes.
> The stable_ref open question requires a spike before plan-file sync is implemented.

- [ ] [SPIKE] Research stable_ref dedup strategy — run `./loop.sh research stable-ref` (see specs/skills/tools/research.md)
  Open question from `specs/system/ledger/spec.md`: agent title drift breaks SHA256(normalize(title)+parent_id) when agents paraphrase the same intent. Candidates: semantic dedup (embedding similarity), fuzzy string matching, human-in-the-loop conflict flagging, canonical title enforcement. Spike must produce a recommendation before stable_ref is implemented.
  Blocks: plan-file sync task, activity-log backfill task.

- [ ] Create `Node` model and migration
  Schema per `specs/system/ledger/spec.md`: `id` (uuid), `kind` (enum: question/answer), `answer_type` (enum: terminal/generative, nullable), `scope` (enum: intent/code/deployment/ui/interaction), `body` (text), `title` (string), `spec_path` (string, nullable), `author` (enum: human/agent/system), `stable_ref` (string, indexed), `version` (int, default 1), `status` (enum: open/in_progress/blocked/closed, questions only), `resolution` (enum: done/duplicate/deferred/wont_do/icebox, nullable), `accepted` (enum: true/false/pending, answers only), `accepted_by` (jsonb array, default []), `acceptance_threshold` (int, default 1), `conflict` (boolean, default false), `conflict_disk_state` (text, nullable), `conflict_db_state` (text, nullable), `org_id` (uuid), `recorded_at` (timestamptz), `originated_at` (timestamptz, nullable). Index on (org_id, scope, status). Index on stable_ref.
  Files: `app/app/modules/ledger/models/node.rb`, migration, `app/spec/models/ledger/node_spec.rb`, factory
  Required tests: kind enum validates; scope enum validates; answer node immutable after creation (no update); terminal answer rejects child question creation; generative answer allows child questions; accepted defaults to pending; version increments on status transition; org_id present; factory creates valid record

- [ ] Create `NodeEdge` model and migration
  Schema: `id` (uuid), `parent_id` (FK → nodes), `child_id` (FK → nodes), `edge_type` (enum: contains/depends_on/refs), `ref_type` (string, nullable — git_sha/vector_chunk_id/spec_path/node_id), `primary` (boolean, default false). Index on (parent_id, edge_type). Index on (child_id, edge_type).
  Files: `app/app/modules/ledger/models/node_edge.rb`, migration, `app/spec/models/ledger/node_edge_spec.rb`, factory
  Required tests: edge_type enum validates; ref_type nullable; primary flag works; fan-in (node with multiple contains parents) works; depends_on edge blocks in_progress transition

- [ ] Create `ActorProfile` and `Actor` models and migrations
  `ActorProfile`: `id`, `name`, `provider`, `model`, `allowed_tools` (jsonb array), `prompt_template` (text, nullable), `org_id`. `Actor`: `id`, `actor_profile_id` (FK), `node_id` (FK → nodes), `tools_used` (jsonb array, default []), `created_at`.
  Files: `app/app/modules/ledger/models/actor_profile.rb`, `app/app/modules/ledger/models/actor.rb`, migrations, factories
  Required tests: ActorProfile allowed_tools defaults to []; Actor tools_used defaults to []; Actor belongs_to ActorProfile and Node; factory creates valid records

- [ ] Implement Node lifecycle service (`Ledger::NodeLifecycleService`)
  Enforces: question cannot move to in_progress while any depends_on question is not closed; generative answer child questions not opened until acceptance_threshold reached; false verdict re-opens parent question; true verdict closes question when threshold met; terminal answer rejects child question creation; version increments on every status transition.
  Files: `app/app/modules/ledger/services/node_lifecycle_service.rb`, `app/spec/modules/ledger/services/node_lifecycle_service_spec.rb`
  Required tests: UAT-1 (question lifecycle); UAT-2 (dependency enforcement); UAT-3 (generative answer opens children); question re-opens on false verdict; version increments on each transition; terminal answer blocks child creation

- [ ] Create Ledger API controller (`Ledger::NodesController`)
  `GET /api/nodes` — filter by scope, status, resolution, author, parent_id. `POST /api/nodes` — create question or answer. `GET /api/nodes/:id` — show with edges. `POST /api/nodes/:id/verdict` — submit true/false verdict on an answer. `POST /api/nodes/:id/comments` — create comment node and trigger Knowledge::IndexerJob. All require JWT auth.
  Files: `app/app/modules/ledger/controllers/ledger/nodes_controller.rb`, `app/config/routes.rb` (update), `app/spec/requests/ledger/nodes_spec.rb`
  Required tests: GET /api/nodes filters by scope and status; POST creates question node; verdict true closes question when threshold met; verdict false re-opens question; comment triggers IndexerJob; unauthenticated → 401; answer immutable after creation → 422 on update attempt

- [ ] Create `SpecWatcherJob` (Ledger disk↔DB sync)
  Polls `specs/**/*.md` every 10 seconds. On new file: create Node (scope: intent, status: open). On changed file: parse status header, apply to node, last-write-wins. On deleted file: set resolution: deferred. Detects git revert (file SHA matches prior known SHA) → sets conflict: true, never auto-resolves. After any change: enqueue `Knowledge::IndexerJob`. Phase 0: polling only (no inotify).
  Files: `app/app/modules/ledger/jobs/spec_watcher_job.rb`, `app/spec/modules/ledger/jobs/spec_watcher_job_spec.rb`
  Required tests: new spec file creates Node; changed file updates node status; deleted file sets resolution: deferred; git revert detected → conflict: true; IndexerJob enqueued after change; idempotent (re-run on unchanged file = no-op)

- [ ] Implement plan-file sync (`Ledger::PlanFileSyncService`) — BLOCKED by stable_ref spike
  Reads `IMPLEMENTATION_PLAN.md`. For each checkbox: compute stable_ref, look up in ledger. If found, no-op. If not, create Node (scope: code). Checked items → closed. Orphaned nodes (stable_ref no longer in file) → flagged orphaned, not deleted. Idempotent.
  Files: `app/app/modules/ledger/services/plan_file_sync_service.rb`, `app/spec/modules/ledger/services/plan_file_sync_service_spec.rb`
  Required tests: UAT-4 (plan file sync); unchecked → open; checked → closed; re-sync = no duplicates; removed item → orphaned; idempotent


## Section 5 — Knowledge Module

- [ ] Enable pgvector extension
  Migration to enable `vector` extension. `pgvector` gem already in Gemfile.
  Files: `app/db/migrate/YYYYMMDDHHMMSS_enable_pgvector.rb`
  Required tests: migration runs without error; `ActiveRecord::Base.connection.execute("SELECT '[1,2,3]'::vector")` succeeds

- [ ] Create `LibraryItem` model and migration
  Schema per `specs/system/knowledge/spec.md` + `specs/platform/rails/system/knowledge.md`: `id` (uuid), `org_id`, `node_id` (FK → nodes, nullable), `source_path` (string, nullable), `source_sha` (string, nullable), `chunk_index` (int), `content_type` (enum: md_file/plain_text/link_reference/llm_response/error_context), `content` (text), `embedding` (vector(1536) via pgvector), `archived_at` (nullable). IVFFlat index on embedding for cosine similarity. Unique index on (source_path, chunk_index). Default scope excludes archived items.
  Files: `app/app/modules/knowledge/models/library_item.rb`, migration, `app/spec/models/knowledge/library_item_spec.rb`, factory
  Required tests: content_type enum validates; archived items excluded from default scope; unique index on (source_path, chunk_index); stores and retrieves 1536-dim vector; nearest-neighbor query returns results ordered by cosine distance; factory creates valid record

- [ ] Create `EmbedderService` interface and `OpenAiEmbedder`
  `Knowledge::EmbedderService` abstract interface `embed(text) → Array<Float>`. `Knowledge::OpenAiEmbedder` implements it using `text-embedding-3-small`. API key wrapped in `Secret`. Swappable via `EMBEDDER_PROVIDER=openai|ollama`.
  Files: `app/app/modules/knowledge/services/embedder_service.rb`, `app/app/modules/knowledge/services/open_ai_embedder.rb`, `app/spec/modules/knowledge/services/open_ai_embedder_spec.rb`
  Required tests: returns array of 1536 floats (stub HTTP); raises on API error; API key never appears in logs or error messages; `Secret` wraps the key; provider swappable via env var

- [ ] Create `MdChunker` service
  `Knowledge::MdChunker.chunk(text) → Array<String>`. Splits at paragraph/section boundaries. Preserves section headers with their content.
  Files: `app/app/modules/knowledge/services/md_chunker.rb`, `app/spec/modules/knowledge/services/md_chunker_spec.rb`
  Required tests: splits on blank lines between paragraphs; preserves section headers with content; single-paragraph file returns one chunk; empty input returns empty array

- [ ] Create `Knowledge::IndexerJob`
  Accepts file path or content string + node_id. Computes SHA256. Skips if source_sha matches existing LibraryItem. Chunks via MdChunker. Calls EmbedderService#embed per chunk. Upserts LibraryItem records keyed on (source_path, chunk_index). Updates source_sha. Idempotent. Enqueued on `knowledge` queue. Also handles llm_response and error_context content types (no source_path, tagged with node_id).
  Files: `app/app/modules/knowledge/jobs/indexer_job.rb`, `app/spec/modules/knowledge/jobs/indexer_job_spec.rb`
  Required tests: unchanged file (same SHA256) skips embedding call; changed file re-embeds all chunks; idempotent (run twice = same DB state); job enqueued on `knowledge` queue; llm_response chunk tagged with node_id; error_context chunk tagged with node_id

- [ ] Create `ContextRetriever` service
  `Knowledge::ContextRetriever#retrieve(query:, limit: 5, node_id: nil)` — embeds query, runs pgvector cosine similarity search, returns top-N LibraryItem chunks. When node_id provided, scopes to that node and its ancestors. Excludes archived items.
  Files: `app/app/modules/knowledge/services/context_retriever.rb`, `app/spec/modules/knowledge/services/context_retriever_spec.rb`
  Required tests: returns results sorted by similarity descending; respects limit; returns empty array when no embeddings exist; archived items excluded; node_id scopes to node tree; error_context chunks returned alongside spec chunks when node_id provided

- [ ] Create `Knowledge::LibraryItemsController`
  index (paginated), show. Requires JWT auth.
  Files: `app/app/modules/knowledge/controllers/knowledge/library_items_controller.rb`, `app/config/routes.rb` (update), `app/spec/requests/knowledge/library_items_spec.rb`
  Required tests: index returns paginated items; unauthenticated → 401; 404 on missing item


## Section 6 — Tasks Module

> Note: `specs/system/tasks.md` does not exist. Tasks spec is defined only in
> `specs/platform/rails/system/tasks.md`. Plan from that override directly.

- [ ] Create `Task` model and migration
  Schema per `specs/platform/rails/system/tasks.md`: `id`, `org_id`, `title`, `description` (text), `status` (enum: pending/in_progress/complete/failed/blocked), `loop_type` (enum: plan/build/review/reflect/research), `provider` (string, nullable), `model` (string, nullable), `prompt_template` (text, nullable), `reviewer_provider` (string, nullable), `reviewer_model` (string, nullable), `allowed_tools` (jsonb array, default []), `task_ref` (string, indexed), `depends_on_ids` (jsonb array, default []), `created_at`, `updated_at`.
  Files: `app/app/modules/tasks/models/task.rb`, migration, `app/spec/models/tasks/task_spec.rb`, factory
  Required tests: status enum validates; loop_type enum validates; allowed_tools defaults to []; depends_on_ids defaults to []; task_ref indexed; factory creates valid record

- [ ] Create `Idea` model, migration, and `IdeaParserJob`
  Schema: `id`, `org_id`, `idea_ref` (string, SHA256 of title), `title`, `description` (text), `status` (enum: parked/ready/promoted), `created_at`, `promoted_at` (nullable). `IdeaParserJob` parses `IDEAS.md` and upserts records. `IDEAS.md` is source of truth.
  Files: `app/app/modules/tasks/models/idea.rb`, migration, `app/app/modules/tasks/jobs/idea_parser_job.rb`, `app/app/modules/tasks/services/idea_parser.rb`, `app/spec/models/tasks/idea_spec.rb`, factory
  Required tests: parked/ready/promoted statuses parse correctly; idempotent; only `ready` ideas can be promoted (validated); factory creates valid record

- [ ] Create `Tasks::PlanParserJob` and `PlanParser` service
  Reads `IMPLEMENTATION_PLAN.md`. Parses `- [ ]` (pending) and `- [x]` (complete) checkboxes. Upserts `Task` records keyed on `task_ref` (SHA256 of checkbox text). Preserves manually set `provider`/`model` overrides. Idempotent. Enqueued on `tasks` queue.
  Files: `app/app/modules/tasks/jobs/plan_parser_job.rb`, `app/app/modules/tasks/services/plan_parser.rb`, `app/spec/modules/tasks/services/plan_parser_spec.rb`
  Required tests: unchecked → status: pending; checked → status: complete; idempotent; manual provider override not overwritten; malformed MD logs warning and continues without raising; job enqueued on `tasks` queue

- [ ] Create `Tasks::TasksController` and `Tasks::IdeasController`
  `TasksController`: index (filter by status, loop_type), show, update (status, provider, model overrides). `IdeasController`: index, show. `POST /api/ideas/:id/promote` creates spec file and updates `IDEAS.md` atomically. All require JWT auth.
  Files: `app/app/modules/tasks/controllers/tasks/tasks_controller.rb`, `app/app/modules/tasks/controllers/tasks/ideas_controller.rb`, `app/config/routes.rb` (update), `app/spec/requests/tasks/tasks_spec.rb`, `app/spec/requests/tasks/ideas_spec.rb`
  Required tests: index filters by status and loop_type; idea promote creates spec file and updates IDEAS.md atomically; unauthenticated → 401; promoting non-ready idea → 422


## Section 7 — Agents Module

- [ ] Create `AgentRun` model and migration
  Schema per `specs/system/agent-runner/spec.md` + `specs/platform/rails/system/agents.md`: `id`, `org_id`, `actor_id` (FK → actors, nullable), `node_id` (FK → nodes, nullable), `parent_run_id` (FK self-referential, nullable), `run_id` (uuid), `iteration` (int), `mode` (enum: plan/build/review/reflect/research), `model` (string), `provider` (string), `prompt_sha256` (string, indexed), `input_tokens` (int), `output_tokens` (int), `cost_estimate_usd` (decimal 10,6), `exit_code` (int), `duration_ms` (int), `response_truncated` (boolean, default false), `source_library_item_ids` (jsonb, default []), `created_at`. Unique index on (run_id, iteration).
  Files: `app/app/modules/agents/models/agent_run.rb`, migration, `app/spec/models/agents/agent_run_spec.rb`, factory
  Required tests: factory creates valid record; prompt_sha256 indexed; cost_estimate stores 6 decimal places; uniqueness on (run_id, iteration) enforced at DB level; parent_run_id self-reference works; source_library_item_ids defaults to []

- [ ] Create `Agents::PromptDeduplicator` service
  `#cached_result?(prompt_sha256:, mode:, max_age_hours: 24)` — queries AgentRun for recent successful run with matching prompt_sha256 and mode. Returns cached run or nil. Ignores failed runs and runs older than max_age.
  Files: `app/app/modules/agents/services/prompt_deduplicator.rb`, `app/spec/modules/agents/services/prompt_deduplicator_spec.rb`
  Required tests: returns nil when no match; returns run when match within max_age; ignores failed runs; ignores runs older than max_age

- [ ] Create `Agents::ProviderAdapter` base and `ClaudeAdapter`
  Base class with interface: `build_prompt`, `parse_response`, `cache_config`, `max_context_tokens`. `ProviderAdapter.for(provider_string)` factory method. `ClaudeAdapter` applies `cache_control: {type: "ephemeral", ttl: "1h"}` to practices files and prd.md (>500 tokens). Does NOT cache task description or IMPLEMENTATION_PLAN.md. Aborts with RALPH_WAITING if prompt >150K tokens. Calls `Security::PromptSanitizer.sanitize` before sending. Never enables compaction.
  Files: `app/app/modules/agents/services/provider_adapter.rb`, `app/app/modules/agents/services/claude_adapter.rb`, `app/spec/modules/agents/services/claude_adapter_spec.rb`
  Required tests: `ProviderAdapter.for("claude")` returns ClaudeAdapter; cache_control applied to practices blocks; cache_control NOT applied to task description; prompt >150K tokens aborts with RALPH_WAITING; PromptSanitizer called before send; compaction never enabled

- [ ] Create `Agents::KiroAdapter`
  Invocation: `kiro-cli chat --no-interactive --trust-all-tools --model $MODEL -- "$PROMPT"`. Never passes `--resume`. Selects agent config by loop type from `kiro-agents/`. Aborts with RALPH_WAITING if prompt >150K tokens. Calls `Security::PromptSanitizer.sanitize`.
  Files: `app/app/modules/agents/services/kiro_adapter.rb`, `kiro-agents/ralph_build.json`, `kiro-agents/ralph_plan.json`, `kiro-agents/ralph_research.json`, `kiro-agents/ralph_review.json`, `app/spec/modules/agents/services/kiro_adapter_spec.rb`
  Required tests: `ProviderAdapter.for("kiro")` returns KiroAdapter; never passes --resume; selects correct agent config by loop type; prompt >150K tokens aborts; PromptSanitizer called

- [ ] Create `Agents::OpenAiAdapter`
  Uses `response_format: {type: "json_schema"}` for structured-output tasks. Enforces 75% context window cap. Calls `Security::PromptSanitizer.sanitize`.
  Files: `app/app/modules/agents/services/open_ai_adapter.rb`, `app/spec/modules/agents/services/open_ai_adapter_spec.rb`
  Required tests: `ProviderAdapter.for("openai")` returns OpenAiAdapter; response_format json_schema used for structured tasks; prompt >75% context cap aborts; PromptSanitizer called

- [ ] Create `Agents::AgentRunsController`
  `POST /api/agent_runs/start` — JWT auth; creates AgentRun, assembles prompt, checks dedup, calls Go sidecar `POST /run`; returns cached run on dedup hit. `POST /api/agent_runs/:id/complete` — sidecar token auth (`X-Sidecar-Token`); updates record, triggers `Tasks::PlanParserJob` if mode was plan, calls `Analytics::AuditLogger`. Duplicate (run_id + iteration) → 422. Concurrent run while active → 409.
  Files: `app/app/modules/agents/controllers/agents/agent_runs_controller.rb`, `app/config/routes.rb` (update), `app/spec/requests/agents/agent_runs_spec.rb`
  Required tests: start creates AgentRun and calls sidecar; start returns cached run on dedup hit; complete updates record and triggers PlanParserJob on plan mode; duplicate (run_id+iteration) → 422; concurrent run → 409; wrong sidecar token → 401; parent_run_id links subagent to parent; source_library_item_ids stored; prompt exceeding token limit aborts with RALPH_WAITING before sidecar call


## Section 8 — Analytics Module

- [ ] Create `analytics_events` table and migration
  Schema per `specs/system/analytics/spec.md` + `specs/platform/rails/system/analytics.md`: `id` (uuid), `org_id` (uuid), `distinct_id` (string — opaque UUID, never email), `event_name` (string, namespaced), `properties` (jsonb — filtered through PromptSanitizer before storage), `timestamp` (timestamptz), `received_at` (timestamptz). Index on (org_id, event_name, timestamp). Append-only (no update/destroy).
  Files: `app/app/modules/analytics/models/analytics_event.rb`, migration, `app/spec/models/analytics/analytics_event_spec.rb`, factory
  Required tests: factory creates valid record; no update method exposed; no destroy method exposed; index on (org_id, event_name, timestamp); distinct_id validated as UUID format

- [ ] Create `AuditEvent` model and migration
  Schema: `id`, `org_id`, `actor_id` (string), `resource_type`, `resource_id`, `action`, `severity` (enum: info/warning/critical), `metadata` (jsonb — filtered through Secret redaction and PromptSanitizer), `created_at`. Append-only. Index on (org_id, created_at).
  Files: `app/app/modules/analytics/models/audit_event.rb`, migration, `app/spec/models/analytics/audit_event_spec.rb`, factory
  Required tests: factory creates valid record; no update/destroy exposed; severity enum validates; index on (org_id, created_at); Secret values in metadata stored as "[REDACTED]"

- [ ] Create `FeatureFlag` model and migration
  Schema per `specs/system/feature-flags/spec.md` + `specs/platform/rails/product/analytics.md`: `id`, `org_id`, `key` (string, unique per org), `enabled` (boolean, default false), `variant` (string, nullable), `metadata` (jsonb — `hypothesis` field required on creation), `status` (enum: active/archived, default active), `created_at`, `updated_at`. `FeatureFlag.enabled?` returns false for archived flags without raising. Automatically fires `$feature_flag_called` event on evaluation.
  Files: `app/app/modules/analytics/models/feature_flag.rb`, migration, `app/spec/models/analytics/feature_flag_spec.rb`, factory
  Required tests: key unique per org → 422 on duplicate; enabled defaults to false; metadata.hypothesis required on creation → 422 if missing; archived flag returns false from enabled? without raising; enabled? fires $feature_flag_called event; factory creates valid record

- [ ] Create `FeatureFlagExposure` model and migration
  Schema: `id` (uuid), `org_id` (uuid), `flag_key` (string), `variant` (string), `distinct_id` (string), `timestamp` (timestamptz). Index on (org_id, flag_key, distinct_id).
  Files: `app/app/modules/analytics/models/feature_flag_exposure.rb`, migration, factory
  Required tests: factory creates valid record; index exists

- [ ] Create `LlmMetric` model and migration
  Schema: `id`, `org_id`, `agent_run_id` (FK), `provider`, `model`, `input_tokens` (int), `output_tokens` (int), `cost_estimate_usd` (decimal 10,6), `task_type` (string), `created_at`. Index on (org_id, provider, model, created_at).
  Files: `app/app/modules/analytics/models/llm_metric.rb`, migration, factory
  Required tests: factory creates valid record; index exists; cost_estimate stores 6 decimal places

- [ ] Create `Analytics::AuditLogger` service
  `Analytics::AuditLogger.log(actor:, resource_type:, resource_id:, action:, severity: :info, metadata: {})` — async write to `audit_events` via `AuditLogJob`. Filters metadata through Secret redaction and PromptSanitizer. Never raises. Fire-and-forget.
  Files: `app/app/modules/analytics/services/audit_logger.rb`, `app/app/modules/analytics/jobs/audit_log_job.rb`, `app/spec/modules/analytics/services/audit_logger_spec.rb`
  Required tests: creates AuditEvent asynchronously; Secret values in metadata stored as "[REDACTED]"; PII in metadata redacted; failure to persist logs to Rails logger, does not raise; job enqueued on `analytics` queue

- [ ] Create `Analytics::MetricsController`
  `GET /api/analytics/llm` — aggregate cost/tokens by provider/model/date, filterable by date range. `GET /api/analytics/loops` — run counts and failure rates by mode. `GET /api/analytics/summary` — total cost this week, tasks completed, loop error rate. `GET /api/analytics/events` — paginated event list. `GET /api/analytics/flags/:key` — exposure counts and conversion rates per variant. All require JWT auth.
  Files: `app/app/modules/analytics/controllers/analytics/metrics_controller.rb`, `app/config/routes.rb` (update), `app/spec/requests/analytics/metrics_spec.rb`
  Required tests: llm returns costs grouped by provider; date range filtering works; summary returns three metrics; flags returns exposure counts; unauthenticated → 401; distinct_id in response is UUID not email


## Section 9 — Sandbox Module

- [ ] Create `ContainerRun` model and migration
  Schema per `specs/system/sandbox/spec.md` + `specs/platform/rails/system/sandbox.md`: `id`, `org_id`, `agent_run_id` (FK, nullable), `image` (string), `command` (text), `status` (enum: pending/running/complete/failed), `exit_code` (int, nullable), `started_at`, `finished_at`, `created_at`, `updated_at`. Duration computed from started_at/finished_at.
  Files: `app/app/modules/sandbox/models/container_run.rb`, migration, `app/spec/models/sandbox/container_run_spec.rb`, factory
  Required tests: status enum validates; factory creates valid record; duration computed correctly; agent_run_id nullable at DB level

- [ ] Create `Sandbox::DockerDispatcher` service
  `#dispatch(image:, command:, env: {})`. Shells out to `docker run --rm`. Command passed as argument array — no shell interpolation. Env vars filtered through Secret redaction before logging. Returns `{exit_code:, stdout:, stderr:, duration_ms:}`. Times out after configurable seconds (default 300). Creates and updates `ContainerRun` record. Containers run as non-root, no `--privileged`.
  Files: `app/app/modules/sandbox/services/docker_dispatcher.rb`, `app/spec/modules/sandbox/services/docker_dispatcher_spec.rb`
  Required tests: successful command returns exit_code 0 and stdout; failed command returns non-zero exit_code without raising; Secret env vars not logged; times out after configured seconds; ContainerRun record created and updated with final status; command passed as array (no shell interpolation)


## Section 10 — Go Runner Sidecar

- [ ] Scaffold Go runner (`runner/`)
  Responsibilities: receive `POST /run` (Basic Auth), execute loop via `exec.CommandContext`, mutex (one run at a time → 409 on concurrent), parse token counts from stdout, call `POST /api/agent_runs/:id/complete` on Rails with results, expose `/healthz` (200 when ready), `/metrics` (prometheus/client_golang). Metrics: `runs_total` (counter), `runs_failed_total` (counter), `run_duration_seconds` (histogram), `current_runs` (gauge).
  Files: `runner/main.go`, `runner/go.mod`, `runner/go.sum`
  Required tests: `go test ./...` exits 0; `/healthz` returns 200; `/metrics` returns valid Prometheus text; concurrent POST /run returns 409; POST /run without auth returns 401; calls Rails complete endpoint after loop exits (mock server test)

## Section 11 — Go Analytics Sidecar

- [ ] Scaffold Go analytics sidecar (`analytics-sidecar/`)
  `POST /capture` — accepts single event or batch array, returns 202 immediately. In-memory event queue. Batch flush to Postgres `analytics_events` every 5 seconds or 100 events. Buffers in memory if Postgres temporarily unavailable. `GET /healthz`. No auth on `/capture` — internal network only. `properties` jsonb filtered through gitleaks patterns before storage. `distinct_id` validated as UUID format before storage.
  Files: `analytics-sidecar/main.go`, `analytics-sidecar/go.mod`, `analytics-sidecar/go.sum`
  Required tests: `go test ./...` exits 0; POST /capture returns 202 immediately; events flushed within 5s or 100 events; events buffered on Postgres unavailability; /healthz returns 200; distinct_id non-UUID rejected


## Section 12 — API Documentation (rswag)

- [ ] Configure rswag and generate OpenAPI spec
  Add `rswag-api`, `rswag-ui`, `rswag-specs` gems. Swagger UI at `/api/docs` (unauthenticated). OpenAPI spec at `swagger/v1/swagger.yaml`. `spec/swagger_helper.rb`. Every controller has a corresponding `spec/requests/` file using rswag DSL. `rake rswag:specs:swaggerize` exits 0.
  Files: `app/Gemfile` (update), `app/spec/swagger_helper.rb`, `app/swagger/v1/swagger.yaml`, `app/config/initializers/rswag.rb`
  Required tests: `GET /api/docs` returns 200 without authentication; `rake rswag:specs:swaggerize` exits 0; swagger.yaml lists all API endpoints; every controller has a spec/requests/ file

## Section 13 — Loop & Prompt Templates

- [ ] Create `loop.sh`
  Build mode (default), plan mode, reflect mode, research mode. `AGENT=kiro` and `AGENT=claude` support. Git stash guard per iteration. Log rollback events via `curl POST /api/audit_events`. Create `ralph/{timestamp}` branch when running on main/master. Stop with exit 2 after 3 consecutive iterations without a RALPH signal. `RALPH_WAITING: <question>` pauses for human input.
  Files: `loop.sh`
  Required tests: `./loop.sh plan 1` runs one iteration and exits; failed iteration leaves working tree clean (stash pop); RALPH_COMPLETE exits 0; 3 consecutive no-signal iterations exits 2; AGENT=kiro and AGENT=claude both work

- [ ] Create `PROMPT_reflect.md`
  Instructs agent to: read accumulated AgentRun records via Rails API, identify patterns in costs/errors/review feedback, propose ONE concrete improvement with (a) what will improve and (b) which metric verifies it. Ends with RALPH_COMPLETE or RALPH_WAITING.
  Files: `PROMPT_reflect.md`
  Required tests: file exists; contains RALPH_COMPLETE signal instruction; contains one-proposal rule; contains measurable hypothesis requirement

- [ ] Create `PROMPT_research.md`
  Instructs agent to: read spike node, pause with RALPH_WAITING for interview questions, collect sources, write research log at `specs/research/{feature}.md`, update spec with Research section, trigger IndexerJob. Ends with RALPH_COMPLETE.
  Files: `PROMPT_research.md`
  Required tests: file exists; contains RALPH_WAITING interview instruction; contains source collection format; contains RALPH_COMPLETE instruction

- [ ] Update `PROMPT_build.md` and `PROMPT_plan.md` — fix docker-compose reference
  Update test command reference from `docker-compose.yml` to `docker-compose.test.yml` after Section 1 rename task.
  Files: `PROMPT_build.md`, `PROMPT_plan.md`
  Required tests: files reference docker-compose.test.yml for test runs

## Section 14 — Practices Files

- [ ] Create `practices/general/security.md`
  Rules: Secret value object for all API keys; `inspect`/`to_s` override pattern; `.expose` is the only exit; filter_parameters list; Lograge structured logging only; audit log entries filtered before storage; shell commands as argument arrays; `ENV.fetch` not `ENV[]`; `.env` in .gitignore always; rack-attack from day one; brakeman on every build.
  Files: `practices/general/security.md`
  Required tests: file exists; references Secret class; references filter_parameters; references rack-attack; references brakeman

- [ ] Create `practices/general/reflect.md`
  Protocol: one proposal per reflect iteration; every proposal states (a) what will improve and (b) which metric verifies it; no change without measurable hypothesis; reflect output targets practices/, PROMPT_*.md, or config — not application code.
  Files: `practices/general/reflect.md`
  Required tests: file exists; contains one-proposal-per-iteration rule; contains measurable hypothesis requirement

- [ ] Create `practices/LOOKUP.md`
  Maps concepts to the practices file and section that defines them. Rows (alphabetical): `audit on destructive`, `cache_control`, `effort parameter`, `ENV.fetch`, `filter_parameters`, `module boundary`, `RALPH_COMPLETE`, `rack-attack`, `Secret`, `shared service pattern`, `Ultrathink`.
  Files: `practices/LOOKUP.md`
  Required tests: file exists; contains table with Secret, cache_control, RALPH_COMPLETE, Ultrathink, module boundary, audit on destructive

---

## Resolved Ambiguities

- **Multi-tenancy scope for Phase 0:** Single org. `org_id` from `ORG_ID` env var (default: hardcoded UUID). No org creation UI.
- **MinIO usage:** Removed from Phase 0. No spec defines what would be stored there.
- **loop.sh location:** `projects/unpossible2/loop.sh` — within the project directory.
- **Go runner source:** Copy into `projects/unpossible2/runner/` — not a submodule.
- **Reviewer LLM Phase 0 scope:** Stub only. `reviewer_provider` and `reviewer_model` fields exist in schema; second AgentRun spawn not implemented until a plan loop explicitly adds it.
- **`GET /up` health endpoint:** Rails 8 includes this by default. Confirmed enabled in routes.rb and not behind authentication.
- **Redis:** Solid Queue uses Postgres — no Redis needed in Phase 0. Remove Redis from AGENTS.md and docker-compose.yml.
- **`specs/system/tasks.md`:** Does not exist. Tasks spec is defined only in `specs/platform/rails/system/tasks.md`. Plan from that override directly.

## Remaining Open Questions

> Do not implement until resolved.

- **`ACTIVE_PROJECT` env var:** `specs/skills/loops/plan.md` references `ACTIVE_PROJECT` to scope research logs. Clarify: is this set in `.env`, in `loop.sh`, or passed as a CLI argument?
- **Kiro agent config location:** `specs/platform/rails/system/agents.md` references `kiro-agents/` directory. Clarify: are these committed to the repo under `kiro-agents/` and symlinked, or managed outside the repo?
- **stable_ref dedup strategy:** Blocked on spike (see Section 4). Do not implement plan-file sync or activity-log backfill until spike is resolved.
- **Ledger module namespace:** The `ledger` module is not listed in `specs/prd.md` module list (`knowledge/tasks/agents/sandbox/analytics`). Confirm whether ledger lives under `app/modules/ledger/` or is a top-level concern in `app/models/`.
