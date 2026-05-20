# IMPLEMENTATION_PLAN.md

Generated: 2026-05-15T13:21 — Phase 0 only (Docker Compose, no CI, no k8s, no staging)

## Scope

Phase 0 — Local development. `docker compose up` starts the stack, `docker compose -f infra/docker-compose.test.yml run --rm test` runs the full suite. All specs in `specifications/system/` with `status: active` are in scope. Specs with `status: proposed` or `status: draft` that describe Phase 2+ features are out of scope. Draft specs that describe Phase 0 MVP features are in scope.

## Spec Contradictions

- **`iteration` column on AgentRun**: Platform override (`specifications/platform/rails/system/agents.md`) references a unique index on `(run_id, iteration)` but the schema uses `run_id` alone (unique). The concept spec does not mention `iteration`. The schema is authoritative — `iteration` is stale in the platform override.
- **`FeatureFlagExposure` model**: Platform override (`specifications/platform/rails/product/analytics.md`) references this model, but the implementation fires `$feature_flag_called` as an `AnalyticsEvent` directly (no separate model). The implementation matches the concept spec's acceptance criteria. The platform override reference is stale.
- **`metadata.hypothesis` required vs optional**: Platform override says required on creation (422 if missing). Feature flags requirements spec says optional in Phase 0. The implementation enforces it on create. Keeping the implementation as-is (stricter is safer).

## Completed Work (confirmed from code)

- [x] Infrastructure: `infra/Dockerfile`, `infra/Dockerfile.test`, `infra/Dockerfile.go`, `infra/Dockerfile.agent`
- [x] Infrastructure: `infra/docker-compose.yml` (rails, go_runner, analytics, agent, postgres)
- [x] Infrastructure: `infra/docker-compose.test.yml` (test + postgres with tmpfs)
- [x] Agents module: `AgentRun` model with all fields, validations, unique index on `run_id`
- [x] Agents module: `AgentRunTurn` model with position, kind, content, purged_at
- [x] Agents module: `AgentRunsController` (start, complete, input endpoints)
- [x] Agents module: `RunStorageService` (start with dedup, complete with LlmMetric, record_input with re-enqueue)
- [x] Agents module: `ProviderAdapter` base class with pinned+sliding trimming
- [x] Agents module: `ClaudeAdapter`, `KiroAdapter`, `OpenAiAdapter`
- [x] Agents module: `PromptDeduplicator`
- [x] Agents module: `AgentRunJob` with concurrency control, enrichment, pause/resume
- [x] Agents module: `TurnContentGcJob`
- [x] Agents module: `SkillLoader`, `ContextRetriever`, `EnrichmentRunner`
- [x] Sandbox module: `ContainerRun` model with status enum, duration_ms
- [x] Sandbox module: `DockerDispatcher` service
- [x] Analytics module: `AnalyticsEvent` model (append-only)
- [x] Analytics module: `AuditEvent` model (append-only, severity enum)
- [x] Analytics module: `LlmMetric` model (append-only, mode column)
- [x] Analytics module: `FeatureFlag` model with `enabled?` class method, auto-fires `$feature_flag_called`
- [x] Analytics module: `FeatureFlagsController` (index, create, update)
- [x] Analytics module: `MetricsController` (llm, loops, summary, events, flag_stats)
- [x] Analytics module: `AuditLogger` + `AuditLogJob`
- [x] Auth: `AuthToken` (encode/decode JWT), `Secret` value object
- [x] Auth: `ApplicationController#authenticate!` with JWT + sidecar token + dev bypass
- [x] Auth: `Api::AuthController#create` (POST /api/auth/token)
- [x] Middleware: `HealthCheckMiddleware` at position 0
- [x] Middleware: `BatchRequestMiddleware`
- [x] API docs: rswag setup, Swagger UI at `/api/docs`
- [x] Swagger: all endpoints documented in `swagger/v1/swagger.yaml`
- [x] Go: runner sidecar (`go/cmd/runner`) with POST /run, metrics, Basic Auth
- [x] Go: analytics ingest sidecar (`go/cmd/analytics`) with POST /capture, batch flush, PII filtering
- [x] Go: reference parser (`go/cmd/reference-parser`) — walks files, git, LEDGER.jsonl, produces JSON graph
- [x] Reference graph: `LedgerAppender` (append-only, idempotent)
- [x] Reference graph: `scripts/controlled-commit.sh` (atomic commit + LEDGER + plan update)
- [x] Reference graph: `specifications/skills/tools/commit.md` skill file
- [x] Security: `Security::PromptSanitizer`, `Security::LogRedactor`
- [x] Config: lograge, rack_attack, solid_queue recurring tasks
- [x] Tests: comprehensive spec coverage (354+ examples, 98%+ coverage)

## Section 1 — Pending Migration

- [x] 1.1 — Apply `duration_ms` migration to `analytics_llm_metrics` (`web/db/migrate/20260515000002_add_duration_ms_to_analytics_llm_metrics.rb`)
  Required tests: `LlmMetric` stores `duration_ms` when provided, allows nil `duration_ms`, validates integer >= 0
  Note: Migration file exists, model validates it, specs test it. Schema.rb needs regeneration (run `db:migrate` in test container). If tests already pass with this migration applied, mark done.

## Section 2 — Infra Hardening

- [x] 2.1 — Postgres port binding: verify Postgres is not bound to `0.0.0.0` in compose files (`infra/docker-compose.yml`, `infra/docker-compose.test.yml`)
  Required tests: no `ports:` directive on postgres service in either compose file (manual inspection — no exposed ports means internal-only on bridge network)
  Note: Current compose files do NOT expose postgres ports — this is already correct. ✅ DONE.

- [x] 2.2 — Image tags use git SHA in compose files (`infra/docker-compose.yml`)
  Required tests: `image:` directives use `${GIT_SHA:-dev}` variable, never `latest`
  Note: Current compose file uses `${GIT_SHA:-dev}` for all custom images. pgvector uses `pgvector/pgvector:pg16` (pinned tag, not `latest`). ✅ DONE.

## Section 3 — Reference Graph: Go Parser Enhancements

The reference parser exists and produces a JSON graph from specs, LEDGER.jsonl, and git. The concept spec has additional acceptance criteria around PR nodes, git notes, and spec tags that may not be fully implemented.

- [x] [SPIKE] 3.1 — Research reference graph parser completeness — run `./loop.sh research reference-graph-parser`
  Findings: PR nodes (pr_opened/pr_review/pr_merged) ✅ fully implemented in parseLedger(). spec: tags in RSpec ✅ fully implemented in parseTestFiles(). blocked-by in plan items ✅ fully implemented in parsePlanItems(). Git notes on merge commits ❌ NOT implemented — parser reads git log but never calls `git notes show {sha}`. This gap is low priority (no consumer of git notes data yet); tracked as a future beat if the web UI needs it.
  Blocks: 3.2, 3.3

- [x] 3.2 — Add PR node support to reference parser if missing (`go/cmd/reference-parser/main.go`)
  Note: Already implemented. TestParseLedger_PRNodes covers all required acceptance criteria. ✅ DONE.
  Blocked by: 3.1

- [x] 3.3 — Add `spec:` tag parsing from RSpec files to reference parser if missing (`go/cmd/reference-parser/main.go`)
  Note: Already implemented. TestParseTestFiles_SpecTagEdge covers all required acceptance criteria. ✅ DONE.
  Blocked by: 3.1

## Section 4 — Reference Graph: PR Skill

- [x] [SPIKE] 4.1 — Research PR skill implementation — review `specifications/skills/tools/pr.md` and determine what's needed
  Findings: `gh pr create` is sufficient for PR creation. LEDGER.jsonl `pr_opened` event format is already defined in the reference parser (pr_number, branch, task_ids, spec_refs, sha_first, sha_last). Task IDs come from LEDGER.jsonl entries matching commits in the branch range. Spec refs come from IMPLEMENTATION_PLAN.md comment metadata. Script pattern follows `scripts/controlled-commit.sh`. `gh` CLI is the only external dependency.
  Blocks: 4.2

- [x] 4.2 — Implement PR skill script (`scripts/pr.sh` or equivalent)
  Required tests: creates PR via `gh pr create`, appends `pr_opened` event to LEDGER.jsonl with task_ids/spec_refs/sha_first/sha_last, exits 0 on success
  Blocked by: 4.1

## Section 5 — Repo Map (Draft Spec)

- [x] [SPIKE] 5.1 — Research repo map implementation — run `./loop.sh research repo-map`
  Determine: Which tree-sitter Go bindings to use? Token budget strategy? Integration with agent configs? Is `smacker/go-tree-sitter` still maintained and suitable?
  Findings: `smacker/go-tree-sitter` requires CGO (wraps C libraries) — incompatible with `CGO_ENABLED=0` used in `Dockerfile.go`. No viable pure-Go tree-sitter alternative exists. Regex-based extraction is the right approach: Ruby class/method signatures and Go exported symbols are well-structured enough for regex without a full AST. Token budget via character-count approximation (4 chars ≈ 1 token) — no external library needed. `REPO_MAP.md` is gitignored (derived artifact), regenerated by `loop.sh` before each iteration. No new dependencies required — stdlib only.
  Blocks: 5.2

- [x] 5.2 — Implement `go/cmd/repo-map` CLI binary (`go/cmd/repo-map/main.go`)
  Required tests: produces markdown summary of Ruby classes/Go types/spec headings, respects `--budget` flag, `--focus` limits to directory, `--output` writes to file, deterministic output, excludes test/vendor files
  Blocked by: 5.1

## Section 6 — UI (Proposed Specs — Phase 0 Scope TBD)

These specs have `status: proposed`. They describe server-rendered HTML views that would be useful for Phase 0 local development but are not required by any active spec's acceptance criteria.

- [x] [SPIKE] 6.1 — Research agent runs UI feasibility — review `specifications/system/agent-runs-ui.md`
  Findings: In Phase 0 scope — spec says "useful for Phase 0 local development." App is full-stack Rails (not API-only). No existing views/layout — this is the first HTML controller. `redcarpet` + `rouge` gems already present for markdown rendering. `MarkdownHelper` already exists. No new gems needed. Minimal inline-styled ERB layout appropriate since no CSS framework exists.
  Blocks: 6.2

- [x] 6.2 — Implement agent runs UI (`web/app/modules/agents/controllers/agent_runs_html_controller.rb`, views)
  Required tests: GET /agent_runs returns 200 with paginated list, GET /agent_runs/:id returns 200 with turn list, auth required
  Blocked by: 6.1

- [x] [SPIKE] 6.3 — Research analytics dashboard UI feasibility — review `specifications/system/analytics-dashboard-ui.md`
  Determine: Is this in Phase 0 scope? Dependencies on existing data?
  Findings: In Phase 0 scope — spec says "useful for Phase 0 local development." App is full-stack Rails (not API-only). `Analytics::LlmMetric` and `Agents::AgentRun` models exist and are fully implemented. `MetricsController` already has `summary`, `llm`, and `loops` actions with exactly the data needed. Layout already has dark-theme CSS with all needed styles. No new gems needed — same pattern as agent runs HTML controller.
  Blocks: 6.4

- [x] 6.4 — Implement analytics dashboard UI (`web/app/modules/analytics/controllers/dashboard_controller.rb`, views)
  Required tests: GET /analytics returns 200 with summary cards, GET /analytics/llm returns 200 with cost breakdown, auth required
  Blocked by: 6.3

## Section 7 — Log Tail Relay (Proposed)

- [x] [SPIKE] 7.1 — Research log tail relay approach — review `specifications/system/log-tail-relay.md`
  Findings: **File relay is the right approach.** The agent container already mounts `..:/workspace` and `../.data:/.data`. A `make logs-snapshot` target on the host runs `docker compose logs --tail=100 <service> > .data/logs-snapshot.txt`; the agent reads `/.data/logs-snapshot.txt`. No new sidecar, no socket exposure, opt-in (developer-triggered), bounded output. HTTP sidecar is overkill for single-user local use. Clipboard/pipe doesn't work in non-interactive agent sessions. `.data/` is already gitignored and has a `snapshots/` subdirectory. Implementation: add `logs-snapshot` Makefile target + document the read path in AGENTS.md.
  Blocks: 7.2

- [x] 7.2 — Implement log tail relay (`make logs-snapshot` Makefile target + AGENTS.md documentation)
  Required tests: `make logs-snapshot` writes last 100 lines of rails logs to `.data/logs-snapshot.txt`; `make logs-snapshot SERVICE=postgres` writes postgres logs; file is readable by agent at `/.data/logs-snapshot.txt`
  Blocked by: 7.1

## Section 8 — CI Drift Detection (Reference Graph Priority 4)

Out of scope for Phase 0. Requires CI (Phase 1). Documented here to prevent re-planning.

## Section 9 — Reference Graph Web UI (Priority 5)

- [x] [SPIKE] 9.1 — Research reference graph web UI — review `specifications/system/reference-graph/concept.md` § Read-Only Web UI
  Determine: What views are needed (current, open, condensed)? What data does the parser output? Server-rendered HTML consuming JSON from the Go parser?
  Findings: Three views needed: current (in-progress beat + ancestor chain via refs edges), open (non-done beats filterable by status), condensed (full node tree grouped by type, collapsible, text search). Parser outputs JSON Graph with nodes (id, type, label, path, status, metadata) and edges (from, to, type). Controller shells out to `go/reference-parser` binary via `Open3.capture3`, configurable via `REFERENCE_PARSER_PATH` env var. Fail-open: returns empty graph if binary missing. Same layout/CSS pattern as existing HTML controllers. No new gems needed.
  Blocks: 9.2

- [x] 9.2 — Implement reference graph web UI (views consuming parser JSON output)
  Required tests: GET /graph/current returns 200, GET /graph/open returns 200 with filterable plan items, GET /graph/condensed returns 200 with collapsible tree
  Blocked by: 9.1

## Notes

- **Ledger/Knowledge removal**: Already complete. Tables dropped, models removed, AgentRun uses string `source_ref` instead of FK to ledger nodes.
- **`infra/k8s/` and `infra/nixos/`**: Must NOT exist until Phase 2 is explicitly planned. Confirmed absent. ✅
- **Go binaries**: `go/runner` and `go/reference-parser` pre-built binaries exist in repo. `go/cmd/analytics` source exists with tests.
- **Swagger coverage**: All active API endpoints are documented. `rake rswag:specs:swaggerize` should exit 0.
- **Test suite**: 354+ examples, 98%+ coverage. All modules have model specs, service specs, request specs, and job specs.
