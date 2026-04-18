# Go System Overrides — Unpossible

Go-specific implementation details for system-level specs. Each file extends the corresponding `specifications/system/` spec.

| Override | Extends | Type |
|---|---|---|
| [runner.md](runner.md) | specifications/system/agent-runner/concept.md | Sidecar (HTTP server) |
| [analytics.md](analytics.md) | specifications/system/analytics/concept.md | Sidecar (HTTP server) |

The reference-graph parser (`go/cmd/parser/`) is specified in `specifications/system/reference-graph/concept.md` § Go Reference Parser. It is a CLI tool, not a sidecar.
