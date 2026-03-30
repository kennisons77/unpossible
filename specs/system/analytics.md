# Analytics — System

## What It Does

Captures LLM, infrastructure, and loop signal from every agent iteration. Stores it in Postgres and surfaces it through a queryable API. Feeds the Reflect loop with cost and error patterns for self-improvement.

## Why Build It

- Feed the Reflect loop — LLM cost and error patterns drive self-improvement
- Own the data — no third-party service receives it
- Ops visibility — loop run counts, failure rates, rollback events

## Ingest Architecture

The ingest path must be:
- **Non-blocking** — a slow analytics write must never slow down the main application
- **Always available** — if the app is restarting, events should still be accepted and buffered
- **High-throughput** — LLM metrics fire on every agent iteration

A dedicated ingest process with an in-memory queue and batch writes satisfies all three. The application calls the ingest endpoint fire-and-forget. The ingest process owns only capture and flush — the application owns all reads and the query API.

## Signal Categories

### LLM metrics
Per agent run: provider, model, input tokens, output tokens, cost estimate, task type, duration.
```
event_name: "llm.run_completed"
properties: { provider, model, input_tokens, output_tokens, cost_usd, mode, task_id, duration_ms }
distinct_id: <run_id>
```

### Infrastructure metrics
Loop run counts, failure rates, rollback events, container dispatch results.
```
event_name: "loop.iteration_completed"
properties: { mode, exit_code, duration_ms, agent, model }
event_name: "loop.rollback_triggered"
properties: { mode, iteration, reason }
```

## Audit Log

Separate concern from analytics. Analytics is for operational insight; audit is for compliance and security. They may share a database but nothing else.

## Query API

The application server owns all reads. The ingest process never exposes query endpoints.

```
GET /api/analytics/llm     — aggregate cost/tokens by provider/model/date
GET /api/analytics/loops   — run counts, failure rates by mode
GET /api/analytics/summary — total cost this week, tasks completed, loop error rate
```

All endpoints require authentication.

## PII & Security

- `distinct_id` is always an opaque UUID — never an email address or name
- `properties` are filtered through secret/PII redaction patterns before storage
- The ingest endpoint is internal-only — never exposed publicly

## Phase 0 Scope

- Ingest: `/capture` endpoint, in-memory queue, batch flush
- `analytics_events` table
- Query API: `/llm`, `/loops`, `/summary`
- Dashboard: LLM cost panel and loop success rate panel

## Acceptance Criteria

- `POST /capture` returns 202 immediately regardless of flush state
- Events flushed within 5 seconds or after 100 events, whichever comes first
- Events buffered in memory if storage temporarily unavailable — no events dropped
- `GET /api/analytics/llm` returns cost aggregated by provider/model, filterable by date range
- `GET /api/analytics/loops` returns run counts and failure rates by mode
- `GET /api/analytics/summary` returns total cost this week, tasks completed, loop error rate
- Ingest endpoint is not reachable from outside the internal network
