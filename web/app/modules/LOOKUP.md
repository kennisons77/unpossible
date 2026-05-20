# Module LOOKUP

Maps all active modules to their paths and public interfaces.
Cross-module calls go through public service interfaces only — no direct model access across boundaries.

## Modules

### agents
- Path: `app/modules/agents/`
- Purpose: Agent run storage, prompt dedup, JWT auth
- Public interface: `Agents::RunStorageService`

### sandbox
- Path: `app/modules/sandbox/`
- Purpose: Container lifecycle, Docker dispatcher
- Public interface: `Sandbox::DockerDispatcher`

### analytics
- Path: `app/modules/analytics/`
- Purpose: LLM metrics, audit log, feature flags
- Public interface: `Analytics::AuditLogger`, `Analytics::FeatureFlag`

### reference_graph
- Path: `app/modules/reference_graph/`
- Purpose: Read-only web UI over the Go reference parser JSON graph
- Public interface: `ReferenceGraph::ParserService`

## Cross-Module Rules

- Never access another module's models directly — call its public service interface
- Never require another module's internal files — use the public interface only
- Shared value objects (e.g. `Secret`) live in `web/lib/`, not in any module
