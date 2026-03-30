# Agents Module

## What It Does

Owns the full agent lifecycle: spawning loop runs, storing every interaction, managing the producer/reviewer pattern, and providing prompt deduplication. The application server is the authority — the Go sidecar is a thin process executor that reports back, not an independent agent manager.

## Why the App Server Owns This

Agent management requires: task context, cost tracking, deduplication lookups, reviewer orchestration, and audit logging. All of that state lives in the database. Putting management logic in the sidecar would duplicate domain knowledge across two runtimes.

## Data Storage

All agent data is graph-aware from day one — explicit relationship columns so traversals like "everything that contributed to this build output" are possible without a schema migration later:

- `AgentRun.parent_run_id` — subagent spawned by a parent run (self-referential)
- `AgentRun.task_id` — run was executing this task
- `Task.depends_on_ids` — task dependency graph
- `LibraryItem.parent_id` — research item belongs to a feature context
- `AgentRun.source_library_item_ids` — which knowledge items were retrieved for this run's context

## Agent Run Record

Per iteration, store:
- `run_id` (uuid), `iteration` (int)
- `parent_run_id` (nullable) — set when this is a subagent
- `task_id` (nullable)
- `mode` — plan / build / review / reflect / research
- `provider`, `model`
- `prompt_sha256` — SHA256 of assembled prompt (for dedup)
- `input_tokens`, `output_tokens`, `cost_estimate_usd`
- `exit_code`, `duration_ms`, `response_truncated`
- `source_library_item_ids` — knowledge items retrieved for context

## Loop Execution Flow

1. Client calls start endpoint with `{mode:, task_id:, iterations:}`
2. App creates an agent run record, assembles the prompt, checks dedup
3. App calls the Go sidecar with the assembled prompt and config
4. Go sidecar executes `loop.sh`, streams output, parses token counts
5. Go sidecar calls the complete endpoint with results
6. App updates the record, triggers plan parsing if mode was plan, logs to audit

## Prompt Deduplication

Before calling the sidecar, check: does a recent successful run exist with the same `prompt_sha256` and `mode`? If yes, return the cached run and skip the LLM call. Max age configurable (default 24h). Ignores failed runs. Implements "don't ask what we already know."

## Provider Adaptation

The task schema specifies the provider. The agent module selects the appropriate adapter. Adapters are swappable — adding a new provider means implementing the adapter interface, not modifying orchestration logic.

### Session discipline (all providers)

Each loop iteration is a fresh context window by design. Sessions are never persisted across iterations:
- Stale context from a previous iteration misleads the agent
- A clean context + targeted retrieval is cheaper and more accurate than a long running session
- Keep every session as short as possible — load only what the current task needs, complete it, discard the session

### Provider adapter interface

Each adapter implements:
- `build_prompt(task:, context_chunks:, practices:)` — assembles the request in the provider's native format
- `parse_response(raw_output:)` — normalises provider-specific response shapes to `{text:, input_tokens:, output_tokens:, stop_reason:}`
- `cache_config` — provider-specific cache settings
- `supports_caching?` — boolean
- `max_context_tokens` — integer

### Claude (Anthropic)

- Applies `cache_control: {type: "ephemeral", ttl: "1h"}` to stable blocks loaded every iteration: practices files, prd.md, large tool definitions (>500 tokens)
- Does NOT cache: task description, `IMPLEMENTATION_PLAN.md`, retrieved knowledge chunks
- Aborts with `RALPH_WAITING` if prompt would exceed 150K tokens
- Never enables compaction in build/plan/review/research modes
- Sets effort level based on task type: `low` (reads/classification), `medium` (standard build), `high` (default), `max` (debugging/architecture — Opus only)

### Kiro (kiro-cli)

- Invocation: `kiro-cli chat --no-interactive --trust-all-tools --model $MODEL -- "$PROMPT"`
- Never passes `--resume` — each iteration is a fresh session
- Selects agent config by loop type: `ralph_build`, `ralph_plan`, `ralph_research`, `ralph_review`
- Tool allowlists enforced at runtime via agent config, not just in the prompt
- No native prompt caching — cost efficiency via model selection and dedup

### OpenAI

- Uses structured output format for structured-output tasks
- Enforces 75% context window utilisation cap
- No native prompt caching — relies on `prompt_sha256` dedup

### Local / Ollama (future)

- No caching, smaller context windows — enforces 60% cap
- Not suitable for build tasks until a model with ≥32K context is configured

## Acceptance Criteria

- Start endpoint creates an agent run and calls the sidecar
- Start returns cached run on dedup hit — no sidecar call made
- Complete endpoint updates the record with sidecar results
- Duplicate (run_id + iteration) → 422
- `parent_run_id` correctly links subagent runs to their parent
- `source_library_item_ids` stored and retrievable
- Claude adapter applies cache_control to practices and prd.md blocks
- Claude adapter does NOT apply cache_control to task description or IMPLEMENTATION_PLAN.md
- Prompt exceeding token limit aborts with RALPH_WAITING before calling any provider
- Compaction never enabled in build/plan/review/research modes
- Kiro adapter never passes `--resume`
- Kiro adapter selects agent config by loop type
- Adding a new provider requires only a new adapter class — no changes to orchestration logic
- Unauthenticated requests return 401
- Wrong sidecar token returns 401
