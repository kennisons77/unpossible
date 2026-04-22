# Go Sidecar Architecture

## Research Pass — 2026-04-22

### Interview Findings

The spike had three open questions. Answers derived from the Go platform specs
(`specifications/platform/go/`), the infrastructure concept spec, the analytics
requirements spec, and the runner concept spec.

---

**Q1: Should the analytics ingest sidecar be built before the runner sidecar?**

Yes. Build analytics first, then runner.

Rationale:

- The analytics sidecar (`go/cmd/analytics/`) has no dependencies on the runner or on
  any Rails internals beyond the `analytics_events` Postgres table (already exists).
  It is a standalone HTTP server with a fixed schema.
- The runner sidecar (`go/cmd/runner/`) calls back to Rails (`POST /api/agent_runs/:id/complete`)
  and executes `loop.sh`. It has more moving parts and requires the Go bootstrap to be
  stable before adding that complexity.
- The analytics sidecar is simpler: one endpoint (`POST /capture`), one background
  goroutine (flush loop), one Postgres table. It is the right first target for
  establishing Go build patterns, test patterns, and the `infra/Dockerfile.go`
  multi-stage build.
- Once the analytics sidecar is working, the runner sidecar reuses the same build
  infrastructure, Postgres client, and test patterns.

**Build order:** 8.2 (bootstrap) → 8.3 (analytics) → 8.4 (Dockerfile.go) → 8.5
(uncomment compose) → 8.6 (runner).

---

**Q2: What is the minimal viable runner sidecar for Phase 0?**

The runner spec (`specifications/platform/go/system/runner.md`) defines the full
interface. For Phase 0 the minimal viable implementation is:

- `POST /run` — Basic Auth, executes `loop.sh` via `exec.CommandContext`, mutex
  enforces one run at a time (concurrent → 409), calls Rails complete endpoint after
  exit.
- `GET /healthz` — returns 200.
- `GET /ready` — returns 200 when not running, 503 when a run is active.
- `GET /metrics` — Prometheus text format. Four metrics: `runs_total`,
  `runs_failed_total`, `run_duration_seconds`, `current_runs`.

Token parsing (Claude `--output-format=stream-json` stdout) is required by the spec
and must be included — it feeds `input_tokens`/`output_tokens` into the Rails complete
callback. Without it the AgentRun record has no token data.

The Prometheus metrics endpoint requires `prometheus/client_golang`. This is the only
external dependency for the runner. It is well-maintained and the spec names it
explicitly — no alternative needed.

**Minimal viable = full spec.** The runner spec is already scoped to Phase 0. No
further reduction is appropriate.

---

**Q3: How to structure go.mod for a monorepo with multiple binaries?**

Single `go.mod` at `go/go.mod` with module path `github.com/unpossible/unpossible`.
All binaries under `go/cmd/{name}/main.go`. Shared packages under `go/internal/`.

```
go/
├── go.mod                    # module github.com/unpossible/unpossible, go 1.22
├── go.sum
├── cmd/
│   ├── analytics/main.go     # analytics ingest sidecar
│   ├── runner/main.go        # loop runner sidecar
│   └── parser/main.go        # reference-graph parser CLI (task 5.1)
└── internal/
    ├── pgclient/             # shared Postgres connection + retry logic
    └── piifilter/            # PII/secret pattern redaction (analytics + parser)
```

This is the standard Go monorepo pattern for a project with multiple binaries. One
`go.mod` means one `go build ./...` builds everything, one `go test ./...` tests
everything, and one `infra/Dockerfile.go` multi-stage build produces all binaries.

The `internal/` packages enforce the Go visibility rule: code under `internal/` is
importable only by code rooted at `go/`. This prevents accidental cross-binary coupling
while sharing the Postgres client and PII filter.

**Shared packages to create at bootstrap (task 8.2):**

- `go/internal/pgclient/` — wraps `database/sql` + `lib/pq` driver, connection pool,
  retry on transient errors. Used by analytics flush loop and (later) parser.
- `go/internal/piifilter/` — regex-based redaction of secrets and PII patterns from
  `properties` jsonb before storage. Used by analytics sidecar.

Both packages are stdlib-plus-one-driver (`lib/pq` for Postgres). No ORM. No
framework. The analytics sidecar and parser are the only consumers in Phase 0.

---

### Build Order Summary

```
8.2  Bootstrap go/ — go.mod, cmd stubs, internal/pgclient, internal/piifilter
       go build ./... exits 0
       go test ./... exits 0

8.3  Analytics ingest sidecar — POST /capture, flush loop, GET /healthz
       Depends on: 8.2

8.4  infra/Dockerfile.go — multi-stage, one stage per binary target
       Depends on: 8.2

8.5  Uncomment Go sidecar services in docker-compose.yml
       Depends on: 8.3, 8.4

8.6  Runner sidecar — POST /run, GET /healthz, GET /ready, GET /metrics
       Depends on: 8.2
       External dep: prometheus/client_golang (pinned version)
```

---

### External Dependencies

| Package | Used by | Reason |
|---|---|---|
| `lib/pq` | pgclient | Postgres driver — stdlib `database/sql` requires a driver |
| `prometheus/client_golang` | runner | Metrics endpoint — spec names it explicitly |

Both are well-maintained. `lib/pq` is the standard pure-Go Postgres driver. No other
external dependencies are needed for Phase 0 Go code.

The analytics sidecar uses only stdlib + `lib/pq`. The runner uses stdlib + `lib/pq`
+ `prometheus/client_golang`. The parser uses only stdlib + `lib/pq`.

---

### Dockerfile.go Multi-Stage Pattern

```dockerfile
# infra/Dockerfile.go
FROM golang:1.22-alpine AS builder
WORKDIR /go/src
COPY go/ .
RUN go build -o /out/analytics ./cmd/analytics
RUN go build -o /out/runner ./cmd/runner

FROM alpine:3.19 AS analytics
COPY --from=builder /out/analytics /analytics
ENTRYPOINT ["/analytics"]

FROM alpine:3.19 AS runner
COPY --from=builder /out/runner /runner
ENTRYPOINT ["/runner"]
```

`docker compose` targets the named stage via `target: analytics` or `target: runner`.
The builder stage compiles both binaries in one layer — no redundant downloads.

---

### Acceptance Criteria for 8.1

This spike is complete when `specifications/research/go-sidecars.md` exists with
answers to all three open questions. No code is written in this task.
