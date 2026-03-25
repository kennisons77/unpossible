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

## Codebase Patterns

- Go 1.22, stdlib HTTP server
- Application code in `./dashboard/src/`
- Entry point: `cmd/server/main.go`
- Tests alongside source: `*_test.go`
- Multi-stage Dockerfile: builder (golang:1.22-alpine) → runtime (alpine:3.19)
