---
name: claude
kind: provider
description: Best practices for Claude (Anthropic) as an actor
---

## Model Pricing (as of 2026)

| Model      | Input $/1M | Output $/1M | Best for                          |
|------------|------------|-------------|-----------------------------------|
| Haiku 4.5  | $1.00      | $5.00       | Reading, searching, classification |
| Sonnet 4.6 | $3.00      | $15.00      | Code generation, editing, tests    |
| Opus 4.6   | $5.00      | $25.00      | Debugging, architecture, reasoning |

## Prompt Caching

Apply `cache_control: {type: "ephemeral", ttl: "1h"}` to stable blocks loaded every
iteration: practices files, requirements.md, tool definitions >500 tokens.

Do NOT cache: beat description, per-iteration context (current task, retrieved file content) — these change per iteration.

Cached input tokens cost ~10% of normal input rate. Cache TTL defaults to 5 minutes —
always set `ttl: "1h"` for context shared across loop iterations.

## Token Limits

Abort with `RALPH_WAITING` if assembled prompt would exceed 150K tokens. Never let the
model truncate silently.

Count tokens before expensive calls:
```python
count = client.messages.count_tokens(model="claude-opus-4-6", messages=messages)
```

## Effort Level

| Task type              | Effort   |
|------------------------|----------|
| Reads, classification  | `low`    |
| Standard build         | `medium` |
| Default                | `high`   |
| Debugging, architecture | `max` (Opus only) |

Combine with adaptive thinking (`thinking: {type: "adaptive"}`) for automatic depth
scaling.

## Compaction

Never enable compaction in build/plan/review/research modes. A compacted context loses
the reasoning trail the next iteration depends on.

For very long debugging sessions approaching the 200K context window:
- Enable with beta header `compact-2026-01-12`
- Append `response.content` (not just text) back to messages — compaction blocks must
  be preserved for the next request to work

## Batches API

For non-interactive work (bulk classification, report generation), the Batches API
charges 50% of standard rates. Up to 100,000 requests or 256 MB per batch. Results
within 24 hours. Not suitable for the real-time build loop.
