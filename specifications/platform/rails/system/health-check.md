---
name: health-check
kind: platform
status: active
platform: rails
extends: practices/coding.md
description: Rack middleware at position 0 — responds before router or auth
modules: []
---

# Health Check Middleware — Rails Platform Override

Extends `specifications/practices/coding.md` § Error Handling (fail-open infrastructure).

## Pattern

Health check is a Rack middleware inserted at position 0 in the middleware stack.
It intercepts `GET /health` and responds before the Rails router, authentication,
or any application middleware runs.

## Why

A health check that runs through the full Rails stack fails when the app is
partially broken — exactly when you most need the health check to report status.
Middleware at position 0 bypasses everything except Rack itself.

## Behavior

- `GET /health` → 200 (database connected) or 503 (database unreachable)
- Response body is empty — load balancers use the status code only
- No authentication, no tenant resolution, no logging
- The only check is a simple DB query (`SELECT 1`) with a short timeout

## Implementation

```ruby
# Inserted at position 0 — runs before all other middleware
app.middleware.insert_before(0, HealthCheckMiddleware)
```

The middleware must not raise. If the DB check fails, return 503 — don't let the
exception propagate.

## What Not to Check

- Search engine availability — degraded, not down
- Background job queue — not user-facing
- External APIs — their health is not your health

If component-level health reporting is needed later (Phase 3), add a separate
`/health/detailed` endpoint behind authentication. The primary `/health` endpoint
stays simple: DB up = 200, DB down = 503.
