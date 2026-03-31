# Loop — loop.sh and Prompt Templates

## What It Does

`loop.sh` is the outer runner. It dispatches to an agent (claude, kiro, or custom), detects RALPH signals, manages git branching, and handles the iteration lifecycle. Prompt templates (`PROMPT_*.md`) define what the agent does in each mode.

## Loop Modes

| Mode | Prompt | Purpose |
|---|---|---|
| `build` | `PROMPT_build.md` | Implement one task, test, commit |
| `plan` | `PROMPT_plan.md` | Gap analysis, update IMPLEMENTATION_PLAN.md |
| `review` | `PROMPT_review.md` | Second LLM verifies last commit against spec |
| `reflect` | `PROMPT_reflect.md` | Analyse accumulated evidence, propose one improvement |
| `research` | `PROMPT_research.md` | Interview-driven spec expansion, edge case discovery, source collection — see [research-loop.md](research-loop.md) |
| `promote` | (no loop) | Promote an idea to a spec — shell only |

## RALPH Signals

- `RALPH_COMPLETE` — task done, loop exits 0
- `RALPH_WAITING: <question>` — agent needs human input, loop pauses

These are grep-able strings in agent output. The runner scans for them after each iteration.

## Rollback Guard

Each iteration is wrapped in a git stash guard:
1. `git stash push -m "ralph-pre-iteration-$N"` before agent runs
2. On success: `git stash drop`
3. On failure: `git stash pop` — working tree restored to pre-iteration state

Rollback events are logged to the Rails audit log via `POST /api/audit_events`.

## Reflect Mode

The Reflect loop reads accumulated AgentRun records (via Rails API), identifies patterns in costs/errors/review feedback, and proposes one concrete improvement. The proposal goes through the normal plan/build/review cycle — it never self-applies. This is how the system improves itself without bypassing its own backpressure.

## Prompt Templates

Prompts are templates with `{practices}` and `{context}` slots. The task schema declares which practices files are required. The plan loop assembles the prompt from: task type + knowledge base retrieval + declared practices. Current `PROMPT_build.md` and `PROMPT_plan.md` become the default templates.

## Acceptance Criteria

- `./loop.sh` runs build mode, unlimited iterations
- `./loop.sh plan 1` runs one plan iteration and exits
- `./loop.sh reflect` runs reflect mode
- Failed iteration leaves working tree clean (git stash pop)
- Successful iteration leaves stash empty
- `RALPH_COMPLETE` in agent output causes loop to exit 0
- `RALPH_WAITING: <question>` pauses loop and prompts for human input
- 3 consecutive iterations without a RALPH signal stops the loop with exit 2
- `AGENT=kiro` and `AGENT=claude` both work
