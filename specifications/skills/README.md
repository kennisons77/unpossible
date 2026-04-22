# Skills — Unpossible

Skills are **instructions** — the body of a node that tells an actor what to do.
They are model-agnostic. Which model executes them, how the prompt is assembled, and
how it is cached are concerns of the agent config (`.kiro/agents/`), not the instruction.

## Frontmatter

```yaml
name:    slug
kind:    tool | workflow | loop
command: how a human invokes it
runs:    once | n | until <condition>
actor:   default | plan | build | research | review  ← agent config name
```

`actor` references an agent config in `.kiro/agents/`. The config owns provider, model,
allowed_tools, and prompt_template. Swap the config to change how the instruction
executes — the instruction itself doesn't change.

See `specifications/system/agent-runner/concept.md` for how instructions are assembled, cached, and delivered
to providers.

---

Three kinds of instruction:

```
Tool      — a primitive capability. Runs once. Composable.
Workflow  — tools composed into a named output. Runs once or n times.
Loop      — a workflow run until a condition is met.
```

## Tools (`tools/`)

Primitives. Each does one thing. Loops and workflows call them.

| Tool | Description |
|---|---|
| [interview](tools/interview.md) | Ask questions until shared understanding is reached |
| [research](tools/research.md) | Collect sources and findings for a topic |
| [analyse](tools/analyse.md) | Compare a node against its outputs or codebase, report gaps |
| [commit](tools/commit.md) | Atomically commit code, append LEDGER.jsonl, and update IMPLEMENTATION_PLAN.md |
| [pr](tools/pr.md) | Create a pull request with graph-linked metadata |

## Workflows (`workflows/`)

Tools composed into a named output. Run once, or n times to refine.

| Workflow | Command | Description |
|---|---|---|
| [requirements](workflows/requirements.md) | `make requirements` | Produce or update requirements for a concept |
| [concept](workflows/concept.md) | `make concept` | Produce or update concept files |
| [review](workflows/review.md) | `make review` | Analyse codebase for weaknesses, propose beats |
| [server-ops](workflows/server-ops.md) | `make server-ops` | Operate on a server — deploy, rollback, check services |

## Loops (`loops/`)

Workflows run until a condition passes.

| Loop | Command | Runs until |
|---|---|---|
| [plan](loops/plan.md) | `./loop.sh plan [n]` | No open unplanned questions remain |
| [build](loops/build.md) | `./loop.sh [n]` | Tests green, beat accepted |
| [research](loops/research.md) | `./loop.sh research <id>` | Once per invocation — re-run to deepen |

## Providers (`providers/`)

Best practices for specific providers as actors. Referenced by agent config.

| Provider | Notes |
|---|---|
| [claude](providers/claude.md) | Cache control, token limits, effort levels |
| [kiro](providers/kiro.md) | Invocation, actor config, tool allowlists |
| [openai](providers/openai.md) | Context cap, structured output |

## The Flow

```
interview (tool)                ← reach shared understanding
  └── concept (workflow)        ← broad behavioral definition
      └── requirements (workflow) ← precise technical translation
          └── plan (loop)       ← produce beats from concepts + gap analysis
              └── build (loop)  ← execute beats until accepted
                  └── review (workflow) ← find weaknesses, propose new beats
```

A **beat** is not written directly — it is the residue of concept + requirements + gap
analysis in agreement. The plan loop produces beats. The build loop consumes them. The
review workflow produces new beats when the codebase drifts from the concepts.
