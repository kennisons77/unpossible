[Prior entries summarised: ~85 iterations across auth, agents, sandbox, analytics, infra, rswag setup, Go sidecars, skill loader, context retriever, enrichment runner, LlmMetric mode/duration columns, reference-graph commit skill, PR skill research. Key outcomes: full Phase 0 Rails stack implemented with 354+ specs at 98%+ coverage, all modules (agents/sandbox/analytics) operational, rswag API docs, health check middleware, batch request middleware, ledger/knowledge tables dropped per reference-graph spec, Go runner and analytics sidecars built with tests, Go reference parser built, LedgerAppender implemented, controlled-commit.sh implemented with 20 tests.]

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

## 2026-05-15 12:55 — Reference graph controlled commit skill research (tag 0.0.95)

**Changes:**
- `specifications/research/reference-graph-commit.md` — research findings for spike 4.1
- `specifications/skills/tools/commit.md` — new skill file documenting the atomic commit procedure
- `specifications/skills/loops/build.md` — step 9 updated to reference commit skill
- `specifications/skills/README.md` — tools table updated with `commit` and `pr` entries
- `IMPLEMENTATION_PLAN.md` — 4.1 marked done, derived tasks 4.2–4.4 added and marked done
- `LEDGER.jsonl` — status event appended for ref 4.1

## 2026-05-15 13:21 — Planning loop: regenerate IMPLEMENTATION_PLAN.md

**Changes:**
- Deleted stale IMPLEMENTATION_PLAN.md, performed full gap analysis of all specs vs code
- Confirmed: vast majority of Phase 0 work is complete (agents, sandbox, analytics, auth, infra, Go sidecars, reference parser, controlled commit)
- Remaining work: 1 pending migration (duration_ms on llm_metrics), research spikes for draft/proposed specs (repo map, UI views, PR skill, log tail relay, reference graph parser completeness)
- Generated fresh plan with 9 sections, 14 tasks (7 spikes, 7 build tasks)
- Infra verified: Postgres not exposed, image tags use git SHA, no Phase 2+ files exist
- Trimmed activity.md to last 4 entries (recent session only)
