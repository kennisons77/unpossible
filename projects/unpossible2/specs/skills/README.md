# Skills — Unpossible 2

Invocable agent workflows. A user explicitly triggers a skill via `make <skill>`.
Each skill has a defined goal, step sequence, and output.

## Format

Each file has YAML frontmatter followed by the skill body:

```yaml
---
name: <slug>
command: make <slug>
description: <one sentence>
model: haiku | sonnet | opus
loop_type: plan | build | reflect | research | none
principles: [<slug>, ...]   # which principles files to load
---
```

`loop_type: none` means the skill runs as a standalone agent conversation,
not inside the ralph loop.

> Skills are human-invoked workflows. For the autonomous build loop, see `AGENTS.md`.

## Skill Index

| Skill | Command | Loop Type | Description |
|---|---|---|---|
| [grill-me](grill-me.md) | `make grill-me` | none | Interview relentlessly to reach shared understanding before committing to code |
| [write-a-prd](write-a-prd.md) | `make write-a-prd` | plan | Turn a grilled idea into a spec file with user stories |
| [prd-to-tasks](prd-to-tasks.md) | `make prd-to-tasks` | plan | Break a PRD spec into vertical-slice tasks in the task system |
| [tdd](tdd.md) | `make tdd` | build | Red-green-refactor loop with interface-first philosophy |
| [improve-codebase-architecture](improve-codebase-architecture.md) | `make improve-codebase-architecture` | none | Find shallow modules, propose deepening candidates |
