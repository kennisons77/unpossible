# IMPLEMENTATION_PLAN.md

Generated: 2026-04-22
Phase: 0 — Local (Docker Compose only)
Scope: Phase 0 tasks only. No CI, no staging, no production config.

## Completed Work (discovered from code and git state)

The following is implemented and tested:

- **Auth:** `Secret`, `AuthToken`, `ApplicationController#authenticate!`, `Api::AuthController`, sidecar token auth, `DISABLE_AUTH` dev bypass
- **Agents module:** `AgentRun` model, `AgentRunTurn` model, `AgentRunsController` (start/complete/input), `RunStorageService`, `PromptDeduplicator`, `ProviderAdapter` base + `ClaudeAdapter` + `KiroAdapter` + `OpenAiAdapter`, `AgentRunJob` (with concurrency control, pause/resume, enrichment, token budget), `TurnContentGcJob`, `SkillLoader`, `ContextRetriever`, `EnrichmentRunner`
- **Sandbox module:** `ContainerRun` model, `DockerDispatcher` service
- **Analytics module:** `AnalyticsEvent` model (append-only), `AuditEvent` model (append-only), `LlmMetric` model (append-only), `FeatureFlag` model with `enabled?` + auto exposure event, `AuditLogger` service, `AuditLogJob`, `MetricsController` (llm/loops/summary/events/flag_stats), `FeatureFlagsController` (index/create/update)
- **Infrastructure:** `HealthCheckMiddleware` at position 0, lograge + `LogRedactor`, `PromptSanitizer`, `rack-attack` rate limiting, Solid Queue config, `filter_parameters`
- **API docs:** rswag installed, Swagger UI at `/api/docs`, request specs in rswag format for all existing controllers
- **Infra:** `Dockerfile` (ruby:3.3-slim final), `Dockerfile.test` (ruby:3.3 full), `docker-compose.yml`, `docker-compose.test.yml`, pgvector/pgvector:pg16
- **Reference graph:** `LedgerAppender` service (append-only LEDGER.jsonl)
- **DB schema:** All tables created, ledger/knowledge tables dropped, FKs updated to string refs

## Infra Issues

### 1. Docker Compose — image tags use `${GIT_SHA:-dev}` not enforced git SHA

The spec says "Image tags in compose files use git SHA, not `latest`." The compose file uses `${GIT_SHA:-dev}` which falls back to `dev` if unset. This is acceptable for Phase 0 local dev — the `GIT_SHA` variable is set in the documented `docker compose up` command. No action needed.

### 2. Docker Compose — Postgres port binding

The spec says "Postgres and Redis ports are not bound to 0.0.0.0 in any compose file." Confirmed: Postgres has no `ports:` mapping in either compose file — internal network only. ✓

### 3. Docker Compose — Go sidecars commented out

Go sidecars (runner, analytics) are correctly commented out with a note: "Phase 0: Go sidecars not yet built." The `go/` directory does not exist. Go sidecar tasks are deferred to when the Go codebase is bootstrapped.

---

## Open Tasks

### Section 1 — Infra & Schema Gaps

- [x] 1.1 Commit db/schema.rb — canonical schema reference *(done — tag 0.0.72)*

### Section 2 — Feature Flag `metadata.hypothesis` Validation

The Rails platform override (`specifications/platform/rails/product/analytics.md`) states: "`feature_flags.metadata` — `hypothesis` field required on creation → 422 if missing." The base concept spec says `metadata.hypothesis` is optional in Phase 0. **The platform override is authoritative for Rails implementation.** However, the current `FeatureFlag` model has no such validation, and the existing test explicitly asserts "is valid without metadata.hypothesis."

**Contradiction:** The platform override requires `hypothesis` on creation; the base concept says optional in Phase 0. The platform override says "required on creation → 422 if missing" which is unambiguous for the Rails implementation.

- [x] 2.1 Add `metadata.hypothesis` presence validation to `Analytics::FeatureFlag` on create (`web/app/modules/analytics/models/feature_flag.rb`, `web/spec/models/analytics/feature_flag_spec.rb`, `web/spec/requests/analytics/feature_flags_spec.rb`)
  Required tests: creating flag without `metadata.hypothesis` returns 422, creating flag with `metadata.hypothesis` succeeds, updating flag does not require hypothesis

### Section 3 — Batch Request Middleware

Spec: `specifications/system/batch-requests.md` — Rack middleware for `POST /api/batch`.

No implementation exists. No code references batch requests anywhere.

- [x] 3.1 Implement `BatchRequestMiddleware` (`web/app/middleware/batch_request_middleware.rb`, `web/config/application.rb`, `web/spec/middleware/batch_request_middleware_spec.rb`)
  Required tests: fans out sub-requests and returns aggregated responses, preserves response ordering, individual sub-request failures don't fail the batch, max batch size exceeded returns 422, malformed JSON returns 422, inherits auth context from outer request, each sub-request runs through full Rack stack
- [x] 3.2 Add rswag request spec for `POST /api/batch` (`web/spec/requests/batch_spec.rb`, `web/config/routes.rb`)
  Required tests: happy path 200, auth failure 401, validation failure 422 (malformed JSON, exceeds max size)

### Section 4 — Reference Graph: Controlled Commit Skill

Spec: `specifications/system/reference-graph/concept.md` § Controlled Commit Skill (Priority 1).

`LedgerAppender` exists and handles LEDGER.jsonl appending. The controlled commit skill (atomic git commit + LEDGER.jsonl + IMPLEMENTATION_PLAN.md update) is not implemented.

- [x] [SPIKE] 4.1 Research controlled commit skill — run `./loop.sh research reference-graph-commit-skill` (see specifications/skills/tools/research.md)
  Open questions: How should the skill be invoked from the build loop? Should it be a Ruby service, a shell script, or a standalone CLI? How to handle IMPLEMENTATION_PLAN.md checkbox updates atomically with git commit?
  Findings: `specifications/research/reference-graph-commit-skill.md` — skill file is the deliverable, `LedgerAppender` handles idempotent append, two-event pattern records SHA post-commit

### Section 5 — Reference Graph: Go Reference Parser

Spec: `specifications/system/reference-graph/concept.md` § Go Reference Parser (Priority 2).

No `go/` directory exists. The parser is a standalone Go binary that walks files + git + LEDGER.jsonl to produce a JSON graph.

- [ ] [SPIKE] 5.1 Research Go reference parser — run `./loop.sh research reference-graph-parser` (see specifications/skills/tools/research.md)
  Open questions: tree-sitter Go bindings for Ruby parsing, LEDGER.jsonl event schema stability, graph output format for web UI consumption, how to bootstrap go.mod and the Go build in the monorepo.

### Section 6 — Reference Graph: Spec Reference Tags in Tests

Spec: `specifications/system/reference-graph/concept.md` § Spec Reference Tags in Tests (Priority 3).

No `spec:` metadata tags exist in any RSpec files. This is a convention — no code changes needed beyond adding tags to existing specs. Blocked by the Go reference parser (which reads these tags).

- [ ] 6.1 Add `spec:` metadata tags to existing RSpec files linking tests to spec sections (`web/spec/**/*_spec.rb`)
  Required tests: N/A — this is a convention change. Verify tags parse correctly once the reference parser exists.
  Depends on: 5.1 (parser must exist to validate tags)

### Section 7 — Reference Graph: Ledger & Knowledge Module Removal

Spec: `specifications/system/reference-graph/concept.md` § Ledger + Knowledge Module Removal (Priority 6).

The DB tables for ledger and knowledge have already been dropped (migration `20260416000002_drop_ledger_and_knowledge_tables`). The `AgentRun` FK to ledger has been removed (migration `20260416000001_remove_ledger_fks_from_agent_runs`). However, some residual code may remain:

- `LedgerAppender` in `web/app/lib/ledger_appender.rb` — this is **retained** as part of the reference graph (it writes to LEDGER.jsonl, which is the new file-based ledger). Not removal target.
- Old ledger migrations still exist in `web/db/migrate/` (20260402000001 through 20260402000007, 20260410000001 through 20260410000005) — these are historical and should remain (Rails convention: never delete migrations).

No further removal work needed. ✓

### Section 8 — Go Sidecar Bootstrap

Spec: `specifications/system/infrastructure/concept.md` — Go runner sidecar (port 8080) and analytics ingest sidecar (port 9100).
Spec: `specifications/system/analytics/requirements.md` — Ingest sidecar (Go) at port 9100.
Spec: `specifications/platform/go/` — Go platform overrides.

No `go/` directory exists. The Go sidecars are required for the full Phase 0 stack per the infrastructure spec.

- [ ] [SPIKE] 8.1 Research Go sidecar architecture — run `./loop.sh research go-sidecars` (see specifications/skills/tools/research.md)
  Open questions: Should the analytics ingest sidecar be built before the runner sidecar? What is the minimal viable runner sidecar for Phase 0? How to structure go.mod for a monorepo with multiple binaries?

- [ ] 8.2 Bootstrap `go/` directory with `go.mod`, `go/cmd/runner/main.go`, `go/cmd/analytics/main.go` stubs
  Depends on: 8.1
  Required tests: `go build ./...` succeeds, `go test ./...` passes

- [ ] 8.3 Implement Go analytics ingest sidecar (`go/cmd/analytics/`) — `POST /capture`, in-memory queue, batch flush to Postgres
  Depends on: 8.2
  Required tests: POST /capture returns 202, events flushed within 5s or 100 events, events buffered on Postgres unavailability, internal-only (not publicly reachable)

- [ ] 8.4 Add `infra/Dockerfile.go` for Go sidecar builds
  Depends on: 8.2
  Required tests: `docker build` succeeds for both runner and analytics targets

- [ ] 8.5 Uncomment Go sidecar services in `infra/docker-compose.yml`
  Depends on: 8.3, 8.4
  Required tests: `docker compose up` starts all services including Go sidecars

- [ ] 8.6 Implement Go runner sidecar (`go/cmd/runner/`) — minimal Phase 0 runner
  Depends on: 8.2
  Required tests: health endpoint responds, basic request/response cycle

### Section 9 — Repo Map

Spec: `specifications/system/repo-map/concept.md` — Go CLI binary for AST-based codebase summary.

No implementation exists. Depends on Go bootstrap.

- [ ] [SPIKE] 9.1 Research repo map implementation — run `./loop.sh research repo-map` (see specifications/skills/tools/research.md)
  Open questions: tree-sitter Go bindings (`smacker/go-tree-sitter`) maturity for Ruby grammar, token budget estimation approach, relevance ranking weights.
  Depends on: 8.2 (Go bootstrap)

### Section 10 — Analytics Dashboard UI

Spec: `specifications/system/analytics-dashboard-ui.md` (status: proposed).

No views exist. The spec requires server-rendered HTML (ERB).

- [ ] 10.1 Implement analytics dashboard views — `GET /analytics` summary, `GET /analytics/llm` breakdown (`web/app/views/analytics/`, `web/app/modules/analytics/controllers/dashboard_controller.rb`, `web/config/routes.rb`, `web/spec/requests/analytics/dashboard_spec.rb`)
  Required tests: GET /analytics returns 200 with summary cards, GET /analytics/llm returns 200 with cost breakdown, auth required (401 without token)

### Section 11 — Agent Runs UI

Spec: `specifications/system/agent-runs-ui.md` (status: proposed).

No views exist. The spec requires server-rendered HTML (ERB).

- [ ] 11.1 Implement agent runs UI views — `GET /agent_runs` history, `GET /agent_runs/:id` detail (`web/app/views/agents/`, `web/app/modules/agents/controllers/agent_runs_ui_controller.rb`, `web/config/routes.rb`, `web/spec/requests/agents/agent_runs_ui_spec.rb`)
  Required tests: GET /agent_runs returns 200 with paginated list, GET /agent_runs/:id returns 200 with turn list, auth required (401 without token), 404 for missing run

### Section 12 — Log Tail Relay

Spec: `specifications/system/log-tail-relay.md` (status: proposed).

No implementation exists. Multiple open questions unresolved.

- [ ] [SPIKE] 12.1 Research log tail relay approach — run `./loop.sh research log-tail-relay` (see specifications/skills/tools/research.md)
  Open questions: Which approach (file relay, HTTP endpoint, clipboard/pipe)? Should the agent request logs proactively? Should it cover all services or just Rails?

### Section 13 — FeatureFlag: Automatic Exposure via Ingest Sidecar

Spec: `specifications/system/feature-flags/requirements.md` states: "Automatic exposure event — `$feature_flag_called` fired on every evaluation via the analytics ingest sidecar."

Current implementation fires the event by writing directly to `AnalyticsEvent` in Postgres (synchronous). The spec says it should go through the Go analytics ingest sidecar. This is blocked by the Go sidecar (Section 8).

- [ ] 13.1 Refactor `FeatureFlag.enabled?` to fire exposure event via ingest sidecar HTTP call instead of direct DB write (`web/app/modules/analytics/models/feature_flag.rb`, `web/spec/models/analytics/feature_flag_spec.rb`)
  Depends on: 8.3 (analytics ingest sidecar)
  Required tests: `enabled?` sends POST to ingest sidecar, event appears in analytics_events after flush, failure to reach sidecar does not raise (fail open)

### Section 14 — Multi-tenancy Hardening

Spec: `specifications/practices/multi-tenancy.md` — every query scoped by org_id.

Current state: most controllers scope by `current_org_id`, but the `MetricsController` queries `Agents::AgentRun` directly (cross-module model access). The LOOKUP.md says "Never access another module's models directly."

- [ ] 14.1 Audit and fix cross-module model access in `Analytics::MetricsController` — queries to `Agents::AgentRun` should go through a public interface (`web/app/modules/analytics/controllers/metrics_controller.rb`, `web/app/modules/agents/services/run_storage_service.rb`)
  Required tests: existing metrics request specs continue to pass, no direct `Agents::AgentRun` reference in analytics module code

### Section 15 — Missing LOOKUP.md Files

Spec: `specifications/practices/changeability.md` — every module directory gets a LOOKUP.md.

`web/app/modules/LOOKUP.md` exists (top-level). Individual module directories (`agents/`, `sandbox/`, `analytics/`) do not have their own LOOKUP.md files.

- [ ] 15.1 Add LOOKUP.md to each module directory (`web/app/modules/agents/LOOKUP.md`, `web/app/modules/sandbox/LOOKUP.md`, `web/app/modules/analytics/LOOKUP.md`)
  Required tests: N/A — documentation only

### Section 16 — Recurring Jobs: Test Environment

The `config/recurring.yml` only defines jobs under `production:`. The `TurnContentGcJob` has no recurring schedule for test or development environments. This is correct — recurring jobs are production-only. ✓

---

## Dependency Graph

```
8.1 (spike: Go sidecars)
  → 8.2 (Go bootstrap)
    → 8.3 (analytics ingest sidecar) → 8.5 (uncomment compose) → 13.1 (flag exposure via sidecar)
    → 8.4 (Dockerfile.go) → 8.5
    → 8.6 (runner sidecar)
    → 9.1 (spike: repo map)
    → 5.1 (spike: Go reference parser)

4.1 (spike: controlled commit skill) — independent

2.1 (hypothesis validation) — independent
3.1 → 3.2 (batch middleware)
10.1 (analytics dashboard UI) — independent
11.1 (agent runs UI) — independent
12.1 (spike: log tail relay) — independent
14.1 (cross-module access) — independent
15.1 (LOOKUP.md files) — independent
6.1 (spec tags) — depends on 5.1
```

## Priority Order

1. **2.1** — Fix spec contradiction (hypothesis validation) — small, independent
2. **3.1, 3.2** — Batch middleware — spec is active, fully defined, no open questions
3. **14.1** — Cross-module access fix — architectural hygiene
4. **15.1** — LOOKUP.md files — documentation
5. **10.1** — Analytics dashboard UI — proposed spec, no blockers
6. **11.1** — Agent runs UI — proposed spec, no blockers
7. **4.1** — Spike: controlled commit skill
8. **8.1** — Spike: Go sidecars (blocks most remaining work)
9. **12.1** — Spike: log tail relay
10. **8.2–8.6** — Go sidecar implementation (after spike)
11. **5.1** — Spike: Go reference parser (after Go bootstrap)
12. **9.1** — Spike: repo map (after Go bootstrap)
13. **13.1** — Flag exposure via sidecar (after analytics sidecar)
14. **6.1** — Spec reference tags (after parser)

## Notes

- The `FeatureFlagExposure` model mentioned in `specifications/platform/rails/product/analytics.md` does not exist and has no migration. The current implementation fires exposure events directly into `AnalyticsEvent`. This is functionally equivalent — the exposure data is captured. A separate `FeatureFlagExposure` model would be needed only if the query pattern requires it (e.g., for faster joins). No task created — current approach satisfies the acceptance criteria.
- The `analytics-dashboard-ui.md` and `agent-runs-ui.md` specs have status `proposed`. They are included in the plan because they are Phase 0 scoped and have no open questions.
- The `log-tail-relay.md` spec has status `proposed` with multiple unresolved open questions — spike task created.
- The `reference-graph/concept.md` spec has status `draft` with several open questions — spike tasks created for the major components.
- The `repo-map/concept.md` spec has status `draft` — spike task created, blocked by Go bootstrap.
