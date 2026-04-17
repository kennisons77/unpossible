# Runner Sidecar — Go Platform Override

Extends `specs/runner.md`. Go implementation details only.

## Invocation
`POST /run` — Basic Auth. Executes `loop.sh` via `exec.CommandContext`. Mutex enforces one run at a time.

## Token Parsing
Parses token counts from Claude's `--output-format=stream-json` stdout.

## Callback
Calls `POST /api/agent_runs/:id/complete` on Rails with results after loop exits.

## Endpoints
- `POST /run` — Basic Auth required
- `GET /healthz`
- `GET /ready`
- `GET /metrics` — Prometheus text format via `prometheus/client_golang`

## Metrics
- `runs_total` counter
- `runs_failed_total` counter
- `run_duration_seconds` histogram
- `current_runs` gauge

## Port
8080

## Files
- `go/cmd/runner/main.go`
- `go/go.mod`
- `go/go.sum`

## Go-specific Acceptance Criteria
- `go test ./...` exits 0
- `POST /run` without Basic Auth → 401
- Concurrent `POST /run` → 409
- Calls Rails complete endpoint after loop exits (mock server test)
- Token counts parsed from stream-json stdout
