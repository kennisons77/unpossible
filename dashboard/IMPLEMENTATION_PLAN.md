# Implementation Plan — dashboard

## Phase 1: Read-only API + UI

- [x] Scaffold Go module (`projects/dashboard/src/`) with `cmd/server/main.go`
- [x] Implement `/healthz` and `/ready` endpoints
- [x] Parse `IMPLEMENTATION_PLAN.md` → `GET /api/plan` (JSON: tasks with done/pending status)
- [ ] Parse `WORKLOG.md` → `GET /api/worklog` (JSON: entries)
- [ ] List and serve `specs/*.md` → `GET /api/specs`, `GET /api/specs/{name}`
- [ ] Serve static HTML frontend (embedded via `embed.FS`) showing plan + worklog
- [ ] `POST /run` endpoint — executes `loop.sh` via `exec.CommandContext`, protected by Basic Auth
- [ ] Prometheus metrics: `runs_total`, `runs_failed_total`, `run_duration_seconds`
- [ ] Structured JSON logging (stdlib `log/slog`)
- [ ] Multi-stage Dockerfile builds and `go test ./...` passes in container
