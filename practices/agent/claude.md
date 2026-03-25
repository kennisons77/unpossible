# Claude Agent Practices

Invoked via `claude -p --dangerously-skip-permissions --output-format=stream-json --model <MODEL>`.

## Models

| Model | Input $/1M | Output $/1M | Context | Notes |
|---|---|---|---|---|
| claude-haiku-4-5 | $1.00 | $5.00 | 200K | Fastest, cheapest; limited reasoning depth |
| claude-sonnet-4-5 | $3.00 | $15.00 | 200K | Best cost/quality balance for most tasks |
| claude-opus-4-5 | $15.00 | $75.00 | 200K | Strongest reasoning; reserve for hard problems |

> Prices are approximate. Verify current rates at https://www.anthropic.com/pricing.

## Task → Model Assignment

| Task type | Recommended model | Rationale |
|---|---|---|
| File read / search / grep | haiku-4-5 | No reasoning needed; pure retrieval |
| Boilerplate / scaffolding | haiku-4-5 | Mechanical generation |
| Code generation / editing | sonnet-4-5 | Reliable output quality at reasonable cost |
| Test writing | sonnet-4-5 | Needs context awareness, not deep reasoning |
| Planning / gap analysis | sonnet-4-5 | Good enough for structured spec work |
| Debugging / root cause | opus-4-5 | Needs multi-step reasoning across large context |
| Architecture decisions | opus-4-5 | High-stakes; worth the cost |

**Rule:** Start with sonnet. Drop to haiku for pure reads. Escalate to opus only when sonnet stalls or produces wrong output after one retry.

## Caveats

- `--dangerously-skip-permissions` auto-approves all tool calls — run in a branch or sandbox, never on main with production credentials present.
- `--output-format=stream-json` produces structured output suitable for log parsing but is verbose; pipe through `jq` or redirect to a file if you need to inspect it.
- Claude has no persistent memory between loop iterations — `IMPLEMENTATION_PLAN.md` and `specs/activity.md` are its only state.
- Context window fills fast with large `specs/` or `practices/` directories. Keep files lean; see `practices/general/cost.md` for caching strategies.
- Opus is ~5× the cost of sonnet per token. A single runaway opus iteration can cost more than an entire sonnet build loop.

## Prompt Caching

Add `cache_control: {type: "ephemeral", ttl: "1h"}` to stable blocks (practices files, prd.md) to reduce repeat costs by ~90%. See `practices/general/cost.md` for full guidance.
