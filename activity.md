# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 57 iterations — initial planning through 0.0.43. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack, brakeman), JWT auth, Ledger module (built then fully removed), Knowledge module (built then fully removed), Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController), Sandbox module (ContainerRun, DockerDispatcher), Analytics::FeatureFlag + controller, Analytics::AnalyticsEvent model, Analytics::AuditEvent model, HealthCheckMiddleware, Ledger+Knowledge removal, specs/docs cleanup, stale reference cleanup.]

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

## 2026-04-17 13:25 — Task 3.4: Analytics::MetricsController (tag 0.0.48)

**Changes:**
- Created `web/app/modules/analytics/controllers/metrics_controller.rb` — GET /api/analytics/llm, /loops, /summary; all require JWT auth
- Added routes for all three endpoints
- Created `web/spec/requests/analytics/metrics_spec.rb` — covers aggregation, date filtering, org isolation, 401 without auth
- 198 examples, 0 failures, 98.88% coverage
