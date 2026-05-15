[Prior entries summarised: ~76 iterations across auth, agents, sandbox, analytics, infra, rswag setup, Go sidecars, skill loader, context retriever, enrichment runner. Key outcomes: full Phase 0 Rails stack implemented with 34+ spec files, all modules (agents/sandbox/analytics) operational, rswag API docs, health check middleware, batch request middleware, ledger/knowledge tables dropped per reference-graph spec, Go runner and analytics sidecars built with tests, LedgerAppender implemented.]

## 2026-05-01 11:54 — Planning loop: regenerate IMPLEMENTATION_PLAN.md

**Changes:**
- Deleted stale IMPLEMENTATION_PLAN.md, performed full gap analysis of specs vs code
- Generated fresh plan with 11 sections, 21 tasks (5 spikes, 16 build tasks)
- Key gaps confirmed: go/go.mod missing, infra/Dockerfile.go missing, go/cmd/analytics missing, FeatureFlag.enabled? class method missing, FeatureFlagExposure model missing, LlmMetric missing mode column, MetricsController cross-module violation, swagger missing feature_flags + batch endpoints, run-tests.sh missing from repo
- Spec contradiction flagged: FeatureFlag hypothesis required vs optional (platform spec vs system spec)
- Trimmed activity.md to last 10 entries

## 2026-05-01 11:59 — Add go/go.mod and go/go.sum for Go module foundation (tag 0.0.88)

**Changes:**
- Created `go/go.mod` with module path `github.com/unpossible/unpossible/go`, go 1.23.0
- Generated `go/go.sum` via `go mod tidy` against existing vendor directory
- Added Go binary outputs (`go/runner`, `go/analytics`) to `.gitignore`
- `go build ./...` and `go test ./...` both exit 0; 352 Rails specs still pass

## 2026-05-08 — Go analytics sidecar and Dockerfile.go implemented

**Changes:**
- `go/cmd/analytics/main.go` — full ingest sidecar with POST /capture, in-memory queue, batch flush, PII filtering
- `go/cmd/analytics/main_test.go` — test coverage for ingest, PII, UUID validation
- `infra/Dockerfile.go` — multi-stage build for runner and analytics targets
- `infra/docker-compose.yml` updated with analytics service on port 9100

## 2026-05-15 12:00 — Planning loop: regenerate IMPLEMENTATION_PLAN.md

**Changes:**
- Performed full gap analysis comparing specs vs code in `web/` and `go/`
- Generated fresh plan: 5 build tasks (swagger gaps, LlmMetric mode/duration columns) + 6 spikes (reference graph, dashboard UI, agent runs UI, repo map, log tail relay)
- Most Phase 0 work is complete — remaining gaps are swagger coverage, minor schema additions, and research spikes for proposed/draft specs
- Spec contradictions documented: `iteration` column (stale platform spec), `FeatureFlagExposure` model (superseded by analytics_events approach)
- Trimmed activity.md to last 10 entries

## 2026-05-15 12:22 — Add mode column to analytics_llm_metrics (tag 0.0.93)

**Changes:**
- Migration `20260515000001_add_mode_to_analytics_llm_metrics.rb` adds `mode` string column
- `LlmMetric` validates presence of `mode`
- `RunStorageService.complete` passes `run.mode` when creating `LlmMetric`
- `MetricsController#llm` supports `?mode=` filter param
- Factory, model spec, and request specs updated; 354 examples, 0 failures, 98.68% coverage

**Thinking:**
- The analytics concept spec requires `mode` on LLM metrics so cost can be broken down by agent run mode (plan/build/review/reflect/research). Without it, the `llm` endpoint can only aggregate by provider/model — you can't answer "how much did build loops cost vs plan loops?"
- Adding `mode` to `LlmMetric` directly (rather than joining to `AgentRun`) keeps the metrics table self-contained and the query simple. The `MetricsController#llm` filter is a single `.where(mode:)` clause.

**Challenges:**
- `git add -A` swept up untracked files (polyai-questions.html, unpossible-city/) that were in the working directory. Caught before push and removed via `git rm --cached` + `--amend`. Lesson: stage specific files or check `git status` before committing.

**Alternatives considered:**
- Join `analytics_llm_metrics` to `agents_agent_runs` on `agent_run_id` to get mode at query time — rejected because it couples the metrics query to the agents table, adds a join to every aggregation, and breaks if `agent_run_id` is null.
- Add `mode` as a nullable column with no validation — rejected because a metric without a mode is useless for the breakdown query. Fail-closed: require it.

**Tradeoffs taken:**
- `mode` is a plain string, not an enum at the DB level. Consistent with how `mode` is stored on `agents_agent_runs`. If mode values diverge in the future, a DB-level enum would enforce consistency — acceptable debt for Phase 0.
- Existing `LlmMetric` rows (if any) will have `mode = NULL`, which fails the new validation on create but doesn't affect existing records. Migration is additive; no backfill needed for Phase 0 (no production data).
