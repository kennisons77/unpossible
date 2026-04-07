# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 24 iterations — initial planning pass, gap analysis, Rails skeleton + test infra, Sidekiq/Redis + Rubocop + SimpleCov fixes, gap analysis refresh x2, Gemfile.lock fix solid_queue, gap analysis refresh + IMPLEMENTATION_PLAN.md rewrite, docker-compose rename + full dev stack, Solid Queue configuration, Secret value object, Security::LogRedactor, Security::PromptSanitizer, rack-attack rate limiting, brakeman + bundler-audit Rake tasks, scaffold module directory structure + LOOKUP.md files (tag 0.0.8), JWT authentication (tag 0.0.9), Ledger::Node model + migration (tag 0.0.10), Ledger::NodeEdge model + migration (tag 0.0.11), Ledger::ActorProfile + Ledger::Actor models + migrations (tag 0.0.12), Ledger::NodeLifecycleService (tag 0.0.13), Ledger::NodesController (tag 0.0.14), Ledger::PlanFileSyncService (tag 0.0.15), gap analysis + IMPLEMENTATION_PLAN.md refresh (iteration 24)]

---

## 2026-04-02 09:16 — Ledger Bug Fixes: status/verdict/accepted column refs (tag 0.0.23)

**Mode:** Build
**Iteration:** 25
**Status:** Complete

**Tasks completed:** ledger-fix-open-status, ledger-fix-verdict, ledger-fix-open-query, ledger-ui-accepted-ref

**Changes:**
- Replaced all `"open"` status references with `"proposed"` across app code and specs (migration 7 renamed it)
- Added `NodeLifecycleService.record_verdict` — closes parent question on `true`, reopens on `false`; `changed_by` normalized to `"human"` (NodeAuditEvent validates against CHANGED_BY_VALUES)
- Added `"in_progress"` to `VALID_TRANSITIONS["proposed"]`
- Fixed `_assert_no_open_depends_on` error message to match `/open dependency/`
- Removed `accepted`/`acceptance_threshold` column refs from factory traits, node_spec, nodes_spec, NodesController params
- Fixed `LedgerController#open` to query all non-closed statuses
- Fixed `node.html.erb` stale `@node.accepted` references
- Added `redcarpet 3.6.1` and `rouge 4.7.0` to vendor/cache and Gemfile.lock (were in Gemfile but missing)
- Rewrote `node_lifecycle_service_spec` UAT-3 to test `record_verdict` without dropped columns
- Fixed `spec_watcher_job_spec` to use `in_review` (valid for intent scope) not `in_progress`

**Result:** 175 examples, 0 failures (tag 0.0.23)
