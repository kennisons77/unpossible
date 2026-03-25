# Kiro Agent Practices

Invoked via `kiro-cli chat --no-interactive --trust-all-tools --model <MODEL>`.

## Models

Kiro uses a credit multiplier system rather than direct token pricing. Costs are relative to your subscription's base credit rate.

| Model | Credit multiplier | Notes |
|---|---|---|
| auto | 1.00× | Default; kiro selects model per task automatically |
| claude-sonnet-4.5 | 1.30× | Strong code generation and reasoning |
| claude-sonnet-4 | 1.30× | Hybrid reasoning; good for regular build tasks |
| claude-haiku-4.5 | 0.40× | Fast and cheap; best for reads and simple edits |
| deepseek-3.2 | 0.25× | Experimental; strong at code, lower cost |
| minimax-m2.5 | 0.25× | Experimental; general purpose |
| minimax-m2.1 | 0.15× | Experimental; cheapest option |
| qwen3-coder-next | 0.05× | Experimental; lowest cost, code-focused |

> Multipliers from `kiro-cli chat --list-models`. Experimental models may change or be removed without notice.

## Task → Model Assignment

| Task type | Recommended model | Rationale |
|---|---|---|
| File read / search / grep | haiku-4.5 or qwen3-coder-next | Cheapest options; no reasoning needed |
| Boilerplate / scaffolding | haiku-4.5 | Mechanical generation at low cost |
| Code generation / editing | sonnet-4.5 or auto | Reliable quality; auto lets kiro optimize |
| Test writing | sonnet-4.5 | Needs context awareness |
| Planning / gap analysis | sonnet-4 or sonnet-4.5 | Structured reasoning at mid cost |
| Debugging / root cause | sonnet-4.5 | Best available reasoning in kiro |
| Architecture decisions | sonnet-4.5 | Highest quality option available |
| Cost-sensitive bulk work | deepseek-3.2 or minimax-m2.1 | Experimental but very cheap |

**Rule:** Use `auto` when unsure — kiro will route to the appropriate model. Pin a specific model only when you need predictable behavior or cost control.

## Caveats

- `--trust-all-tools` (`-a`) auto-approves all tool calls — run in a branch or sandbox.
- Kiro does not support `--output-format=stream-json`; output is plain text. Log parsing requires different tooling than the claude agent.
- Experimental models (deepseek, minimax, qwen3) are previews — output quality is less consistent and they may be removed. Don't rely on them for critical build loops.
- `auto` model selection is opaque; if cost predictability matters, pin an explicit model.
- Kiro has no persistent memory between loop iterations — `IMPLEMENTATION_PLAN.md` and `specs/activity.md` are its only state, same as claude.
- The `--model` flag accepts the exact model name strings listed above (e.g. `claude-sonnet-4.5`, not `sonnet`).
