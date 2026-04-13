# Practices

Practices files live in `specs/practices/` and are indexed into the knowledge base.
They are **reference material, not default context** — loading them every iteration
wastes tokens on content the agent already internalises.

## Loading Strategy

```
Always in context     cost.md — shapes model selection and context loading decisions
                      version-control.md — shapes every commit

Loaded by plan loop   planning.md — when producing beats
                      verification.md — when deriving test requirements from AC
                      changeability.md — when evaluating structure

Loaded by review loop changeability.md — when proposing refactors
                      coding.md — refactoring-as-a-bet rules

Retrieved on demand   coding.md, verification.md, security.md
                      threat-modeling.md, automation.md
                      — pulled from knowledge base when the agent hits an issue
                        or when the instruction explicitly references them

Platform practices    specs/platform/{platform}/ — layered on top of base spec
                      by the plan and build loops, not loaded by default
```

Prompt caching is applied automatically by the provider adapter to `cost.md` and
`version-control.md` — they are stable across iterations and benefit from caching.
Practices authors do not add cache annotations manually.

## When Practices Enter the Equation

**PRD and spec authoring** — practices are not loaded. PRDs and specs are
platform-agnostic and implementation-free. Practices are irrelevant at this stage.

**Plan loop** — `planning.md`, `verification.md`, and `changeability.md` are loaded
to shape beat titles, ensure AC maps to tests, and evaluate structural decisions.
`cost.md` is always present. Platform practices are layered on top of the base spec.

**Build loop** — `cost.md` and `version-control.md` are always present. All others
are retrieved on demand from the knowledge base when the agent encounters an issue or
the instruction references them explicitly. Platform overrides are loaded for the
active stack.

**Research loop** — `cost.md` only. Research is about collecting information, not
applying coding discipline.

**Review loop** — `changeability.md` and `coding.md` are loaded. `cost.md` is always
present. The review loop evaluates accumulated changes against structural and
refactoring principles.

## File Map

| File                 | Always | Plan | Build     | Review | Research |
|----------------------|--------|------|-----------|--------|----------|
| `cost.md`            | ✓      | ✓    | ✓         | ✓      | ✓        |
| `version-control.md` |        |      | ✓         |        |          |
| `planning.md`        |        | ✓    |           |        |          |
| `verification.md`    |        | ✓    | on demand |        |          |
| `changeability.md`   |        | ✓    | on demand | ✓      |          |
| `coding.md`          |        |      | on demand | ✓      |          |
| `security.md`        |        |      | on demand |        |          |
| `threat-modeling.md` |        |      | on demand |        |          |
| `automation.md`      |        |      | on demand |        |          |
| `lookup-tables.md`   |        |      | on demand |        |          |
| `zed.md`             |        |      |           |        |          |

`zed.md` is never loaded by agents — it is for human reference only.
