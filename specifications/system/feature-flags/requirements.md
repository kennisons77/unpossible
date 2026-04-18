# Requirements: Feature Flags

- **Status:** Draft
- **Created:** 2026-04-01
- **Last revised:** 2026-04-01

## Intent

Feature flags are runtime kill switches. Code ships with new behaviour off by default.
The developer turns it on when ready and off if something goes wrong. Deployment and
release are decoupled — a beat is complete when tests pass, not when the behaviour is
visible.

## Personas

- **Developer:** needs to enable or disable a behaviour at runtime without a deploy.
- **Loop agent:** creates a flag when implementing a beat that introduces new behaviour.
  Ships the beat with the flag disabled.
- **The system:** evaluates flags at call sites without knowing whether the flag exists
  — missing flags return `false` safely.

## User Scenarios

**Scenario 1 — Shipping behind a flag:**
The build loop implements a new analytics cost alert strategy. It creates a flag
`analytics.cost_alerts` (`enabled: false`) and wraps the new code path. The beat
passes tests and is committed. The new behaviour is inert in production.

**Scenario 2 — Enabling a flag:**
The developer is ready to test the new strategy. They call
`PATCH /api/feature_flags/analytics.cost_alerts` with `{ enabled: true }`. The
behaviour is live without a deploy.

**Scenario 3 — Emergency rollback:**
The new behaviour causes errors. The developer sets `enabled: false` via the same
endpoint. The system falls back to the previous path immediately.

**Scenario 4 — Safe evaluation of a missing flag:**
A call site checks a flag that hasn't been created yet. `FeatureFlag.enabled?` returns
`false` without raising — the default behaviour is always safe.

## User Stories

- As the loop agent, I want to create a flag with `enabled: false` so I can ship new
  behaviour without exposing it.
- As a developer, I want to enable or disable a flag via the API so I can control
  behaviour without a deploy.
- As the system, I want flag evaluation to return `false` safely for unknown or archived
  flags so call sites never raise.

## Success Metrics

| Goal | Metric |
|---|---|
| Safe default | `FeatureFlag.enabled?` never raises — unknown flags return `false` |
| Decoupled release | A beat can be marked complete with its flag disabled |
| Fast rollback | A flag can be disabled via one API call with immediate effect |

## Functional Requirements

**MVP:**

- **Boolean flags** — `enabled: true/false`. No variants, no percentage rollout.
- **Flag creation** — `POST /api/feature_flags` with `key` and `org_id`. Key format:
  `{module}.{feature}`. Unique per org — duplicate key returns 422.
- **Flag update** — `PATCH /api/feature_flags/:key` to set `enabled`.
- **Safe evaluation** — `FeatureFlag.enabled?(org_id:, key:)` returns `false` for
  unknown or archived flags without raising.
- **Automatic exposure event** — `$feature_flag_called` fired on every evaluation via
  the analytics ingest sidecar. No manual instrumentation at call sites.
- **No deletion** — flags are never deleted. Archived record is experiment history.
- **`metadata` optional** — `hypothesis`, `metric`, `owner` fields available in
  `metadata` jsonb but not required in Phase 0.

**Post-MVP:**

- Archiving workflow — `active → archived` transition with UI and API support.
- Experiment infrastructure — variants, hypothesis enforcement, conversion measurement
  via analytics joins.
- Percentage rollout — evaluate per `distinct_id` for gradual exposure.
- UI — flag list, enable/disable toggle, archive action.

## Features Out

- Experiment measurement (Phase 0 is kill switch only)
- Variants and A/B testing
- Percentage rollout
- Archiving workflow (schema supports it; no workflow in Phase 0)
- UI (API only in Phase 0)
- `metadata.hypothesis` enforcement (optional, not required)

## Specs

| Spec file | Description |
|---|---|
| [`concept.md`](concept.md) | Schema, lifecycle, evaluation behaviour, naming convention, acceptance criteria |

## Open Questions

| Question | Answer | Date |
|---|---|---|
| Should `metadata.hypothesis` be required when archiving (not on creation)? | Unresolved — revisit when archiving workflow is scoped | |
| Who fires `$feature_flag_called` — feature flags module or analytics? | Feature flags module calls ingest sidecar directly — analytics owns no instrumentation logic | 2026-04-01 |
