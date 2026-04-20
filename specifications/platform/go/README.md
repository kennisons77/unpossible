# Go Platform — Unpossible

Go implementation overrides. Each file extends a core spec and adds only Go-specific details.

All Go code lives under `go/` with a single `go.mod`. Binaries are separated by `cmd/` subdirectory:

```
go/
├── go.mod
├── go.sum
├── cmd/
│   ├── runner/       # Agent loop runner sidecar (port 8080)
│   ├── analytics/    # Analytics ingest sidecar (port 9100)
│   ├── parser/       # Reference-graph parser (CLI, no server)
│   └── linter/       # Custom linter (CLI, no server) — future
└── internal/         # Shared packages (PII filtering, Postgres client, etc.)
```

Sidecars (runner, analytics) run as long-lived HTTP servers alongside Rails.
CLI tools (parser, linter) run on demand with no server component.

One `infra/Dockerfile.go` builds all binaries via multi-stage build.

## Directories

- `system/` — overrides for `specifications/system/` specs
