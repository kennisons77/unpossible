# Agent Call Management

General practices for controlling cost and context across any agent in the loop.
For model selection and per-agent pricing, see `practices/agent/claude.md` or `practices/agent/kiro.md`.

## Model Selection

Use the cheapest model that can complete the task without stalling. Escalate only after a failure.

| Task type | Tier |
|---|---|
| File read / search / grep | cheapest |
| Boilerplate / scaffolding | cheapest |
| Code generation / editing | mid |
| Test writing / planning | mid |
| Debugging / architecture | top |

See the relevant agent file for exact model names and costs.

## Subagent Caps

Each subagent is a separate call with its own context window — costs multiply.

- Reading/searching: ≤3 cheap subagents, ≤5 turns each
- Code generation: 1 mid subagent, ≤20 turns
- Build/test: 1 mid subagent (don't parallelise around failures)
- Reasoning: 1 top subagent, only when mid has already failed

**Kill signal:** If a subagent exceeds 10 turns on a simple read task, it is stuck. Terminate it, log the failure in `specs/activity.md`, and use a simpler approach next iteration.

## Prompt Caching (Claude only)

Repeated context is the largest cost driver. Add `cache_control: {type: "ephemeral", ttl: "1h"}` to stable blocks — cached tokens cost ~10% of normal rate.

Cache: `specs/prd.md`, `practices/*.md` files, large repeated schema blocks.
Don't cache: the current task, `specs/plan.md` (changes each iteration), blocks under ~500 tokens.

## Context Hygiene

- `specs/activity.md` grows unboundedly and loads every iteration — trim to the last 10 entries after each iteration. Prepend a single summary line: `[Prior entries summarised: N iterations, key outcomes: ...]`
- Keep `specs/` and `practices/` files lean — every byte loads into every iteration
- If context approaches the window limit, regenerate `IMPLEMENTATION_PLAN.md` rather than letting the agent work with a truncated view

## Batching (Claude only)

For non-interactive work (bulk classification, fixture generation, offline analysis), the Batches API costs 50% of standard rates. Not suitable for the real-time build loop.
