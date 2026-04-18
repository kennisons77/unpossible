# Analytics — Go Platform Override

Extends `specifications/analytics.md`. Go sidecar implementation only.

## Responsibilities
The sidecar owns ingest only — capture, queue, and flush to Postgres. No query endpoints. No business logic.

## Endpoints
- `POST /capture` — accepts single event or batch array, returns 202 immediately, no auth (internal network only)
- `GET /healthz` — liveness check

## Ingest Behaviour
- In-memory event queue
- Batch flush to Postgres `analytics_events` every 5 seconds or 100 events, whichever comes first
- Buffers in memory if Postgres is temporarily unavailable — no events dropped on brief outage
- `properties` jsonb filtered through gitleaks/PII patterns before storage
- `distinct_id` validated as UUID format before storage — non-UUID rejected

## Port
9100

## Files
- `go/cmd/analytics/main.go`
- `go/go.mod`
- `go/go.sum`

## Go-specific Acceptance Criteria
- `go test ./...` exits 0
- `POST /capture` returns 202 immediately
- Events flushed within 5s or 100 events
- Events buffered on Postgres unavailability
- `GET /healthz` returns 200
- Non-UUID `distinct_id` rejected before storage
