---
name: claude
kind: provider
description: Best practices for Claude (Anthropic) as an actor
---

## Prompt Caching

Apply `cache_control: {type: "ephemeral", ttl: "1h"}` to stable blocks loaded every
iteration: principles files, prd.md, tool definitions >500 tokens.

Do NOT cache: beat description, retrieved knowledge chunks — these change per iteration.

## Token Limits

Abort with `RALPH_WAITING` if assembled prompt would exceed 150K tokens. Never let the
model truncate silently.

## Compaction

Never enable compaction in build/plan/review/research modes. A compacted context loses
the reasoning trail the next iteration depends on.

## Effort Level

| Task type | Effort |
|---|---|
| Reads, classification | `low` |
| Standard build | `medium` |
| Default | `high` |
| Debugging, architecture | `max` (Opus only) |
