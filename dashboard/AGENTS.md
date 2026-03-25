# AGENTS.md — dashboard

Operational reference for building, running, and testing this project.

## Build

```bash
docker compose -f ./dashboard/infra/docker-compose.yml build
```

## Run

```bash
docker compose -f ./dashboard/infra/docker-compose.yml up dashboard
```

Server listens on `http://localhost:8080`.

## Test

```bash
docker compose -f ./dashboard/infra/docker-compose.yml run --rm test
```

## Endpoints

- `GET /` — HTML frontend
- `GET /healthz` — liveness probe
- `GET /ready` — readiness probe
- `GET /api/plan` — IMPLEMENTATION_PLAN.md as JSON
- `GET /api/worklog` — WORKLOG.md as JSON
- `GET /api/specs` — list of spec files
- `GET /api/specs/{name}` — individual spec content
- `POST /run` — trigger loop.sh (requires Basic Auth)
- `GET /metrics` — Prometheus metrics

## Environment Variables

- `WORKSPACE_DIR` — path to unpossible repo (default: /workspace)
- `LOOP_SCRIPT` — path to loop.sh (default: $WORKSPACE_DIR/loop.sh)
- `RUN_AUTH_USER` — Basic Auth username for /run endpoint
- `RUN_AUTH_PASS` — Basic Auth password for /run endpoint

## Codebase Patterns

- Go 1.22, stdlib HTTP server
- Application code in `./dashboard/src/`
- Entry point: `cmd/server/main.go`
- Tests alongside source: `*_test.go`
- Multi-stage Dockerfile: builder (golang:1.22-alpine) → runtime (alpine:3.19)
- Packages: parser (markdown parsing), runner (loop execution), metrics (Prometheus), web (embedded static files)
