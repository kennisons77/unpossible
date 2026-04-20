---
name: cost
kind: practice
domain: Cost
description: Control token spend — cheapest model that works, subagent caps, cache strategy
loaded_by: [all]
---

# Cost Management

Reference for controlling token spend in autonomous loops. Agent-agnostic principles.
Provider-specific details live in `specifications/skills/providers/{provider}.md`.

## Core Principle

Use the cheapest model that can complete the task without stalling. Escalate only when
a cheaper model has already failed. Never default to the most capable model.

## Subagent Economics

Each subagent is a separate API call with its own context window. Costs multiply.

Caps that keep costs predictable:
- Reading/searching: ≤3 subagents, ≤5 turns each
- Code generation: 1 subagent, ≤20 turns
- Build/test: 1 subagent (prevents parallelising around failures)
- Reasoning: 1 subagent with the most capable model (only when cheaper models stall)

Kill signals: if a subagent exceeds 10 turns on a simple read task, it is stuck.
Terminate it, note the failure in activity.md, and use a simpler approach next iteration.

## Context Loading

Repeated context (system prompts, practices files, specs) is the largest cost driver
in loops. Minimize what's loaded per iteration:

What to keep stable across iterations:
- `specifications/project-requirements.md` (rarely changes)
- `practices/*.md` files (stable reference material)
- Large tool definitions or schema blocks

What changes per iteration (don't cache):
- The current task description
- `IMPLEMENTATION_PLAN.md` (updated after each task)
- Per-iteration retrieved file content

## Activity Log Hygiene

`activity.md` grows unboundedly and is loaded every iteration. Keep it short:

- After each iteration, trim to the last 10 entries
- Add a single summary line before the trimmed entries:
  `[Prior entries summarised: N iterations, key outcomes: ...]`
- This keeps the file under ~2000 tokens regardless of project length
