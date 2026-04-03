# Analytics Product — Rails Platform Override

Extends `specs/system/analytics/spec.md`. Rails-specific implementation only.

## Models
- `Analytics::FeatureFlag` — `enabled?` fires `$feature_flag_called` automatically; archived flags return false without raising
- `Analytics::FeatureFlagExposure`

## Controller
- `Analytics::MetricsController` additions — JWT auth required
  - `GET /api/analytics/events`
  - `GET /api/analytics/flags/:key`

## Schema Details
- `feature_flags.key` — unique per org
- `feature_flags.metadata` — `hypothesis` field required on creation → 422 if missing
- `feature_flag_exposures` — index on `(org_id, flag_key, distinct_id)`

## Rails-specific Acceptance Criteria
- `FeatureFlag` with missing `metadata.hypothesis` → 422
- Archived `FeatureFlag` returns false from `enabled?` without raising
- `distinct_id` in API responses is UUID, never email
