# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 32 iterations — initial planning, gap analysis, Rails skeleton + test infra, Sidekiq/Redis + Rubocop + SimpleCov fixes, gap analysis refresh x3, Gemfile.lock fix, docker-compose rename + full dev stack, Solid Queue, Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman + bundler-audit, scaffold modules + LOOKUP.md (0.0.8), JWT auth (0.0.9), Ledger::Node (0.0.10), NodeEdge (0.0.11), ActorProfile + Actor (0.0.12), NodeLifecycleService (0.0.13), NodesController (0.0.14), PlanFileSyncService (0.0.15), gap analysis refresh, Ledger bug fixes (0.0.23), audit events + node level fix + UI specs (0.0.24), AUTH_SECRET extraction, comment rewrite (9.1), test gaps 9.2-9.4 (v0.0.16), MarkdownHelper spec + fix (0.0.25)]

---

## 2026-04-09 14:37 — Task 15.4: Agents::ProviderAdapter + concrete adapters

**Mode:** Build
**Iteration:** 37
**Status:** Complete
**Tag:** 0.0.29

**Tasks completed:**
- Implemented `Agents::ProviderAdapter` base class with `.for(provider)` factory method, `build_prompt`, `parse_response`, `max_context_tokens` abstract interface (raises NotImplementedError)
- Implemented `Agents::ClaudeAdapter` (200K tokens, Anthropic response format)
- Implemented `Agents::KiroAdapter` (200K tokens, Anthropic response format)
- Implemented `Agents::OpenAiAdapter` (128K tokens, OpenAI response format)
- Unknown provider raises ArgumentError
- Full test suite passes (266 examples, 0 failures, 94.86% coverage)

**Changes:**
- `web/app/modules/agents/services/provider_adapter.rb` — new
- `web/app/modules/agents/services/claude_adapter.rb` — new
- `web/app/modules/agents/services/kiro_adapter.rb` — new
- `web/app/modules/agents/services/open_ai_adapter.rb` — new
- `web/spec/modules/agents/services/provider_adapter_spec.rb` — new
- `IMPLEMENTATION_PLAN.md` — marked 15.4 complete

---

## 2026-04-09 14:27 — Task 15.1: Agents::AgentRun model + migration

**Mode:** Build
**Iteration:** 36
**Status:** Complete
**Tag:** v0.0.17

**Tasks completed:**
- Created `agents_agent_runs` table with UUID PK, run_id (unique), actor/node FKs, parent_run_id (nullable), mode/status string enums, token counts, cost_estimate_usd, duration_ms, response_truncated, source_node_ids (jsonb default [])
- Dedup index on `(prompt_sha256, mode)` for future PromptDeduplicator use
- Implemented `Agents::AgentRun` model with MODES/STATUSES constants, inclusion validations, belongs_to associations
- Factory + spec covering mode/status enum validation, nullable parent_run_id, source_node_ids default
- Full test suite passes (250 examples, 0 failures, 94.46% coverage)

**Changes:**
- `web/db/migrate/20260409000003_create_agents_agent_runs.rb` — new
- `web/app/modules/agents/models/agent_run.rb` — new
- `web/spec/factories/agents_agent_runs.rb` — new
- `web/spec/models/agents/agent_run_spec.rb` — new
- `IMPLEMENTATION_PLAN.md` — marked 15.1 complete

---

## 2026-04-09 14:12 — Task 12.3: Knowledge::EmbedderService + OpenAiEmbedder

**Mode:** Build
**Iteration:** 35
**Status:** Complete
**Tag:** 0.0.28

**Tasks completed:**
- Implemented `Knowledge::EmbedderService` with `.for(provider)` factory method dispatching to concrete embedders via `EMBEDDER_PROVIDER` env var (default: openai)
- Implemented `Knowledge::OpenAiEmbedder` calling `text-embedding-3-small` (1536 dims) via `net/http`, API key wrapped in `Secret`
- Ollama and unknown providers raise `NotImplementedError` (Phase 0)
- Full test suite passes (243 examples, 0 failures, 94.32% coverage)

**Changes:**
- `web/app/modules/knowledge/services/embedder_service.rb` — new
- `web/app/modules/knowledge/services/open_ai_embedder.rb` — new
- `web/spec/modules/knowledge/services/embedder_service_spec.rb` — new
- `IMPLEMENTATION_PLAN.md` — marked 12.3 complete

---

## 2026-04-09 14:00 — Task 12.2: Knowledge::MdChunker service

**Mode:** Build
**Iteration:** 34
**Status:** Complete
**Tag:** 0.0.27

**Tasks completed:**
- Implemented `Knowledge::MdChunker` service that splits markdown at paragraph/section boundaries
- Headings are kept together with their following content as a single chunk
- Returns array of `{content:, chunk_index:}` hashes
- Empty/nil input returns empty array
- Full test suite passes (238 examples, 0 failures, 96.33% coverage)

**Changes:**
- `web/app/modules/knowledge/services/md_chunker.rb` — new
- `web/spec/modules/knowledge/services/md_chunker_spec.rb` — new
- `IMPLEMENTATION_PLAN.md` — marked 12.2 complete

---

## 2026-04-09 13:55 — Task 12.1: Knowledge::LibraryItem model + pgvector migration

**Mode:** Build
**Iteration:** 33
**Status:** Complete
**Tag:** 0.0.26

**Tasks completed:**
- Enabled pgvector extension via migration
- Created `knowledge_library_items` table with UUID PK, vector(1536) embedding column, unique index on `(source_path, chunk_index)` for upsert idempotency
- Implemented `Knowledge::LibraryItem` model with content_type enum validation (markdown, plain_text, link_reference, llm_response, error_context), optional node_id FK to Ledger::Node, model-level pgvector array serialization
- Added factory and RSpec tests covering validations, upsert idempotency, nullable fields
- Full test suite passes (234 examples, 0 failures, 96.53% coverage)

**Changes:**
- `web/db/migrate/20260409000001_enable_pgvector.rb` — new
- `web/db/migrate/20260409000002_create_knowledge_library_items.rb` — new
- `web/app/modules/knowledge/models/library_item.rb` — new
- `web/spec/factories/knowledge_library_items.rb` — new
- `web/spec/models/knowledge/library_item_spec.rb` — new
- `IMPLEMENTATION_PLAN.md` — marked 12.1 complete
