# Analytics — Product

## What It Does

Captures product events and feature flag exposures. Enables hypothesis-driven development through experiment infrastructure — define a flag, expose users to variants, measure conversion.

## Why Build It

- Experiment infrastructure — feature flags + exposure tracking enable hypothesis-driven development
- Own the data — no third-party analytics service receives it
- Product insight — understand what users actually do

## Signal Categories

### Product events
User actions: page views, button clicks, form submissions, feature flag exposures.
```
event_name: "task.promoted"
properties: { task_id, loop_type, org_id }
distinct_id: <user uuid>
```

### Business logic metrics
Feature flag exposures, task completion rates, research loop outcomes.
```
event_name: "$feature_flag_called"
properties: { flag_key, variant, enabled }
event_name: "task.completed"
properties: { loop_type, duration_ms, reviewer_passed }
```

## Feature Flags

When a feature flag is evaluated, a `$feature_flag_called` event fires automatically — callers don't instrument it manually. Exposure events join with product events on `distinct_id` to compute: "of the users who saw variant A, what % completed the target action?"

Every flag requires a `hypothesis` field on creation — no flag without a measurable outcome.

## Data Model

### analytics_events
```
id            uuid
org_id        uuid
distinct_id   string  — opaque UUID; never an email or name
event_name    string  — namespaced
properties    jsonb   — filtered through PII redaction before storage
timestamp     timestamptz
received_at   timestamptz
```

### feature_flag_exposures
```
id          uuid
org_id      uuid
flag_key    string
variant     string
distinct_id string
timestamp   timestamptz
```
Joins with `analytics_events` on `distinct_id` to compute conversion rates per variant.

## Query API

```
GET /api/analytics/events      — paginated event list, filterable by event_name, org_id, date range
GET /api/analytics/flags/:key  — exposure counts and conversion rates per variant
```

All endpoints require authentication. `distinct_id` in responses is always an opaque UUID.

## PII & Security

- `distinct_id` is always an opaque UUID — never an email address or name
- `properties` filtered through PII redaction before storage
- No analytics data sent to a third party

## Acceptance Criteria

- Feature flag evaluation automatically fires `$feature_flag_called` — no manual instrumentation
- Flag creation without `hypothesis` → rejected
- `distinct_id` in stored events is always a UUID — never an email or name
- `GET /api/analytics/flags/:key` returns exposure counts and conversion rates per variant
