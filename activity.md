# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 61 iterations — initial planning through 0.0.48. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations (2.1, 2.2).]

---

## 2026-04-17 13:01 — Task 2.2: Add org_id to sandbox_container_runs (tag 0.0.45)

**Changes:**
- Created migration for org_id on sandbox_container_runs; updated ContainerRun model and DockerDispatcher
- 171 examples, 0 failures, 98.69% coverage

---

## 2026-04-17 13:05 — Task 3.1: Analytics::LlmMetric model (tag 0.0.46)

**Changes:**
- Created analytics_llm_metrics table, LlmMetric model (append-only, decimal(10,6) cost), factory, spec
- 182 examples, 0 failures, 98.75% coverage

---

## 2026-04-17 13:15 — Tasks 3.2 + 3.3: AuditLogger service + AuditLogJob (tag 0.0.47)

**Changes:**
- Created `web/app/modules/analytics/jobs/audit_log_job.rb` — Active Job on analytics queue, creates AuditEvent via create!
- Created `web/app/modules/analytics/services/audit_logger.rb` — fire-and-forget wrapper, rescues StandardError, logs to Rails.logger
- Created specs for both; used `around` block to set queue_adapter: :test for enqueue matchers
- 190 examples, 0 failures, 98.79% coverage

---

## 2026-04-17 13:34 — Task 3.5: events + flags/:key endpoints (tag 0.0.49)

**Changes:**
- Added `events` action to MetricsController: paginated, filterable by event_name/date range
- Added `flag_stats` action: exposure counts + conversion rates per variant via JSONB property queries
- Added routes: GET /api/analytics/events, GET /api/analytics/flags/:key
- Extended metrics_spec.rb with 9 new examples covering pagination, filtering, org isolation, conversion rates
- 207 examples, 0 failures, 98.94% coverage
