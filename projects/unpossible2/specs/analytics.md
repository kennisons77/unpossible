# Analytics

## What It Does

A PostHog-style analytics system built in, running as a Go sidecar alongside Rails. It captures four categories of signal — product, LLM, infrastructure, and business logic — stores them in Postgres, and surfaces them through a queryable API and a dashboard UI owned by Rails.

We build this ourselves for the same reason we build everything else: to own the data, avoid sending it to a third party, and make it available to the Reflect loop for self-improvement. The architecture is PostHog-shaped (events, persons, identity resolution, feature flag exposures) but the implementation is ours.

## Why a Go Sidecar

The analytics ingest path needs to be:
- Non-blocking — a slow analytics write must never slow down a Rails request
- Always available — if Rails is restarting, events should still be accepted and buffered
- High-throughput — LLM metrics fire on every agent iteration

A Go sidecar with an in-memory event queue and batch Postgres writes satisfies all three. Rails calls `http://localhost:9100/capture` fire-and-forget. The sidecar batches and flushes to Postgres every 5 seconds or 100 events. Rails owns the query API and UI — the sidecar owns only ingest.

## Four Signal Categories

### 1. Product events
User actions in the UI: page views, button clicks, form submissions, feature flag exposures. PostHog-style named events with properties.

```
event_name: "task.promoted"
properties: { task_id, loop_type, org_id }
distinct_id: <user uuid>
```

### 2. LLM metrics
Per agent run: provider, model, input tokens, output tokens, cost estimate, task type, duration. The raw material for cost analysis and the Reflect loop.

```
event_name: "llm.run_completed"
properties: { provider, model, input_tokens, output_tokens, cost_usd, mode, task_id, duration_ms }
distinct_id: <run_id>
```

### 3. Infrastructure metrics
Loop run counts, failure rates, rollback events, container dispatch results. Complements the Go runner's Prometheus `/metrics` endpoint — Prometheus is for ops alerting, analytics is for trend analysis.

```
event_name: "loop.iteration_completed"
properties: { mode, exit_code, duration_ms, agent, model }

event_name: "loop.rollback_triggered"
properties: { mode, iteration, reason }
```

### 4. Business logic metrics
Feature flag exposures, task completion rates, research loop outcomes, spec coverage. These are the product metrics — is the system actually improving?

```
event_name: "$feature_flag_called"
properties: { flag_key, variant, enabled }
distinct_id: <org_id>

event_name: "task.completed"
properties: { loop_type, duration_ms, reviewer_passed }
```

## Architecture

```
Rails / Go runner
      ↓  POST /capture (fire-and-forget)
Analytics sidecar (Go, port 9100)
      ↓  in-memory queue, batch flush every 5s or 100 events
Postgres (analytics_events table)
      ↑  query
Rails analytics API + UI
```

The sidecar exposes:
- `POST /capture` — accepts a single event or batch array, returns 202 immediately
- `GET /healthz` — liveness check
- No auth on `/capture` — it's internal network only (never public)

## Data Model

### analytics_events

```
id            uuid
org_id        uuid
distinct_id   string  — user uuid, run_id, or org_id depending on event type
event_name    string  — namespaced: "llm.run_completed", "task.promoted", etc.
properties    jsonb
timestamp     timestamptz
received_at   timestamptz  — when the sidecar received it (for lag analysis)
```

Single table. No separate persons/identities table in Phase 0 — identity resolution is a Phase 2 addition. `distinct_id` is sufficient for grouping events by actor.

### analytics_persons (Phase 2)

When identity resolution is needed (anonymous → identified merge, PostHog-style):
- `persons` table: `id`, `org_id`, `properties` (jsonb)
- `person_identities` table: `person_id`, `distinct_id` — multiple distinct_ids per person
- Migration is additive — `analytics_events.distinct_id` already exists

### feature_flag_exposures

```
id          uuid
org_id      uuid
flag_key    string
variant     string
distinct_id string
timestamp   timestamptz
```

Separate table for fast experiment analysis — joins with `analytics_events` on `distinct_id` to compute conversion rates per variant.

## Rails Query API

Rails owns all reads. The sidecar never exposes query endpoints.

```
GET /api/analytics/events          — paginated event list, filterable by event_name, org_id, date range
GET /api/analytics/llm             — aggregate cost/tokens by provider/model/date
GET /api/analytics/loops           — run counts, failure rates, rollback rates by mode
GET /api/analytics/flags/:key      — exposure counts and conversion rates per variant
GET /api/analytics/summary         — dashboard summary: total cost this week, tasks completed, error rate
```

All endpoints require JWT auth. PII is never returned — `distinct_id` is an opaque UUID.

## Dashboard

Rails UI. Four panels matching the four signal categories:

- **Product** — event stream, top events by count, feature flag exposure funnel
- **LLM** — cost by provider/model over time, token efficiency (output/input ratio), most expensive task types
- **Infrastructure** — loop run success rate, rollback frequency, average iteration duration
- **Business logic** — task completion rate by loop type, spec coverage (tasks with specs vs without), reflect loop improvement rate

Phase 0: static tables and simple charts. No real-time streaming. Refresh on page load.

## PII & Security

- `distinct_id` is always an opaque UUID — never an email address or name
- `properties` jsonb is filtered through `Security::PromptSanitizer` patterns before storage in the sidecar
- The sidecar's `/capture` endpoint is internal-only — not exposed through the reverse proxy
- No analytics data is ever sent to a third party

## Audit Log (separate concern)

The audit log (`AuditEvent` in Rails) is a separate table and separate concern from analytics. Analytics is for product insight; audit is for compliance and security. They share Postgres but nothing else. See `security.md`.

## Feature Flags Integration

When `FeatureFlag.enabled?` is called, it fires a `$feature_flag_called` event to the analytics sidecar. This is automatic — callers don't instrument it manually. The `FeatureFlag` model handles it.

Exposure events join with `analytics_events` on `distinct_id` to compute: "of the users who saw variant A, what % completed the target action?" This is the experiment analysis loop.

## Phase 0 Scope

- Analytics sidecar: `/capture` ingest, batch flush to Postgres, `/healthz`
- `analytics_events` table only — no persons, no identity resolution
- `feature_flag_exposures` table
- Rails query API: `/llm`, `/loops`, `/summary`
- Dashboard: LLM cost panel and loop success rate panel — the two highest-value views for Phase 0

Identity resolution, real-time streaming, and the full dashboard are Phase 2.

## Acceptance Criteria

- `POST /capture` returns 202 immediately regardless of flush state
- Events are flushed to Postgres within 5 seconds or after 100 events, whichever comes first
- Sidecar buffers events in memory if Postgres is temporarily unavailable — no events dropped on brief outage
- `GET /api/analytics/llm` returns cost aggregated by provider/model, filterable by date range
- `GET /api/analytics/loops` returns run counts and failure rates by mode
- `GET /api/analytics/summary` returns total cost this week, tasks completed this week, loop error rate
- `FeatureFlag.enabled?` automatically fires a `$feature_flag_called` event — no manual instrumentation
- `distinct_id` in stored events is always a UUID — never an email or name
- `/capture` is not reachable from outside the internal network
- `go test ./...` passes on the analytics sidecar
