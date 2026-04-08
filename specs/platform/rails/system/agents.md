# Agents Module — Rails Platform Override

Extends `specs/system/agent-runner/spec.md`. Rails-specific implementation details only.

## Model
- `Agents::AgentRun` — ActiveRecord, `app/modules/agents/models/agent_run.rb`
- `mode` enum: `plan / build / review / reflect / research`
- Unique index on `(run_id, iteration)`
- `cost_estimate_usd` — decimal(10,6)
- `source_library_item_ids` — jsonb, default `[]`

## Services
- `Agents::PromptDeduplicator` — queries AgentRun for recent successful match on `prompt_sha256` + `mode`
- `Agents::ProviderAdapter` — base class; `ProviderAdapter.for(provider_string)` returns correct adapter
- `Agents::ClaudeAdapter`, `Agents::KiroAdapter`, `Agents::OpenAiAdapter`

## Controller
- `Agents::AgentRunsController`
  - `POST /api/agent_runs/start` — JWT auth
  - `POST /api/agent_runs/:id/complete` — sidecar token auth (`X-Sidecar-Token`)
  - Duplicate (run_id + iteration) → 422

## Kiro Agent Configs
- `kiro-agents/ralph_build.json` — tools: `["read", "write", "shell", "grep", "glob"]`
- `kiro-agents/ralph_plan.json` — tools: `["read", "write", "grep", "glob"]`
- `kiro-agents/ralph_research.json` — tools: `["read", "write", "grep", "glob", "knowledge"]`
- `kiro-agents/ralph_review.json` — tools: `["read", "shell", "grep", "glob"]`

## Files
- `web/app/modules/agents/models/agent_run.rb`
- `web/app/modules/agents/services/prompt_deduplicator.rb`
- `web/app/modules/agents/services/provider_adapter.rb`
- `web/app/modules/agents/services/claude_adapter.rb`
- `web/app/modules/agents/services/kiro_adapter.rb`
- `web/app/modules/agents/services/open_ai_adapter.rb`
- `web/app/modules/agents/controllers/agents/agent_runs_controller.rb`

## Rails-specific Acceptance Criteria
- `ProviderAdapter.for("claude")` returns `ClaudeAdapter`
- `ProviderAdapter.for("kiro")` returns `KiroAdapter`
- `ProviderAdapter.for("openai")` returns `OpenAiAdapter`
- `AgentRun` unique index on `(run_id, iteration)` enforced at DB level
- Complete endpoint triggers `Ledger::SpecWatcherJob` when mode is plan
- Complete endpoint calls `Analytics::AuditLogger`
