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
