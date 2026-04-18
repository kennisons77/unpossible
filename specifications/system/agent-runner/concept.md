# Agent Runner

## What It Does

Assembles instructions into provider prompts, executes them via direct HTTP to the
provider API, manages multi-turn conversations with human input pauses, records results,
and deduplicates repeated calls.

## AgentRun Record

```
AgentRun
  run_id               UUID
  source_ref           string, nullable — spec path or plan item ref (e.g. "specifications/system/agent-runner/concept.md")
  parent_run_id        nullable — set when this is a subagent run
  mode                 plan | build | review | reflect | research
  provider             string — provider name at time of run
  model                string — model name at time of run
  prompt_sha256        SHA256 of assembled prompt
  status               running | waiting_for_input | completed | failed
  input_tokens
  output_tokens
  cost_estimate_usd
  duration_ms
  response_truncated   boolean
  source_node_ids      spec paths or plan item refs retrieved for context
```

## AgentRunTurn Record

Each turn in a run's conversation history:

```
AgentRunTurn
  id
  run_id          FK → AgentRun
  position        integer — ordering
  kind            agent_question | human_input | llm_response | tool_result
  content         text
  purged_at       nullable — set when content is GC'd, null means content is live
  created_at
```

`purged_at` is set by the background GC job. Once set, `content` is cleared. The turn
record itself is retained for audit — only the content is removed.

## Skill Frontmatter — Tool Declaration

Skills declare two tool categories in frontmatter:

```yaml
tools:
  enrich:
    - git_diff        # runs before LLM call, result appended as tool_result turn
  callable:
    - read_file       # passed to provider as available tools, LLM decides when to call
```

`enrich` tools run unconditionally before the first LLM call. Their results are appended
as `tool_result` turns and the LLM sees them as already-resolved context.

`callable` tools are passed to the provider in the `tools` array. The LLM invokes them
mid-run; results are appended as `tool_result` turns and the run continues.

### Agent Override Flag

`AgentRun` accepts an `agent_override: boolean` flag. When true:
- Enrichment tools are skipped — no pre-population of context
- Callable tools are still passed to the provider
- The agent handles everything from raw context

This is the baseline for tool effectiveness comparison. See `specifications/practices/verification.md`
for how to use this flag in benchmark test cases.

## Assembly Pipeline

1. Load instruction body (skill file)
2. Retrieve context from `specifications/practices/` files declared in skill frontmatter
3. Load principles files declared in skill frontmatter
4. Unless `agent_override: true`, run enrichment tools and append results as `tool_result` turns
5. Wrap with agent config `prompt_template` (falls back to `PROMPT_{mode}.md`)
6. Compute `prompt_sha256`
7. Check dedup — if recent successful run with same hash exists, return it
8. Call provider HTTP API with callable tools passed in `tools` array

## Pause / Resume

When the agent needs human input:

1. Runner writes an `agent_question` turn with the question content
2. Sets `AgentRun.status = waiting_for_input`
3. Job completes — no thread held

To resume:

1. Human POSTs to `POST /runs/:id/input` with `{ content: "..." }`
2. A `human_input` turn is appended
3. Run is re-enqueued via solid_queue
4. Job resumes: reconstructs turn history, injects human input as user message, calls provider

Multiple pause/resume cycles are supported. Runs stay suspended indefinitely until answered.

## Context Window Management

Turn history is passed to `build_prompt` with a token budget. The adapter is responsible
for fitting within it using the **pinned + sliding** strategy:

- Always include: system prompt, all `agent_question` and `human_input` turns
- Trim from oldest first: `llm_response` and `tool_result` turns
- If still over budget after trimming all non-pinned turns, abort with `RALPH_WAITING`

This preserves the human conversation thread even as intermediate LLM content is dropped.
See `specifications/practices/coding.md` for the rationale behind this decision.

## Prompt Deduplication

Before calling the provider: look up `prompt_sha256` + `mode` in recent AgentRuns.
If a successful run exists within the max age (default 24h), return it — no provider call.
Ignores failed runs.

## Turn Content GC

A background job (solid_queue recurring) purges turn content for completed runs older
than N days (default: 30). It sets `purged_at = now()` and clears `content`. The run
record and turn skeleton are retained permanently for audit.

Failed and `waiting_for_input` runs are never purged — content may still be needed.

## Provider Adapter Interface

Each provider implements:
- `build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)` — assembles
  in provider's native format, applying pinned+sliding trimming to fit within token_budget
- `parse_response(raw_output:)` — normalises to `{text:, input_tokens:, output_tokens:, stop_reason:}`
- `max_context_tokens` — integer

Adding a provider = implementing this interface. No orchestration changes.

## Session Discipline

Each job execution is a fresh context window reconstructed from turns. Never persist
in-memory session state across job executions.

## Concurrency

One active run per agent config at a time, enforced via solid_queue concurrency key on `source_ref`.
A concurrent run request while a run is active returns 409.

## Observability

`AgentRun` records provide the audit trail: tokens, cost, duration, status, source refs.

## Acceptance Criteria

- Start creates an AgentRun with status `running` and enqueues the job
- Concurrent run request for same agent config while a run is active → 409
- Dedup hit returns cached run — no provider call made
- Complete updates the record with provider results and status `completed`
- Duplicate (run_id) → 422
- `parent_run_id` links subagent runs to parent
- `source_node_ids` stored and retrievable
- Prompt exceeding token limit aborts with `RALPH_WAITING` before any provider call
- Agent question appends `agent_question` turn and sets status `waiting_for_input`
- `POST /runs/:id/input` appends `human_input` turn and re-enqueues the job
- Resumed job reconstructs full turn history and injects human input as user message
- Multiple pause/resume cycles work correctly
- GC job sets `purged_at` and clears content on completed runs older than N days
- GC job never purges failed or waiting_for_input runs
- Enrichment tools run before first LLM call and results appear as `tool_result` turns
- Callable tools are passed to the provider in the `tools` array
- `agent_override: true` skips enrichment tools; callable tools still passed
- Adding a provider requires only a new adapter — no orchestration changes
- Unauthenticated requests return 401

See [`requirements.md`](requirements.md) for intent and scenarios.
