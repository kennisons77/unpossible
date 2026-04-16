# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 48 iterations — initial planning, gap analysis, Rails skeleton + test infra, Sidekiq/Redis + Rubocop + SimpleCov fixes, gap analysis refresh x3, Gemfile.lock fix, docker-compose rename + full dev stack, Solid Queue, Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman + bundler-audit, scaffold modules + LOOKUP.md (0.0.8), JWT auth (0.0.9), Ledger::Node (0.0.10), NodeEdge (0.0.11), ActorProfile + Actor (0.0.12), NodeLifecycleService (0.0.13), NodesController (0.0.14), PlanFileSyncService (0.0.15), gap analysis refresh, Ledger bug fixes (0.0.23), audit events + node level fix + UI specs (0.0.24), AUTH_SECRET extraction, comment rewrite (9.1), test gaps 9.2-9.4 (v0.0.16), MarkdownHelper spec + fix (0.0.25), Knowledge::LibraryItem (0.0.26), Knowledge::MdChunker (0.0.27), Knowledge::EmbedderService (0.0.28), Agents::AgentRun (v0.0.17), Agents::ProviderAdapter (0.0.29 prev), Agents::AgentRunTurn (0.0.29), Agents::PromptDeduplicator (0.0.30), Knowledge::ContextRetriever (0.0.31), Knowledge::IndexerJob (0.0.32), Sandbox::ContainerRun (0.0.33), Sandbox::DockerDispatcher (0.0.34), Agents::AgentRunsController (0.0.35), Kiro agent configs (v0.0.18), Analytics::FeatureFlag (0.0.36), gap analysis refresh (reference-graph supersession), Analytics::FeatureFlagsController (0.0.37)]

---

## 2026-04-16 12:40 — Remove Ledger and Knowledge modules (18.1–18.6, 18.4)

**Mode:** Build
**Iteration:** 49
**Status:** Complete — 0.0.38

**Changes:**
- Deleted all Ledger module code (models, services, controllers, jobs, views, factories, specs)
- Deleted all Knowledge module code (models, services, jobs, factories, specs)
- Deleted BulkSnapshotService, ledger_snapshot initializer, ledger.rake
- Added migrations: remove ledger FKs from agents_agent_runs + add source_ref; drop ledger + knowledge tables
- Updated AgentRun model/factory/spec: removed belongs_to :actor/:node, added source_ref (nullable string)
- Updated RunStorageService: concurrent check now uses source_ref instead of actor_id
- Updated AgentRunsController: permitted params use source_ref
- Removed ledger routes and /session/new stub from routes.rb
- Updated Makefile: removed ledger-export/import/seed, bulk-export/import targets and down-hook
- Updated LOOKUP.md files: removed ledger/knowledge entries, fixed naming (AuditLogger, DockerDispatcher, PromptDeduplicator)
- Updated solid_queue_spec + queue.yml: removed knowledge queue
- Updated module_scaffold_spec: removed Knowledge from module list
- 137 examples, 0 failures, 98.48% coverage
