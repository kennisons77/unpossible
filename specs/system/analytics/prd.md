# PRD: Analytics

- **Status:** Draft
- **Created:** 2026-04-01
- **Last revised:** 2026-04-01

## Intent

Analytics is the single internal store for all signals produced by the platform and the
projects built on it — LLM costs, loop operations, infrastructure metrics, product
events, and feature flag exposures. It exists so the developer can see what the system
is doing and why it costs what it costs, so experiments can be measured against
hypotheses, and so future agents can diagnose failures by joining analytics events to
ledger state.

## Personas

- **Developer (primary):** running loops manually, watching costs, debugging failures.
  Needs to know which model is expensive, which loops are failing, and what happened
  during a specific run.
- **Product owner (later):** reviewing experiment results. Needs to know whether a
  feature flag variant moved the metric it was supposed to move.
- **Agent (future):** diagnosing production failures. Needs to join a ledger node ID to
  its analytics events and error signals to understand what went wrong and propose a fix.

## User Scenarios

**Scenario 1 — Watching loop costs:**
A developer runs the build loop overnight. In the morning they query
`GET /api/analytics/llm` filtered to the last 24 hours. They see cost broken down by
model and mode, identify that opus is being used for a task type that sonnet handles
fine, and update the actor profile.

**Scenario 2 — Debugging a loop failure:**
A loop iteration exits non-zero. The developer queries `GET /api/analytics/loops`
filtered by exit code, finds the failing iteration, and uses the `node_id` on the
associated `llm.run_completed` event to pull up the ledger node and its full turn
history.

**Scenario 3 — Measuring an experiment:**
A feature flag `analytics.cost_alerts` is created with a hypothesis. The flag is
enabled for a subset of runs. The developer queries `GET /api/analytics/flags/analytics.cost_alerts`
and sees exposure counts and conversion rates per variant, confirming or rejecting the
hypothesis before archiving the flag.

**Scenario 4 — Infrastructure health:**
A developer notices slow loop iterations. They query container metrics and see memory
pressure on the sandbox container correlating with the slowdown. They adjust the
container resource limits.

**Scenario 5 — Future agent diagnosis (post-MVP):**
A production failure is recorded as a failed answer node in the ledger. An agent queries
analytics for all events with that `node_id`, finds a cost spike and an OOM event on
the sandbox container at the same timestamp, and proposes a fix.

## User Stories

- As a developer, I want to see LLM cost by model and mode over a date range so I can
  make informed actor profile decisions.
- As a developer, I want to see loop failure rates and exit codes so I can identify
  systemic problems.
- As a developer, I want to see container CPU, memory, and disk metrics so I can
  diagnose infrastructure problems.
- As a developer, I want to query raw events by event name, org, and date range so I
  can investigate specific incidents.
- As a developer, I want feature flag exposure counts and conversion rates per variant
  so I can measure hypotheses.
- As the system, I want to capture events fire-and-forget without slowing the main
  application.
- As the system, I want events buffered in memory if storage is temporarily unavailable
  so no signals are lost.

## Success Metrics

| Goal | Metric |
|---|---|
| Ingest never blocks | `POST /capture` p99 latency < 5ms |
| No signal loss | Zero events dropped on brief Postgres outage |
| Cost visibility | Developer can answer "what did last night's loop cost?" in one query |
| Experiment measurement | Conversion rate per flag variant queryable without manual joins |

## Functional Requirements

**MVP:**

- **Ingest sidecar (Go)** — `POST /capture` accepts single event or batch array, returns
  202 immediately. In-memory queue, batch flush to Postgres every 5 seconds or 100
  events, whichever comes first. Buffers in memory on Postgres unavailability. Internal
  network only — never exposed publicly. Port 9100.

- **Signal categories:**
  - `llm.run_completed` — provider, model, input/output tokens, cost_usd, mode,
    `node_id` (ledger node ID — explicit join key to ledger state), duration_ms
  - `loop.iteration_completed` — mode, exit_code, duration_ms, agent, model
  - `loop.rollback_triggered` — mode, iteration, reason
  - `infra.container_metrics` — container name, cpu_percent, memory_mb, disk_mb
  - Product events — event_name, properties, distinct_id (opaque UUID)
  - `$feature_flag_called` — fired automatically on flag evaluation, flag_key, variant,
    enabled. No manual instrumentation by callers.

- **Query API (Rails):**
  - `GET /api/analytics/llm` — cost and tokens by provider/model, filterable by date range and mode
  - `GET /api/analytics/loops` — run counts and failure rates by mode and exit code
  - `GET /api/analytics/summary` — total cost this week, loop error rate, beats completed
  - `GET /api/analytics/events` — paginated raw event list, filterable by event_name, org_id, date range
  - `GET /api/analytics/flags/:key` — exposure counts and conversion rates per variant
  - All endpoints require authentication. Ingest endpoint requires no auth (internal only).

- **PII & security** — `distinct_id` is always an opaque UUID, never an email or name.
  `properties` filtered through PII redaction before storage. Ingest endpoint not
  reachable from outside the internal network.

- **Multi-tenancy** — `org_id` on every event from day one. Phase 0 is single-org
  (`org_id = 1`). Projects built with unpossible share the same store, isolated by
  `org_id`.

- **Audit log** — separate concern. May share the database but nothing else. Analytics
  is for operational insight; audit is for compliance.

**Post-MVP:**

- statsd/Prometheus exporter — read-side projection of the event store for Grafana
  dashboards. The event store remains the source of truth; the exporter aggregates on
  read.
- Outbound adapter interface — projects built with unpossible can push events to
  PostHog, Datadog, or a custom webhook via an adapter. The analytics module defines the
  interface; concrete adapters are post-MVP.
- Agent consumption — structured query endpoint for agents diagnosing failures, joining
  `node_id` on analytics events to ledger state and error signals.
- Alerting — threshold-based alerts on cost spikes or error rate increases.

## Features Out

- UI dashboard (Phase 0 is API only)
- Real-time streaming of events
- Direct PostHog/Datadog integration (interface design only, no concrete adapters)
- Agent-driven diagnosis (data model supports it; consumption is post-MVP)

## Specs

| Spec file | Description |
|---|---|
| [`spec.md`](spec.md) | Ingest architecture, signal categories, data model, query API, PII rules, acceptance criteria |

## Open Questions

| Question | Answer | Date |
|---|---|---|
| Should `node_id` be a first-class indexed column on `analytics_events` or live inside `properties` jsonb? | Indexed column — join performance matters for agent diagnosis use case | 2026-04-01 |
| Container metrics: push from sidecar or pull via Prometheus scrape? | Push via `POST /capture` for Phase 0 — consistent with ingest architecture | 2026-04-01 |
| What is the retention policy for raw events? | Unresolved — define before Phase 1 | |
| statsd exporter: emit from Rails or from a separate job? | Unresolved — post-MVP concern | |
