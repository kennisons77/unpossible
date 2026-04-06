# Module LOOKUP

Maps all five modules to their paths and public interfaces.
Cross-module calls go through public service interfaces only — no direct model access across boundaries.

## Modules

### knowledge
- Path: `app/modules/knowledge/`
- Purpose: Vector store, MD indexing, context retrieval
- Public interface: `Knowledge::IndexerJob`, `Knowledge::RetrievalService`

### tasks
- Path: `app/modules/tasks/`
- Purpose: Task lifecycle management (plan items, acceptance criteria)
- Public interface: `Tasks::TaskLifecycleService`

### agents
- Path: `app/modules/agents/`
- Purpose: Agent run storage, prompt dedup, JWT auth
- Public interface: `Agents::RunStorageService`

### sandbox
- Path: `app/modules/sandbox/`
- Purpose: Container lifecycle, Docker dispatcher
- Public interface: `Sandbox::ContainerDispatchService`

### analytics
- Path: `app/modules/analytics/`
- Purpose: LLM metrics, audit log, feature flags
- Public interface: `Analytics::AuditLogService`, `Analytics::FeatureFlagService`

## Cross-Module Rules

- Never access another module's models directly — call its public service interface
- Never require another module's internal files — use the public interface only
- Shared value objects (e.g. `Secret`) live in `app/lib/`, not in any module
