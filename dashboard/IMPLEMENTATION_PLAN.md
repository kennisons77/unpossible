# Implementation Plan — dashboard

## Phase 1: Read-only API + UI

- [x] Scaffold Go module (`projects/dashboard/src/`) with `cmd/server/main.go`
- [x] Implement `/healthz` and `/ready` endpoints
- [x] Parse `IMPLEMENTATION_PLAN.md` → `GET /api/plan` (JSON: tasks with done/pending status)
- [x] Parse `WORKLOG.md` → `GET /api/worklog` (JSON: entries)
- [x] List and serve `specs/*.md` → `GET /api/specs`, `GET /api/specs/{name}`
- [x] Serve static HTML frontend (embedded via `embed.FS`) showing plan + worklog
- [x] `POST /run` endpoint — executes `loop.sh` via `exec.CommandContext`, protected by Basic Auth
- [x] Prometheus metrics: `runs_total`, `runs_failed_total`, `run_duration_seconds`
- [x] Structured JSON logging (stdlib `log/slog`)
- [x] Multi-stage Dockerfile builds and `go test ./...` passes in container
