# IMPLEMENTATION_PLAN.md — Unpossible

**Phase:** 0 (Local — Docker Compose only)
**Generated:** 2026-05-15
**Source of truth:** `specifications/` + code in `web/` and `go/`

## Scope Notes

- Phase 0 only — no CI, no k8s, no staging, no production config
- Reference graph (concept.md priorities 1–7) is a large multi-component system with open questions — spike required before build
- `analytics-dashboard-ui.md` and `agent-runs-ui.md` are `status: proposed` — included as they are Phase 0 scope (server-rendered HTML, no JS framework)
- `log-tail-relay.md` is `status: proposed` with unresolved open questions — spike required
- `repo-map/concept.md` is `status: draft` — spike required

## Spec Contradictions

- **`iteration` column on AgentRun:** Platform spec (`platform/rails/system/agents.md`) references `iteration` column and unique index on `(run_id, iteration)`. The authoritative concept spec (`system/agent-runner/concept.md`) defines `run_id UUID` as unique with no `iteration` column. Schema matches concept spec. Platform spec is stale on this point — no action needed.
- **`FeatureFlagExposure` model:** Platform spec (`platform/rails/product/analytics.md`) lists `Analytics::FeatureFlagExposure` model. Current implementation fires `$feature_flag_called` events directly into `analytics_events` table via `FeatureFlag.enabled?`. This satisfies the acceptance criteria ("Feature flag evaluation automatically fires `$feature_flag_called`") without a separate model. No action needed unless a dedicated exposure table is explicitly required.

---

## 1. Infrastructure — Infra Hardening

### 1.1 Postgres port binding audit (DONE)
Postgres has no `ports:` section in either compose file — internal only. ✓

### 1.2 Image tags use git SHA (PARTIALLY DONE)
`docker-compose.yml` uses `${GIT_SHA:-dev}` — correct pattern. The `docker-compose.test.yml` builds from Dockerfile.test without an explicit image tag (ephemeral, acceptable for test stack). ✓

### 1.3 Redis service missing from docker-compose.yml
The infrastructure concept spec lists Redis in the Phase 0 compose stack. The current `docker-compose.yml` has no Redis service and the `REDIS_URL` env var is commented out. However, `project-requirements.md` does not list Redis as a dependency, and Solid Queue uses Postgres (no Redis needed). The infrastructure concept may be aspirational.

**Decision:** No Redis needed — Solid Queue is Postgres-backed. The commented-out `REDIS_URL` is acceptable. No task.

---

## 2. Swagger / API Documentation Gaps

- [x] 2.1 — Swagger covers agent_runs, analytics/metrics, auth, health, batch endpoints (confirmed in swagger.yaml)
- [x] 2.2 — Add feature_flags endpoints to swagger (`web/spec/requests/analytics/feature_flags_spec.rb`, `web/swagger/v1/swagger.yaml`)
  Required tests: `GET /api/feature_flags` returns 200 with list, `POST /api/feature_flags` returns 201, `PATCH /api/feature_flags/:key` returns 200, 401 unauthenticated, 422 invalid input documented in swagger
  **Note:** The request spec already used rswag DSL. Ran `rake rswag:specs:swaggerize` and copied generated swagger.yaml to host.

---

## 3. Analytics Module Gaps

- [x] 3.1 — Add `mode` column to `analytics_llm_metrics` table (`web/db/migrate/`, `web/app/modules/analytics/models/llm_metric.rb`, `web/app/modules/agents/services/run_storage_service.rb`)
  Required tests: LlmMetric created with mode from AgentRun, MetricsController#llm can filter by mode
  **Rationale:** The analytics concept spec says LLM metrics include `mode`. The `RunStorageService.complete` creates LlmMetric but doesn't store mode. The `MetricsController#llm` endpoint cannot filter by mode from LlmMetric alone (it would need to join AgentRun). Adding `mode` to LlmMetric is the clean fix.

- [x] 3.2 — Add `duration_ms` column to `analytics_llm_metrics` table (`web/db/migrate/`, `web/app/modules/analytics/models/llm_metric.rb`, `web/app/modules/agents/services/run_storage_service.rb`)
  Required tests: LlmMetric stores duration_ms from AgentRun on completion
  **Rationale:** The analytics concept spec says LLM metrics include `duration_ms`. Currently not stored on LlmMetric.

---

## 4. Reference Graph — Controlled Commit Skill (Priority 1)

- [x] [SPIKE] 4.1 — Research reference graph controlled commit skill
  **Findings:** `specifications/research/reference-graph-commit.md`. `LedgerAppender` already exists with no Rails deps. Skill is a markdown procedure file + thin CLI wrapper. No blocking open questions. Build tasks derived: 4.2, 4.3, 4.4.

- [x] 4.2 — Write `specifications/skills/tools/commit.md` — atomic commit skill (stage code, append LEDGER.jsonl status event, update IMPLEMENTATION_PLAN.md checkbox, git commit)
  **Note:** `scripts/controlled-commit.sh` already existed with full implementation. Skill file written to document the procedure and reference the script.

- [x] 4.3 — `scripts/controlled-commit.sh` — standalone shell script wrapping LEDGER.jsonl append + IMPLEMENTATION_PLAN.md update + git commit
  **Note:** Already existed. `scripts/test-controlled-commit.sh` also existed with 20 passing tests.

- [x] 4.4 — Update `specifications/skills/loops/build.md` step 9 to reference the commit skill
  **Note:** Updated step 9 to reference `commit.md` and `scripts/controlled-commit.sh`.

---

## 5. Reference Graph — Go Reference Parser (Priority 2)

- [x] [SPIKE] 5.1 — Research Go reference parser design — run `./loop.sh research reference-graph-parser`
  **Findings:** `specifications/research/reference-graph-parser.md`. Output: JSON to stdout (single object). Node/edge types derived from file conventions per concept spec. Regex over tree-sitter (all patterns are line-oriented; no CGo needed). Git integration via shelling out to `git` (established pattern from runner sidecar). Plan item renumbering handled via title-based stable refs. Build tasks derived: 5.2, 5.3, 5.4, 5.5.

- [x] 5.2 — `go/cmd/reference-parser/main.go` — parser binary (walk files, parse LEDGER.jsonl, shell out to git, emit JSON graph)
  **Spec:** `specifications/system/reference-graph/concept.md` § Go Reference Parser
  **Acceptance:** Binary runs standalone, emits valid JSON graph, deterministic output, degrades gracefully on missing inputs

- [x] 5.3 — `go/cmd/reference-parser/main_test.go` — unit tests with fixture files
  **Spec:** `specifications/system/reference-graph/concept.md` § Go Reference Parser
  **Acceptance:** Tests cover: LEDGER.jsonl parsing, plan item parsing, spec: tag extraction, edge derivation, empty/malformed input handling

- [x] 5.4 — Update `infra/Dockerfile.go` to build `reference-parser` binary alongside runner and analytics
  **Acceptance:** `docker compose build` produces `reference-parser` binary in the Go image

- [ ] 5.5 — Update `specifications/system/reference-graph/concept.md` with finalized node/edge schema from research
  **Acceptance:** Concept spec reflects the node ID derivation rules and edge types decided in 5.1

---

## 6. Reference Graph — Spec Tags in Tests (Priority 3)

- [ ] 6.1 — Add `spec:` metadata tags to existing RSpec files (`web/spec/**/*_spec.rb`)
  Required tests: At least one spec file per module has a `spec:` tag linking to its concept spec. Reference parser (when built) can extract these tags.
  **Blocked by:** 5.1 (parser design determines tag format)

---

## 7. Analytics Dashboard UI (Proposed)

- [ ] [SPIKE] 7.1 — Research analytics dashboard UI requirements — run `./loop.sh research analytics-dashboard-ui`
  **Rationale:** `specifications/system/analytics-dashboard-ui.md` is `status: proposed`. It defines server-rendered HTML views (ERB) for cost/token/loop health. No views directory exists in `web/app/`. Needs: layout/styling decisions, auth pattern for HTML views, route structure.

---

## 8. Agent Runs UI (Proposed)

- [ ] [SPIKE] 8.1 — Research agent runs UI requirements — run `./loop.sh research agent-runs-ui`
  **Rationale:** `specifications/system/agent-runs-ui.md` is `status: proposed`. Server-rendered HTML for browsing run history and inspecting turns. No views exist. Blocked by same decisions as 7.1 (shared layout, auth pattern).

---

## 9. Repo Map (Draft)

- [ ] [SPIKE] 9.1 — Research repo map implementation — run `./loop.sh research repo-map`
  **Rationale:** `specifications/system/repo-map/concept.md` is `status: draft`. Defines a tree-sitter-based AST summary tool. No implementation exists. Open questions: tree-sitter grammar availability for Ruby 3.3, token budget strategy, integration with agent configs.

---

## 10. Log Tail Relay (Proposed)

- [ ] [SPIKE] 10.1 — Research log tail relay approach — run `./loop.sh research log-tail-relay`
  **Rationale:** `specifications/system/log-tail-relay.md` is `status: proposed` with three possible approaches and unresolved open questions. No implementation exists.

---

## 11. Feature Flags — Swagger Coverage

- [ ] 11.1 — Ensure feature_flags request spec uses rswag DSL for swagger generation (`web/spec/requests/analytics/feature_flags_spec.rb`)
  Required tests: `rake rswag:specs:swaggerize` includes `/api/feature_flags` and `/api/feature_flags/:key` in generated swagger.yaml
  **Note:** This may be the same fix as 2.2 — the request spec exists but may not use rswag DSL format. Verify before implementing.

---

## 12. Batch Request — Swagger Coverage

- [ ] 12.1 — Add rswag request spec for `POST /api/batch` (`web/spec/requests/batch_spec.rb`)
  Required tests: `rake rswag:specs:swaggerize` includes `/api/batch` in generated swagger.yaml with request/response schema documented
  **Note:** The batch middleware spec exists (`spec/requests/batch_spec.rb`) but may not use rswag DSL. The route is declared as a proc in routes.rb for documentation purposes.

---

## 13. Cross-Module Access Pattern

- [x] 13.1 — MetricsController queries Agents::AgentRun directly (ACCEPTABLE)
  The `MetricsController#loops` and `#summary` actions query `Agents::AgentRun` directly. Per the LOOKUP.md convention, cross-module calls should go through public interfaces. However, `AgentRun` is a read-only query here (no writes, no business logic invoked). The analytics module's purpose is to aggregate data across modules. This is acceptable per the concept spec which says analytics "feeds the Reflect loop with cost and error patterns" — it needs read access to agent run data. No action needed.

---

## 14. Go Sidecar Tests

- [x] 14.1 — Go runner has tests (`go/cmd/runner/main_test.go`) ✓
- [x] 14.2 — Go analytics sidecar has tests (`go/cmd/analytics/main_test.go`) ✓

---

## Dependency Order

```
Independent (can start now):
  2.2, 3.1, 3.2, 11.1, 12.1

Spikes (research before build):
  4.1 → 5.1 → 6.1
  7.1 → (dashboard build tasks)
  8.1 → (agent runs UI build tasks)
  9.1 → (repo map build tasks)
  10.1 → (log tail relay build tasks)
```

## Completed Work (discovered from code)

- ✓ All three modules (agents, sandbox, analytics) implemented with models, services, controllers
- ✓ Auth (JWT + sidecar token) fully implemented
- ✓ Health check middleware at position 0
- ✓ Batch request middleware
- ✓ Secret value object with redaction
- ✓ PromptDeduplicator, ProviderAdapter (claude/kiro/openai), SkillLoader, ContextRetriever, EnrichmentRunner
- ✓ AgentRunJob with pause/resume, token budget, enrichment, agent_override
- ✓ TurnContentGcJob
- ✓ DockerDispatcher with timeout, secret filtering, argument arrays
- ✓ FeatureFlag with `enabled?` class method, automatic `$feature_flag_called` event
- ✓ AuditLogger (async, never raises)
- ✓ MetricsController (llm, loops, summary, events, flag_stats)
- ✓ Rswag setup with swagger_helper, swagger.yaml generated
- ✓ Lograge, Rack::Attack initializers
- ✓ LedgerAppender for LEDGER.jsonl
- ✓ Go runner sidecar (POST /run, token parsing, POST complete to Rails)
- ✓ Go analytics ingest sidecar (POST /capture, in-memory queue, batch flush, PII filtering, UUID validation)
- ✓ Solid Queue configured (Postgres-backed, no Redis)
- ✓ Ledger and Knowledge module tables removed (reference-graph priority 6 complete)
- ✓ All infra files present: Dockerfile, Dockerfile.go, Dockerfile.test, Dockerfile.agent, docker-compose.yml, docker-compose.test.yml
- ✓ 34+ spec files covering all modules
