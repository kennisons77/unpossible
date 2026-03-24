# Prompt Language Patterns

Reference for anyone editing PROMPT_plan.md or PROMPT_build.md. These word choices are
load-bearing — changing them degrades agent behavior in specific, documented ways.

## Use These Words

| Word / phrase | Why it matters |
|---|---|
| `study` | Implies deeper analysis than "read" or "look at" — the agent treats it as a directive to reason, not just retrieve |
| `don't assume not implemented` | The most common loop failure mode is the agent inventing missing functionality rather than searching. This phrase directly counters it. |
| `Ultrathink` | Triggers extended internal reasoning before acting. Use before high-stakes decisions: gap analysis, architectural choices, debugging. |
| `capture the why` | Shapes commit messages and documentation toward intent rather than mechanics |
| `up to N subagents` | Sets a ceiling without mandating a floor — the agent scales to the task |
| `only 1 subagent for build/tests` | Enforces backpressure by preventing the agent from parallelising around a failing test |
| `keep it up to date` | Without this, IMPLEMENTATION_PLAN.md drifts stale within a few iterations |
| `resolve them or document them` | Prevents the agent from silently ignoring unrelated failures |

## Avoid These Patterns

- `read` or `look at` in place of `study` — lower signal, shallower analysis
- Vague success criteria — if the agent can't tell when it's done, it won't stop
- Long bullet lists of rules at the end of prompts — the agent front-loads attention; important rules belong near the top
- Contradictory instructions — the agent will pick one and ignore the other unpredictably

## Prompt Tuning

Treat prompts like a feedback loop, not a one-time config:

- When the agent fails in a specific, repeatable way — add one targeted line to the relevant prompt
- When the agent adds unnecessary complexity — add a constraint, don't rewrite the whole prompt
- When the plan goes stale or the agent seems confused about completion status — regenerate planning with `./loop.sh plan 1` rather than trying to patch the prompt

## Cost Discipline

Token spend compounds across iterations. These rules keep each loop iteration under $1.

**Model selection (by task):**

| Task | Model | Why |
|---|---|---|
| Reading files, searching, summarising | Haiku | Cheapest capable reader |
| Code generation, editing, tests | Sonnet | Best cost/quality for generation |
| Debugging, architecture, root-cause analysis | Opus | Justified only when cheaper models stall |

**Subagent limits:**
- Reading/searching: `up to 3 Haiku subagents`, each ≤5 turns
- Build/test: `only 1 Sonnet subagent`
- Kill any subagent that exceeds 10 turns — it is stuck, not thinking

**Context loading rules:**
- Load `specs/prd.md` and `specs/plan.md` directly via Read — no subagent needed
- Only load framework/lang practices files relevant to the current task
- Don't reload files already in context from the same iteration

**Prompt caching:**
- Large repeated context (prd.md, practices files) benefits from `cache_control: {type: "ephemeral", ttl: "1h"}`
- The default 5-minute TTL expires between loop iterations; always specify `ttl: "1h"` for shared context blocks
- Cached tokens cost ~10% of uncached input tokens — worth it for any block > 1000 tokens reused across turns
