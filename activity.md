# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 40 iterations — initial planning, gap analysis, Rails skeleton + test infra, Sidekiq/Redis + Rubocop + SimpleCov fixes, gap analysis refresh x3, Gemfile.lock fix, docker-compose rename + full dev stack, Solid Queue, Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman + bundler-audit, scaffold modules + LOOKUP.md (0.0.8), JWT auth (0.0.9), Ledger::Node (0.0.10), NodeEdge (0.0.11), ActorProfile + Actor (0.0.12), NodeLifecycleService (0.0.13), NodesController (0.0.14), PlanFileSyncService (0.0.15), gap analysis refresh, Ledger bug fixes (0.0.23), audit events + node level fix + UI specs (0.0.24), AUTH_SECRET extraction, comment rewrite (9.1), test gaps 9.2-9.4 (v0.0.16), MarkdownHelper spec + fix (0.0.25), Knowledge::LibraryItem (0.0.26), Knowledge::MdChunker (0.0.27), Knowledge::EmbedderService (0.0.28), Agents::AgentRun (v0.0.17), Agents::ProviderAdapter (0.0.29 prev), Agents::AgentRunTurn (0.0.29), Agents::PromptDeduplicator (0.0.30), Knowledge::ContextRetriever (0.0.31)]

---

## 2026-04-09 15:30 — Task 12.4: Knowledge::ContextRetriever service

**Mode:** Build
**Iteration:** 40
**Status:** Complete
**Tag:** 0.0.31

**Tasks completed:**
- Created `Knowledge::ContextRetriever` service with `.retrieve(query:, limit:, node_id: nil)` interface
- Embeds query via EmbedderService, runs pgvector cosine similarity search (`<=>` operator)
- Optional `node_id` scopes results to that node and its ancestors via `contains` edges (BFS traversal)
- Uses `Arel.sql` + `sanitize_sql_array` for safe ORDER BY with Rails 8's dangerous query protection
- Spec covers: top-N ordered by cosine similarity, node_id scopes to node tree, empty array when no matches
- Full test suite passes (281 examples, 0 failures, 95.21% coverage)

**Changes:**
- `web/app/modules/knowledge/services/context_retriever.rb` — new
- `web/spec/modules/knowledge/services/context_retriever_spec.rb` — new
- `IMPLEMENTATION_PLAN.md` — marked 12.4 complete

---

## 2026-04-09 15:45 — Task 12.5: Knowledge::IndexerJob

**Mode:** Build
**Iteration:** 41
**Status:** Complete
**Tag:** 0.0.32

**Tasks completed:**
- Created `Knowledge::IndexerJob` on `knowledge` queue — receives node_id or source_path
- Computes SHA256 of source file, skips if unchanged (no embedding calls)
- Splits via MdChunker, embeds via EmbedderService, upserts LibraryItem records keyed on `(source_path, chunk_index)`
- Cleans up stale chunks when file shrinks (deletes chunks beyond current count)
- Fixed pre-existing flaky rack_attack spec (combined 429 status + body assertions into single test)
- Full test suite passes (284 examples, 0 failures, 95.32% coverage)

**Changes:**
- `web/app/modules/knowledge/jobs/indexer_job.rb` — new
- `web/spec/modules/knowledge/jobs/indexer_job_spec.rb` — new
- `web/spec/config/initializers/rack_attack_spec.rb` — fixed flaky body assertion
- `IMPLEMENTATION_PLAN.md` — marked 12.5 complete

---

## 2026-04-09 15:58 — Task 14.1: Sandbox::ContainerRun model + migration

**Mode:** Build
**Iteration:** 42
**Status:** Complete
**Tag:** 0.0.33

**Tasks completed:**
- Created `Sandbox::ContainerRun` model with status enum (pending/running/complete/failed)
- Migration creates `sandbox_container_runs` table with UUID PK, image, command, status, exit_code, stdout, stderr, started_at, finished_at, nullable agent_run_id FK
- `#duration_ms` computed method from started_at/finished_at
- Spec covers: status enum validation, nullable agent_run_id, duration computation, required fields
- Full test suite passes (294 examples, 0 failures, 95.4% coverage)

**Changes:**
- `web/app/modules/sandbox/models/container_run.rb` — new
- `web/db/migrate/20260409000005_create_sandbox_container_runs.rb` — new
- `web/spec/models/sandbox/container_run_spec.rb` — new
- `web/spec/factories/sandbox_container_runs.rb` — new
- `IMPLEMENTATION_PLAN.md` — marked 14.1 complete
