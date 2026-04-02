# Agent Runner

## What It Does

Assembles instructions into provider prompts, executes them via the Go sidecar, records
results, and deduplicates repeated calls.

## AgentRun Record

```
AgentRun
  run_id               UUID
  actor_id             FK → Actor (ledger)
  node_id              FK → Node being answered
  parent_run_id        nullable — set when this is a subagent run
  mode                 plan | build | review | reflect | research
  provider             from ActorProfile at time of run
  model                from ActorProfile at time of run
  prompt_sha256        SHA256 of assembled prompt
  input_tokens
  output_tokens
  cost_estimate_usd
  exit_code
  duration_ms
  response_truncated   boolean
  source_node_ids      ledger nodes retrieved for context
```

## Assembly Pipeline

1. Load instruction body (skill file)
2. Retrieve context chunks from knowledge base scoped to the node
3. Load principles files declared in skill frontmatter
4. Wrap with ActorProfile `prompt_template` (falls back to `PROMPT_{mode}.md`)
5. Compute `prompt_sha256`
6. Check dedup — if recent successful run with same hash exists, return it
7. Call sidecar

## Prompt Deduplication

Before calling the sidecar: look up `prompt_sha256` + `mode` in recent AgentRuns.
If a successful run exists within the max age (default 24h), return it — no sidecar call.
Ignores failed runs.

## Provider Adapter Interface

Each provider implements:
- `build_prompt(node:, context_chunks:, principles:)` — assembles in provider's native format
- `parse_response(raw_output:)` — normalises to `{text:, input_tokens:, output_tokens:, stop_reason:}`
- `cache_config` — provider-specific cache settings
- `max_context_tokens` — integer

Adding a provider = implementing this interface. No orchestration changes.

## Session Discipline

Each iteration is a fresh context window. Never persist sessions across iterations.
Load only what the current beat needs, complete it, discard.

## Concurrency

One loop at a time. A concurrent run request while a run is active returns 409. The
sidecar enforces this — the app server does not need to coordinate.

## Deployment

Separate process in the same network namespace as the application server. Receives
calls from the app at localhost, calls back to the app at localhost.

## Observability

Exposes Prometheus-compatible metrics at `/metrics`:
- Run counter (total, failed)
- Run duration histogram
- Current active runs gauge

`/healthz` returns 200 when the sidecar is ready to accept runs.

## Acceptance Criteria

- Start creates an AgentRun and calls the sidecar
- Concurrent run request while a run is active → 409
- Dedup hit returns cached run — no sidecar call made
- Complete updates the record with sidecar results
- Duplicate (run_id + iteration) → 422
- `parent_run_id` links subagent runs to parent
- `source_node_ids` stored and retrievable
- Prompt exceeding token limit aborts with `RALPH_WAITING` before any provider call
- Compaction never enabled in build/plan/review/research modes
- Adding a provider requires only a new adapter — no orchestration changes
- `/healthz` returns 200
- `/metrics` returns valid Prometheus text
- Unauthenticated requests return 401

See [`prd.md`](prd.md) for intent and scenarios.
