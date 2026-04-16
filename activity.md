# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 52 iterations — initial planning through 0.0.40. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman), JWT auth, Ledger module (built then fully removed), Knowledge module (built then fully removed), Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController), Sandbox module (ContainerRun, DockerDispatcher), Analytics::FeatureFlag + controller, Ledger+Knowledge removal (18.1–18.7), specs/docs cleanup, stale reference cleanup (21.1–21.5). 137 examples, 0 failures, 98.48% coverage.]

---

## 2026-04-16 13:27 — Stale reference cleanup (21.1–21.5)

**Mode:** Build
**Iteration:** 53
**Status:** Complete — 0.0.40

**Changes:**
- Removed `ledger:import ledger:seed` from `infra/entrypoint.sh` (tasks deleted in 18.5)
- Replaced `seeds.rb` Ledger::Project reference with no-op comment
- Removed `../ledger:/ledger` volume mount from `infra/docker-compose.yml`
- Updated `application.rb` comments to reference current modules (Agents, Sandbox, Analytics)
- Removed dead `authenticate_session!` method from ApplicationController (called `new_session_path` with no route)
- 137 examples, 0 failures, 98.48% coverage

## 2026-04-16 13:33 — Analytics::AnalyticsEvent model + migration (13.1)

**Mode:** Build
**Iteration:** 54
**Status:** Complete — 0.0.41

**Changes:**
- Created `analytics_events` table: UUID PK, org_id, distinct_id, event_name, node_id (nullable string), properties (jsonb), timestamp, received_at
- Index on (org_id, event_name, timestamp) and node_id
- Append-only model: update/update!/destroy/destroy! raise NotImplementedError
- Factory + spec: validations, append-only enforcement, distinct_id UUID storage, node_id string acceptance
- 150 examples, 0 failures, 98.57% coverage

