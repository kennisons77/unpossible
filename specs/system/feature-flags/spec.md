# Feature Flags

## What It Does

Gates hypothesis-driven features behind a runtime switch. Code ships with the behaviour
off by default. The flag is enabled for a subset, the hypothesis is measured, and the
flag is either removed (behaviour becomes default) or the code is removed (hypothesis
rejected).

## Why It Exists

Separates deployment from release. A beat can be marked complete and merged without
exposing the behaviour to users — the flag controls visibility independently of the
deploy.

## Schema

```
FeatureFlag
  key         string, unique per org — format: {module}.{feature}
  enabled     boolean, default false
  variant     string, nullable (for A/B)
  metadata    jsonb
    hypothesis  string, required — the claim being tested
    metric      string — how success is measured
    owner       string — who is responsible
  status      active | archived
  org_id
```

`metadata.hypothesis` is optional in Phase 0. Required when experiment infrastructure is added (post-MVP).

## Lifecycle

```
active → archived
```

- `active` — flag is evaluated; `enabled` controls the behaviour
- `archived` — experiment concluded; `FeatureFlag.enabled?` returns `false` without
  raising; excluded from UI by default

Flags are never deleted — the archived record is the experiment history.

## Usage Pattern

```ruby
if FeatureFlag.enabled?(org_id:, key: 'module.feature')
  # new behaviour
end
```

## Naming Convention

`{module}.{feature}` — e.g. `knowledge.vector_search`, `analytics.cost_alerts`.
Namespaced to prevent collisions.

## Acceptance Criteria

- `FeatureFlag.enabled?` returns `false` for unknown or archived flags without raising
- Flag key is unique per org — duplicate key returns 422
- Archived flags excluded from UI flag list by default, accessible via filter
