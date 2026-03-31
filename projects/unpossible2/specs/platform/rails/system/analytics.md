# Analytics System — Rails Platform Override

Extends `specs/system/analytics.md`. Rails-specific implementation only.

## Models
- `Analytics::AnalyticsEvent` — append-only, no update/destroy exposed
- `Analytics::AuditEvent` — append-only, severity enum: `info / warning / critical`
- `Analytics::LlmMetric` — per agent run cost/token record, `cost_estimate_usd` decimal(10,6)

## Services & Jobs
- `Analytics::AuditLogger` — `AuditLogger.log(...)` async, never raises, fire-and-forget
- `Analytics::AuditLogJob` — Active Job on `analytics` queue

## Controller
- `Analytics::MetricsController` — JWT auth required
  - `GET /api/analytics/llm`
  - `GET /api/analytics/loops`
  - `GET /api/analytics/summary`

## Schema Details
- `analytics_events` — index on `(org_id, event_name, timestamp)`
- `audit_events` — index on `(org_id, created_at)`
- `llm_metrics` — index on `(org_id, provider, model, created_at)`

## Rails-specific Acceptance Criteria
- `AnalyticsEvent` and `AuditEvent` expose no update or destroy methods
- `AuditLogger.log` failure logs to Rails logger, does not raise
