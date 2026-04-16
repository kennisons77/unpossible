# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 51 iterations — initial planning through 0.0.39. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman), JWT auth, Ledger module (built then fully removed), Knowledge module (built then fully removed), Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController), Sandbox module (ContainerRun, DockerDispatcher), Analytics::FeatureFlag + controller, Ledger+Knowledge removal (18.1–18.7), specs/docs cleanup. 137 examples, 0 failures, 98.48% coverage.]

---

## 2026-04-16 13:21 — Gap analysis refresh + plan update (iteration 52)

**Mode:** Plan
**Iteration:** 52
**Status:** Complete

**Changes:**
- Full gap analysis comparing `web/` against all specs in `specs/system/`, `specs/platform/rails/`
- Confirmed 5 stale references from ledger removal:
  - `entrypoint.sh` runs deleted `ledger:import ledger:seed` rake tasks (21.1)
  - `seeds.rb` references `Ledger::Project` which no longer exists (21.2)
  - `docker-compose.yml` mounts `../ledger:/ledger` — directory no longer exists (21.3 — NEW)
  - `application.rb` has stale comments referencing Knowledge/Ledger namespaces (21.4)
  - `application_controller.rb` has dead `authenticate_session!` referencing `new_session_path` (21.5)
- Retained all existing plan sections: 13 (Analytics models/query API), 19 (Health Check), 10 (rswag), 20 (Reference Graph spikes), 16 (Go sidecars), 8 (LOOKUP/Dockerfile fixes)
- Verified no skipped/pending tests, no TODOs/FIXMEs in source
- Verified Postgres ports not exposed in compose files (spec compliant)
- Verified no `:latest` tags in compose files (spec compliant)
- Confirmed `specs/practices/LOOKUP.md` references `AuthorizationConcern` which doesn't exist — flagged in 8.2
- Confirmed knowledge/ledger specs marked SUPERSEDED — no stale plan tasks reference them
- Spec contradiction unchanged: `metadata.hypothesis` required (platform override) vs optional (base spec + PRD)
- Trimmed activity.md

## 2026-04-16 13:15 — Gap analysis refresh + plan update

**Mode:** Plan
**Iteration:** 51
**Status:** Complete

**Changes:**
- Full gap analysis comparing `web/` against all specs
- Found 4 stale references from ledger removal: `entrypoint.sh` (ledger rake tasks), `seeds.rb` (Ledger::Project), `application.rb` (stale comments), `application_controller.rb` (dead `new_session_path`)
- Added Section 21 (Stale Reference Cleanup) as highest priority — blocks dev stack startup
- Retained Sections 13 (Analytics models/query API), 19 (Health Check), 10 (rswag), 20 (Reference Graph spikes), 16 (Go sidecars)
- Flagged spec contradiction: `metadata.hypothesis` required (platform override) vs optional (base spec + PRD) — base spec is authoritative, current implementation is correct
- Updated dependency graph: 21.x → 13.x → 10.2; 19.1 and 20.x independent
- Trimmed activity.md

## 2026-04-16 12:58 — Clean up specs and docs for ledger/knowledge removal (18.7)

**Mode:** Build
**Iteration:** 50
**Status:** Complete — 0.0.39

**Changes:**
- Added SUPERSEDED headers to specs/system/ledger/ and specs/system/knowledge/ files
- Deleted specs/system/knowledge-browser-ui.md and specs/platform/rails/system/knowledge.md
- Rewrote specs/README.md Core Paradigm: ledger/NodeEdge → reference graph
- Updated agent-runner spec/prd: actor_id/node_id FKs → source_ref, ActorProfile → agent config
- Updated analytics spec/prd: node_id is string ref, not ledger UUID
- Updated sandbox/api/practices/infrastructure specs: removed all ledger/knowledge references
- Updated all skills files: replaced /api/nodes, knowledge base, ActorProfile references
- Updated practices files: structural-vocabulary, changeability, lookup-tables, coding, cost
- Updated README.md, AGENTS.md, project-prd.md: fixed module list and file structure
- 137 examples, 0 failures, 98.48% coverage

## 2026-04-16 12:30 — Ledger+Knowledge module removal (18.1–18.6, 18.4)

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
- Updated LOOKUP.md files: removed ledger/knowledge entries, fixed naming
- 137 examples, 0 failures, 98.48% coverage
