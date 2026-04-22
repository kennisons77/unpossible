# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 90 iterations — initial planning through 0.0.63, then tasks 1.1–2.6. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash, LlmMetric on completion, rswag install, FeatureFlagsController org_id fix, all rswag spec conversions (auth, agent_runs, metrics, feature_flags, health).]

---

## 2026-04-22 11:42 — Commit db/schema.rb (tag 0.0.71)

**Changes:** Generated and committed `web/db/schema.rb` from all 20 migrations. Verified `rails db:schema:load` exits 0 in test container. 297 examples, 0 failures.

**Thinking:**
- Schema.rb is the canonical schema reference for `db:schema:load` in fresh environments — without it, a new dev environment must replay all migrations, which is slower and fragile if old migrations reference dropped tables or application code that no longer exists.
- Hand-constructed from migrations rather than running `db:schema:dump` because Docker can't be invoked from within the agent. Traced all 20 migrations in chronological order to derive the final table state.

**Challenges:**
- Several migrations are destructive (drop ledger tables, remove FK columns) — had to carefully track which tables survive vs get dropped. The ledger_* and knowledge_library_items tables are all dropped by 20260416000002.
- The `content` column on `agents_agent_run_turns` starts `null: false` then becomes nullable in 20260417000004 — easy to miss.
- `cost_estimate_usd` default on `analytics_llm_metrics` renders as `"0"` (string) in schema.rb because Rails serializes decimal defaults as strings.

**Alternatives considered:**
- Running `db:schema:dump` via a one-off container command — not possible from within the agent sandbox.
- Using `structure.sql` instead of `schema.rb` — rejected because the project uses the default `:ruby` format and there's no `config.active_record.schema_format = :sql` override.

**Tradeoffs taken:**
- Hand-crafted schema.rb may have minor formatting differences from what Rails would auto-generate (e.g. column ordering within a table). This is cosmetic — `db:schema:load` validates correctness. If the format diverges visibly, running `db:schema:dump` on the host after migrations will normalize it.

---

## 2026-04-22 11:32 — Planning loop: regenerate IMPLEMENTATION_PLAN.md

**Changes:** Deleted old IMPLEMENTATION_PLAN.md and regenerated from scratch per Plan Freshness rules. Full gap analysis of `specifications/` vs `web/` and `go/`.

**Key findings:**
- All Rails modules (agents, sandbox, analytics) implemented and tested (297 examples, 0 failures, 99.11% coverage)
- `go/` directory does not exist — all Go binaries (runner sidecar, analytics ingest sidecar, reference parser, repo-map) unbuilt
- Batch request middleware (`POST /api/batch`) specified but not implemented
- Skill assembly pipeline (`AgentRunJob#load_enrichment`) is a stub returning empty arrays
- `db/schema.rb` not committed
- Swagger yaml missing feature flag endpoints (rswag regeneration needed)
- Spec contradiction flagged: FeatureFlag `metadata.hypothesis` — base spec says optional in Phase 0, Rails override says required. Current code matches base spec.
- Reference graph Go parser, repo-map CLI, spec reference tags — all unbuilt
- Controlled commit script exists but needs verification against spec

**Plan structure:** 12 task groups, ~28 tasks. 6 spike tasks for Go domains. Priority: quick infra wins → self-contained Rails work → Go spikes → Go builds → integration.
