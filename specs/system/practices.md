# Practices

Practices files live in `specs/practices/` and are indexed into the knowledge base.
They are **reference material, not default context** — loading them every iteration
wastes tokens on content the agent already internalises.

## Loading Strategy

```
Always in context     cost.md — shapes model selection and context loading decisions
                      version-control.md — shapes every commit

Loaded by plan loop   planning.md — when producing beats
                      testing.md — when deriving test requirements from AC

Retrieved on demand   coding.md, verification.md, security.md, reflect.md
                      — pulled from knowledge base when the agent hits an issue
                        or when the instruction explicitly references them

Platform practices    specs/platform/{platform}/ — layered on top of base spec
                      by the plan loop, not loaded by default
```

Prompt caching is applied automatically by the provider adapter to `cost.md` and
`version-control.md` — they are stable across iterations and benefit from caching.
Practices authors do not add cache annotations manually.

## When Practices Enter the Equation

**PRD and spec authoring** — practices are not loaded. PRDs and specs are
platform-agnostic and implementation-free. Practices are irrelevant at this stage.

**Plan loop** — `planning.md` and `testing.md` are loaded to shape beat titles and
ensure AC maps to tests. `cost.md` is always present. Platform practices are layered
on top of the base spec.

**Build loop** — `cost.md` and `version-control.md` are always present. All others
are retrieved on demand from the knowledge base when the agent encounters an issue or
the instruction references them explicitly.

**Research loop** — `cost.md` only. Research is about collecting information, not
applying coding discipline.

**Reflect loop** — `reflect.md` loaded when written. `cost.md` always present.

## File Map

| File | Always | Plan | Build | Research | Reflect |
|---|---|---|---|---|---|
| `cost.md` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `version-control.md` | | | ✓ | | |
| `planning.md` | | ✓ | | | |
| `testing.md` | | ✓ | | | |
| `coding.md` | | | on demand | | |
| `verification.md` | | | on demand | | |
| `security.md` | | | on demand | | |
| `automation.md` | | | on demand | | |
| `reflect.md` | | | | | ✓ |
| `zed.md` | | | | | |

`zed.md` is never loaded by agents — it is for human reference only.

## Missing Files

- `security.md` — secrets handling, PII, attack surface rules
- `reflect.md` — reflect loop analysis and improvement proposals
