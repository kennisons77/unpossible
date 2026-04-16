# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 47 iterations — initial planning, gap analysis, Rails skeleton + test infra, Sidekiq/Redis + Rubocop + SimpleCov fixes, gap analysis refresh x3, Gemfile.lock fix, docker-compose rename + full dev stack, Solid Queue, Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman + bundler-audit, scaffold modules + LOOKUP.md (0.0.8), JWT auth (0.0.9), Ledger::Node (0.0.10), NodeEdge (0.0.11), ActorProfile + Actor (0.0.12), NodeLifecycleService (0.0.13), NodesController (0.0.14), PlanFileSyncService (0.0.15), gap analysis refresh, Ledger bug fixes (0.0.23), audit events + node level fix + UI specs (0.0.24), AUTH_SECRET extraction, comment rewrite (9.1), test gaps 9.2-9.4 (v0.0.16), MarkdownHelper spec + fix (0.0.25), Knowledge::LibraryItem (0.0.26), Knowledge::MdChunker (0.0.27), Knowledge::EmbedderService (0.0.28), Agents::AgentRun (v0.0.17), Agents::ProviderAdapter (0.0.29 prev), Agents::AgentRunTurn (0.0.29), Agents::PromptDeduplicator (0.0.30), Knowledge::ContextRetriever (0.0.31), Knowledge::IndexerJob (0.0.32), Sandbox::ContainerRun (0.0.33), Sandbox::DockerDispatcher (0.0.34), Agents::AgentRunsController (0.0.35), Kiro agent configs (v0.0.18), Analytics::FeatureFlag (0.0.36), gap analysis refresh (reference-graph supersession), Analytics::FeatureFlagsController (0.0.37)]

---

## 2026-04-16 12:25 — Feature flags API controller (11.2)

**Mode:** Build
**Iteration:** 48
**Status:** Complete — 0.0.37

**Changes:**
- Added `Analytics::FeatureFlagsController` with POST/PATCH/GET endpoints, JWT auth
- Added `uniqueness: { scope: :org_id }` validation to `FeatureFlag` model
- Added PATCH route with dot-permitting constraint for flag key param
- Fixed `ledger_project` factory: hardcoded name caused 27 pre-existing test failures
- Fixed `NodeFactory.create_child_question` and `attach_research`: inherit `project_id` from parent
- 345 examples, 0 failures, 90.12% coverage
