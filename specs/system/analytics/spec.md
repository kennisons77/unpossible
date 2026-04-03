# Analytics

## What It Does

Captures all signals from the system — LLM costs, loop operations, product events, and
feature flag exposures — into a single queryable store. Feeds the Reflect loop with cost
and error patterns. Enables hypothesis-driven development through experiment
infrastructure.

## Why It Exists

- Ops visibility — loop run counts, failure rates, rollback events, LLM cost patterns
- Experiment infrastructure — feature flag exposures + product events enable hypothesis
  measurement
- Own the data — no third-party service receives any signal by default; outbound
  adapters (PostHog, Datadog, custom webhook) are a post-MVP concern. The analytics
  module will define the adapter interface; projects built with unpossible can plug in
  concrete adapters without changing the core store.
- Future agent diagnosis — `node_id` on LLM events is the explicit join key to ledger
  state, enabling an agent to reconstruct what happened during a failing run

## Ingest Architecture

The ingest path is:
- **Non-blocking** — a slow analytics write never slows the main application
- **Always available** — events are buffered if storage is temporarily unavailable
- **High-throughput** — LLM metrics fire on every agent iteration

A dedicated ingest endpoint with an in-memory queue and batch writes satisfies all
three. The application calls the ingest endpoint fire-and-forget. The ingest process
owns only capture and flush — the application owns all reads and the query API.

The event store is the source of truth — raw events are preserved, never pre-aggregated.
A statsd/Prometheus exporter is a post-MVP read-side projection of the event store for
ops dashboards (Grafana etc.). The exporter aggregates on read; the store does not
change shape to accommodate it.

## Signal Categories

### LLM metrics
Per agent run: provider, model, tokens, cost, mode, duration. `node_id` is the ledger
node ID — the explicit join key between analytics events and ledger state.
```
event_name: "llm.run_completed"
properties: { provider, model, input_tokens, output_tokens, cost_usd, mode, node_id, duration_ms }
distinct_id: <run_id>
```

### Loop metrics
Loop run counts, failure rates, rollback events.
```
event_name: "loop.iteration_completed"
properties: { mode, exit_code, duration_ms, agent, model }
event_name: "loop.rollback_triggered"
properties: { mode, iteration, reason }
```

### Container metrics
Pushed by the sidecar — not scraped via Prometheus pull. Consistent with the ingest
architecture; no separate metrics endpoint required in Phase 0.
```
event_name: "infra.container_metrics"
properties: { container_name, cpu_percent, memory_mb, disk_mb }
```

### Product events
User actions: page views, button clicks, form submissions, feature flag exposures.
```
event_name: "task.promoted"
properties: { task_id, loop_type, org_id }
distinct_id: <user uuid>
```

### Feature flag exposures
Fired automatically when a flag is evaluated — callers don't instrument manually.
```
event_name: "$feature_flag_called"
properties: { flag_key, variant, enabled }
```
Joins with product events on `distinct_id` to compute conversion rates per variant.

## Data Model

```
analytics_events
  id            uuid
  org_id        uuid
  distinct_id   string  — opaque UUID; never an email or name
  event_name    string  — namespaced
  node_id       uuid    — ledger node ID; indexed; nullable (non-LLM events may omit)
  properties    jsonb   — filtered through PII redaction before storage
  timestamp     timestamptz
  received_at   timestamptz
```

`node_id` is a first-class indexed column, not buried in `properties`. Join performance
matters for the future agent diagnosis use case.

## Audit Log

Separate concern from analytics. Analytics is for operational insight; audit is for
compliance and security. They may share a database but nothing else.

## Query API

```
GET /api/analytics/llm       — cost/tokens by provider/model/date
GET /api/analytics/loops     — run counts, failure rates by mode
GET /api/analytics/summary   — total cost this week, tasks completed, loop error rate
GET /api/analytics/events    — paginated event list, filterable by event_name, org_id, date range
GET /api/analytics/flags/:key — exposure counts and conversion rates per variant
```

All endpoints require authentication. The ingest endpoint is internal-only.

## PII & Security

- `distinct_id` is always an opaque UUID — never an email address or name
- `properties` filtered through PII redaction before storage
- Ingest endpoint never exposed publicly

## Acceptance Criteria

- `POST /capture` returns 202 immediately regardless of flush state
- Events flushed within 5 seconds or after 100 events, whichever comes first
- Events buffered in memory if storage temporarily unavailable — no events dropped
- Feature flag evaluation automatically fires `$feature_flag_called` — no manual instrumentation
- `distinct_id` in stored events is always a UUID — never an email or name
- `GET /api/analytics/llm` returns cost aggregated by provider/model, filterable by date range
- `GET /api/analytics/loops` returns run counts and failure rates by mode
- `GET /api/analytics/flags/:key` returns exposure counts and conversion rates per variant
- Ingest endpoint not reachable from outside the internal network
