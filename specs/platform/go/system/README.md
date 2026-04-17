# Go System Overrides — Unpossible

Go-specific implementation details for system-level specs. Each file extends the corresponding `specs/system/` spec.

| Override | Extends | Type |
|---|---|---|
| [runner.md](runner.md) | specs/system/agent-runner/spec.md | Sidecar (HTTP server) |
| [analytics.md](analytics.md) | specs/system/analytics/spec.md | Sidecar (HTTP server) |

The reference-graph parser (`go/cmd/parser/`) is specified in `specs/system/reference-graph/spec.md` § Go Reference Parser. It is a CLI tool, not a sidecar.
