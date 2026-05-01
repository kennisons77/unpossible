# Research: Go Analytics Ingest Sidecar

## Research Pass — 2026-05-01

### Interview Findings

Design is fully specified in `specifications/platform/go/system/analytics.md` and
`specifications/system/analytics/concept.md`. No open questions remain. Key decisions
already resolved:

- **Port:** 9100 (internal only, no public exposure)
- **Endpoints:** `POST /capture` (202 immediate), `GET /healthz`
- **Queue:** in-memory, flush every 5s or 100 events (whichever first)
- **Backpressure:** buffer in memory on Postgres unavailability — no drops
- **PII:** `properties` filtered before storage; `distinct_id` must be UUID
- **Auth:** none (internal network only)
- **Single event or batch array** accepted at `/capture`
- **No query endpoints** — sidecar owns ingest only; Rails owns reads

Existing runner (`go/cmd/runner/main.go`) already defines `analyticsEvent` struct and
calls `POST /capture` — the sidecar API contract is already in use.

Vendor directory already contains `github.com/lib/pq` — Postgres driver available
without new dependencies.

### Sources

| Title | URL | Type | Relevance |
|---|---|---|---|
| `specifications/platform/go/system/analytics.md` | local | standard | Full sidecar spec — endpoints, queue, flush, PII, port |
| `specifications/system/analytics/concept.md` | local | standard | Data model, signal categories, ingest architecture |
| `specifications/system/analytics/requirements.md` | local | standard | Functional requirements, success metrics |
| `go/cmd/runner/main.go` | local | library | Existing `analyticsEvent` struct and `/capture` call pattern |

### Edge Cases Found

- **Postgres down at startup:** queue must buffer from first event, not fail fast — use
  retry loop in flush goroutine, not a startup health check
- **Batch vs single event:** `/capture` body can be either `{}` or `[{},{}]` — detect
  by first byte (`[` = array, `{` = single), decode accordingly
- **UUID validation:** reject non-UUID `distinct_id` before enqueue, return 422 with
  error message — do not silently drop
- **Graceful shutdown:** on SIGTERM, flush remaining queue before exit
- **Queue overflow:** spec says "no events dropped on brief outage" — for extended
  outages, cap queue at a reasonable size (e.g. 10,000 events) and log drops rather
  than OOM

### Open Questions Remaining

None — design is fully specified.

### Implementation Notes

The sidecar can be implemented using only stdlib + `github.com/lib/pq` (already
vendored). No new dependencies needed. PII filtering in Phase 0 can be a simple
allowlist of known-safe property keys or a regex scan for email patterns — full
gitleaks integration is post-MVP.
