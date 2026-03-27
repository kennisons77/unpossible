# Agents Module

## What It Does

Owns the full agent lifecycle: spawning loop runs, storing every interaction, managing the producer/reviewer pattern, and providing prompt deduplication. Rails is the authority — the Go sidecar is a thin process executor that reports back to Rails, not an independent agent manager.

## Why Rails Owns This

Agent management requires: task context, cost tracking, deduplication lookups, reviewer orchestration, and audit logging. All of that state lives in Postgres. Putting the management logic in Go would mean duplicating domain knowledge across two runtimes. Rails owns the domain; Go executes the shell process.

## Data Storage

All agent data lives in Postgres. The schema is designed to be graph-aware from day one — explicit relationship columns so traversals like "everything that contributed to this build output" are possible without a schema migration later.

### Graph-aware design

Relationships modelled explicitly:
- `AgentRun.parent_run_id` — subagent spawned by a parent run (self-referential)
- `AgentRun.task_id` — run was executing this task
- `Task.depends_on_ids` (jsonb array) — task dependency graph
- `LibraryItem.parent_id` — research item belongs to a feature context
- `AgentRun.source_library_item_ids` (jsonb array) — which knowledge base items were retrieved for this run's context

This is relational Postgres for Phase 0. When traversal queries become painful in SQL, Apache AGE (the Postgres graph extension, openCypher queries) can be added as a Phase 3 task — the data is already graph-shaped and the migration is additive. Don't add AGE until there are real traversal queries that justify the openCypher overhead.

## Agent Run Record

Per iteration, store:
- `run_id` (uuid), `iteration` (int) — identify the loop run
- `parent_run_id` (FK self-referential, nullable) — set when this is a subagent
- `task_id` (FK, nullable) — task being executed
- `mode` — plan / build / review / reflect / research
- `provider`, `model`
- `prompt_sha256` — SHA256 of assembled prompt (for dedup)
- `input_tokens`, `output_tokens`, `cost_estimate_usd`
- `exit_code`, `duration_ms`, `response_truncated`
- `source_library_item_ids` (jsonb) — knowledge base items retrieved for context

Token counts are parsed from Claude's `--output-format=stream-json` output by the Go sidecar and included in the POST payload. No extra API call needed.

## Loop Execution Flow

1. User or scheduler calls `POST /api/agent_runs/start` with `{mode:, task_id:, iterations:}`
2. Rails creates an `AgentRun` record (status: pending), assembles the prompt, checks dedup
3. Rails calls the Go sidecar `POST /run` with the assembled prompt and config
4. Go sidecar executes `loop.sh`, streams output, parses token counts
5. Go sidecar calls `POST /api/agent_runs/:run_id/complete` with results
6. Rails updates the record, triggers `Tasks::PlanParserJob` if mode was plan, logs to audit

The Go sidecar does not decide what to run or how — it receives instructions from Rails and reports back.

## Prompt Deduplication

Before step 3, Rails checks: does a recent successful AgentRun exist with the same `prompt_sha256` and `mode`? If yes, return the cached run and skip the LLM call. Max age configurable (default 24h). Ignores failed runs.

This implements "don't ask what we already know."

## Provider Adaptation

The agent system adapts its behaviour to the LLM provider being used. The task schema specifies the provider; the agent module selects the appropriate adapter. Adapters are swappable — adding a new provider means implementing the adapter interface, not modifying the orchestration logic.

### Core principle: discard sessions aggressively

Each ralph loop iteration is a fresh context window by design. Sessions are not persisted across iterations. This is intentional:
- Stale context from a previous iteration misleads the agent
- Cache compaction (summarising earlier turns) is expensive and lossy
- A clean context + targeted retrieval from the knowledge base is cheaper and more accurate than a long running session

The goal is to keep every session as short as possible — load only what the current task needs, complete the task, discard the session. Never accumulate context across tasks.

### Provider adapter interface

Each adapter implements:
- `build_prompt(task:, context_chunks:, practices:) → provider_request` — assembles the request in the provider's native format, applying caching annotations where supported
- `parse_response(raw_output:) → {text:, input_tokens:, output_tokens:, stop_reason:}` — normalises provider-specific response shapes
- `cache_config → Hash` — returns provider-specific cache settings (TTL, eligible block types)
- `supports_caching? → Boolean`
- `max_context_tokens → Integer`

### Claude (Anthropic direct API)

**Prompt caching** — Claude supports `cache_control: {type: "ephemeral", ttl: "1h"}` on content blocks. The adapter applies this to:
- Stable blocks loaded every iteration: practices files, `prd.md`, large tool definitions (>500 tokens)
- Does NOT cache: the current task description, `IMPLEMENTATION_PLAN.md` (changes each iteration), retrieved knowledge chunks (vary per task)

Cached input tokens cost ~10% of normal rate. The 1h TTL covers loop iterations that run every 10–30 minutes — the default 5-minute TTL is too short and must always be overridden.

**Session discipline** — Claude's context window is 200K tokens (~176K usable). The adapter tracks estimated token usage and aborts with `RALPH_WAITING` if a prompt would exceed 150K tokens before sending. It never enables compaction (`compact-2026-01-12`) in the build loop — trimming `activity.md` to 10 entries is the cheaper substitute. Compaction is only permitted in long debugging sessions where the alternative is a failed run.

**Effort parameter** — the adapter sets `output_config: {effort:}` based on task type:
- `low` — research reads, classification, file scanning
- `medium` — standard build tasks
- `high` — default
- `max` — Opus only, debugging and architectural decisions

### Kiro (kiro-cli)

Kiro is a credit-based agent runtime, not a raw API. It abstracts the underlying model behind a credit multiplier and exposes a tool allowlist system that maps directly to RESEARCH.md's "task record determines allowed tools" requirement.

**Invocation** — Kiro takes the prompt as a positional argument, not stdin. The runner passes it as `kiro-cli chat --no-interactive --trust-all-tools --model $MODEL -- "$PROMPT"`. The `--` prevents flag interpretation of prompt content.

**Model selection** — Kiro exposes multiple models under a single interface:

| Model | Context | Rate multiplier | Best for |
|---|---|---|---|
| `auto` | 1M tokens | 1.0× | Let Kiro select per task |
| `claude-sonnet-4.5` | 200K | 1.3× | Code generation, build tasks |
| `claude-haiku-4.5` | 200K | 0.4× | Reading, searching, classification |
| `deepseek-3.2` | 164K | 0.25× | Cost-sensitive tasks where quality is sufficient |
| `qwen3-coder-next` | 256K | 0.05× | Experimental — very cheap, use for low-stakes reads |

Use `auto` as the default — Kiro's task-based selection is already aligned with the cost discipline principle. Override with a specific model only when the task type demands it.

**Tool allowlists** — Kiro agent configs (`~/.kiro/agents/{name}.json`) define an explicit `tools` array. This is the native implementation of RESEARCH.md's "task schema specifies the allowed tool set." Create one agent config per loop type:
- `ralph_build.json` — `["read", "write", "shell", "grep", "glob"]`
- `ralph_plan.json` — `["read", "write", "grep", "glob"]` (no shell — plan loop doesn't execute)
- `ralph_research.json` — `["read", "write", "grep", "glob", "knowledge"]`
- `ralph_review.json` — `["read", "shell", "grep", "glob"]` (read + test run, no write)

Invoke with `--agent ralph_build` etc. This enforces tool constraints at the runtime level, not just in the prompt.

**No native prompt caching** — Kiro abstracts caching internally. The adapter does not send `cache_control` annotations. Cost efficiency comes from model selection (use `claude-haiku-4.5` or `deepseek-3.2` for reads) and the `prompt_sha256` dedup check before any call.

**Session handling** — Kiro supports `--resume` to continue a previous session. The adapter never uses `--resume` — each iteration starts a fresh session. Session accumulation is the primary source of context bloat and compaction cost. Discard aggressively.

**`auto` model and context window** — when using `auto`, Kiro reports a 1M token context window. Do not treat this as an invitation to load more context. The 150K token soft cap still applies — the knowledge base retrieval limit and practices file selection are unchanged regardless of the underlying model's capacity.

### OpenAI

**No native prompt caching** — relies on `prompt_sha256` dedup. Uses `response_format: {type: "json_schema"}` for structured-output tasks where Claude uses XML tags.

**Session discipline** — same aggressive discard. Context window varies by model; adapter enforces 75% utilisation cap.

### Local / Ollama (future)

No caching. Smaller context windows — adapter enforces 60% cap and retrieves fewer knowledge chunks. Not suitable for build tasks until a model with ≥32K context is configured.

### Adapter selection

The task schema stores `provider`. Rails selects the adapter at run time:

```ruby
adapter = Agents::ProviderAdapter.for(task.provider)
request = adapter.build_prompt(task: task, context_chunks: chunks, practices: practices)
```

No conditional provider logic outside the adapter. The orchestration layer is provider-agnostic.

## Acceptance Criteria (additions)

- Claude adapter applies `cache_control: {type: "ephemeral", ttl: "1h"}` to practices files and prd.md blocks
- Claude adapter does NOT apply cache_control to task description or IMPLEMENTATION_PLAN.md
- Prompt exceeding 150K tokens aborts with RALPH_WAITING before calling the API — for all providers
- Compaction is never enabled in build/plan/review/research modes
- OpenAI adapter uses `response_format: json_schema` for structured-output tasks
- Kiro adapter never passes `--resume` — each iteration is a fresh session
- Kiro adapter selects agent config by loop type (`ralph_build`, `ralph_plan`, `ralph_research`, `ralph_review`)
- `Agents::ProviderAdapter.for("claude")` returns Claude adapter; `"kiro"` returns Kiro adapter; `"openai"` returns OpenAI adapter
- Adding a new provider requires only a new adapter class — no changes to orchestration logic


Each task can specify `reviewer_provider` and `reviewer_model`. After a build run completes, Rails spawns a second AgentRun (linked via `parent_run_id`) with the reviewer model and a verification prompt. The reviewer result is stored as a separate record. Phase 0: stub — implement in a later iteration.

## Authentication

- **JWT** — user-facing endpoints. `POST /api/auth/token` issues tokens with `org_id`, `user_id`, `exp`.
- **Shared secret** — Go sidecar → Rails internal calls. `X-Sidecar-Token` header. Independent of JWT.

## Acceptance Criteria

- `POST /api/agent_runs/start` creates an AgentRun and calls the Go sidecar
- `POST /api/agent_runs/:id/complete` updates the record with results from the sidecar
- Duplicate (run_id + iteration) returns 422
- Dedup check returns cached run when prompt_sha256 matches within max_age
- Dedup ignores failed runs and runs older than max_age
- `parent_run_id` correctly links subagent runs to their parent
- `source_library_item_ids` is stored and retrievable
- Valid JWT authenticates user-facing endpoints; expired/tampered returns 401
- Sidecar token auth works independently of JWT
