---
name: kiro
kind: provider
description: Best practices for Kiro (kiro-cli) as an actor
---

## Invocation

```bash
kiro-cli chat --no-interactive --trust-all-tools --model $MODEL -- "$PROMPT"
```

Never pass `--resume` — each iteration must be a fresh session.

## Agent Config

Select agent config by loop mode:

| Mode | Config |
|---|---|
| build | `ralph_build` |
| plan | `ralph_plan` |
| research | `ralph_research` |
| review | `ralph_review` |

## Tool Allowlists

Enforced at runtime via agent config `allowed_tools` — not just declared in the prompt.
The runtime rejects tool calls outside the allowlist regardless of what the instruction says.

## Caching

No native prompt caching. Cost efficiency via model selection and dedup only.
