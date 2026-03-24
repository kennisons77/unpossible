# Claude Cost Management

Reference for controlling token spend when using Claude in autonomous loops.

## Model Pricing (as of 2026)

| Model | Input $/1M | Output $/1M | Best for |
|---|---|---|---|
| Haiku 4.5 | $1.00 | $5.00 | Reading, searching, classification |
| Sonnet 4.6 | $3.00 | $15.00 | Code generation, editing, tests |
| Opus 4.6 | $5.00 | $25.00 | Debugging, architecture, reasoning |

**Rule of thumb:** Use the cheapest model that can complete the task without stalling. Opus costs 5× Haiku on input and 5× on output — reserve it for tasks where Sonnet has already failed.

## Prompt Caching

Repeated context (system prompts, practices files, specs) is the largest cost driver in loops.

**How it works:**
- Add `cache_control: {type: "ephemeral", ttl: "1h"}` to large content blocks
- Cached input tokens cost ~10% of normal input rate
- Cache TTL defaults to 5 minutes — too short for loop iterations that run every 10–30 minutes
- Always set `ttl: "1h"` for context shared across loop iterations

**What to cache:**
- `specs/prd.md` (rarely changes, loaded every iteration)
- `practices/*.md` files (stable reference material)
- Large tool definitions or schema blocks repeated across turns

**What not to cache:**
- The current task description (changes each iteration)
- `specs/plan.md` (updated after each task — stale cache would confuse the agent)
- Short content blocks under ~500 tokens (caching overhead isn't worth it)

## Subagent Economics

Each subagent is a separate API call with its own context window. Costs multiply.

**Caps that keep costs predictable:**
- Reading/searching: ≤3 Haiku subagents, ≤5 turns each
- Code generation: 1 Sonnet subagent, ≤20 turns
- Build/test: 1 Sonnet subagent (prevents parallelising around failures)
- Reasoning: 1 Opus subagent (only when cheaper models stall)

**Kill signals:** If a subagent exceeds 10 turns on a simple read task, it is stuck. Terminate it, note the failure in activity.md, and use a simpler approach next iteration.

## Batches API

For non-interactive work (bulk classification, report generation, batch analysis), the Batches API charges 50% of standard rates.

- Up to 100,000 requests or 256 MB per batch
- Results available within 24 hours (most complete in 1 hour)
- Use for: generating fixtures, bulk document processing, offline analysis tasks
- Not suitable for: the real-time build loop itself (interactive tasks need synchronous responses)

## Token Counting

Count tokens before expensive calls to catch surprises early:

```python
count = client.messages.count_tokens(model="claude-opus-4-6", messages=messages)
# Abort or truncate if count.input_tokens > your budget threshold
```

Use token counting in CI gates to alert when context grows unexpectedly large.

## Effort Parameter

Control reasoning depth and cost via `output_config: {effort: "low"|"medium"|"high"|"max"}`:

| Level | Use case |
|---|---|
| `low` | Simple reads, classification, boilerplate generation |
| `medium` | Standard code generation |
| `high` | Default — good for most tasks |
| `max` | Opus 4.6 only — hardest debugging and architectural decisions |

Combine with adaptive thinking (`thinking: {type: "adaptive"}`) for automatic depth scaling.

## Compaction

For very long agent sessions that approach the 200K context window:

- Enable with beta header `compact-2026-01-12` and `context_management: {edits: [{type: "compact_20260112"}]}`
- The API summarises earlier context automatically when approaching the trigger threshold
- **Critical:** append `response.content` (not just text) back to messages — compaction blocks must be preserved for the next request to work

Compaction is most valuable for debugging sessions that accumulate many tool call results. For the build loop, keeping `specs/activity.md` trimmed (last 10 entries only) is a cheaper substitute.

## Activity Log Hygiene

`specs/activity.md` grows unboundedly and is loaded every iteration. Keep it short:

- After each iteration, trim to the last 10 entries
- Add a single summary line before the trimmed entries: `[Prior entries summarised: N iterations, key outcomes: ...]`
- This keeps the file under ~2000 tokens regardless of project length
