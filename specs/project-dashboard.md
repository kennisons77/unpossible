# Project Dashboard

## [1] Project Dashboard

- **Status:** ready
- **Created:** 2026-03-25T01:17:30Z
- **Promoted:**

### Description

A local web UI and API that parses unpossible's generated markdown (IMPLEMENTATION_PLAN.md, WORKLOG.md, specs/) and exposes project data as browsable collections: goals, UAT/acceptance criteria, and work done. No external services — all data comes from files already on disk. Frontend style similar to GeneAIe. Human-queryable only at first.

**Language decision: Go.** Produces small static binaries, fast startup, strong stdlib for HTTP and exec. Build with `CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags '-s -w'`. Multi-stage Docker image with binary + loop.sh present or mounted.

**Architecture:**
- `cmd/server/main.go` — HTTP server, Prometheus metrics, structured JSON logging, worker that runs `./loop.sh` via `exec.CommandContext`, mutex/lock-file to prevent concurrent runs
- Endpoints: `/healthz`, `/ready`, `/metrics` (Prometheus), `/run` (POST, optional), `/status` (optional)
- Metrics: `runs_total`, `runs_failed_total`, `run_duration_seconds`, `current_runs`, `last_run_success_timestamp`
- Logging: structured JSON to stdout — fields: `run_id`, `iteration`, `command`, `exit_code`, `duration`, `error`
- Config via env vars: path to `loop.sh`, sandbox flags, max concurrency, timeouts, working directory override
- Security: invoke shell scripts via direct `exec` with argument list — no shell interpolation of user input; run with least privileges; containerized for LLM tool calls

### Open Questions

~~- Should the API be read-only or also allow status updates (e.g. marking tasks done via UI)?~~
**Resolved:** Read-only for now; status updates deferred to a later enhancement.

~~- How does the UI handle multiple projects under `projects/`?~~
**Resolved:** Single-project view only for now; multi-project navigation deferred.

~~- Does `/run` need auth (even a simple shared secret) given it executes shell scripts?~~
**Resolved:** Yes — `/run` protected by HTTP Basic Auth; credentials via env vars.

---
