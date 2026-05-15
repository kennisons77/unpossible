---
name: gascity-gap-analysis
kind: research
status: draft
description: Gap analysis mapping Unpossible concepts onto Gas City primitives
---

# Gap Analysis: Unpossible → Gas City

## System Overview

| Concern | Unpossible (custom) | Gas City (gascity) |
|---------|--------------------|--------------------|
| **Orchestration** | `loop.sh` + Makefile + PROMPT_*.md | `gc` CLI + `city.toml` + formulas + controller/supervisor |
| **Work tracking** | `IMPLEMENTATION_PLAN.md` (markdown checkboxes) | Beads (Dolt-backed structured records with status, assignee, metadata) |
| **Agent roles** | Single agent with mode switching (plan/build/review/research) | Named persistent agents: mayor, deacon, witness, refinery, polecat, dog |
| **Specifications** | `specifications/` hierarchy (concept → requirements → plan → code) | Not built-in; you bring your own spec structure |
| **Activity log** | `activity.md` + `LEDGER.jsonl` + git notes | `.gc/events.jsonl` + bead history + Dolt commit log |
| **Communication** | Human reads output, decides next step | `gc mail` (durable) + `gc session nudge` (ephemeral) between agents |
| **Runtime** | Docker containers (sandbox), host shell (loop.sh) | tmux sessions, subprocess, exec, ACP, or Kubernetes |
| **State reconciliation** | Manual (human runs `make plan`, `make build`) | Controller/supervisor loop reconciles desired → running state |

---

## Concept Mapping (Unpossible → Gas City)

| Unpossible Concept | Gas City Equivalent | Notes |
|---|---|---|
| **Beat** (task in IMPLEMENTATION_PLAN.md) | **Bead** (`bd create`) | Both are atomic work units. Beads have richer metadata (status, assignee, dependencies, metadata JSON) |
| **Loop** (plan/build/review/research) | **Formula** (mol-*.toml) | Formulas are declarative step sequences. Loops are imperative bash scripts that invoke an LLM |
| **RALPH signals** (RALPH_COMPLETE, RALPH_WAITING) | **Drain/nudge** (`gc runtime drain-ack`, `gc session nudge`) | Gas City agents signal completion via drain; they don't output magic strings |
| **Rollback guard** (git stash) | **Worktree isolation** (mol-polecat-work) | Polecats get their own git worktree + feature branch. Failure = branch abandoned, bead returned to pool |
| **PROMPT_build.md** | **Formula step descriptions** + **template-fragments** | The prompt IS the formula. Steps contain the instructions inline |
| **Agent configs** (.kiro/agents/*.json) | **Pack agent definitions** (gastown/agents/*) + **city.toml** | Gas City agents are declared in packs and instantiated by the controller |
| **Makefile targets** (make build, make plan) | **gc commands** + **orders** | `gc start`, `bd create`, `gc sling` replace make targets |
| **ACTIVE_PROJECT** | **Rig** (`gc rig add .`) | A rig is a git repo registered with the city. Multi-rig = multi-project |
| **Specifications hierarchy** | **No equivalent** — bring your own | Gas City doesn't prescribe how you structure specs |
| **Reference graph** (LEDGER.jsonl, git notes, parser) | **Bead graph** (parent/child beads, `gc bd dep add`) | Beads form a DAG. The reference graph is richer (cross-artifact tags, glossary) but less operational |
| **Controlled commit** (scripts/controlled-commit.sh) | **Polecat commit step** (mol-polecat-commit) | Both gate commits on test pass. Gas City's is a formula step, not a standalone script |
| **Review workflow** | **Refinery patrol** (mol-refinery-patrol) | Refinery merges branches after code review. The review loop proposes new beats |
| **Research loop** | **mol-idea-to-plan** (partial) | Gas City's planning formula dispatches parallel review legs. No dedicated "research" primitive |
| **Interview tool** | **No equivalent** | Gas City has no built-in requirements-gathering workflow |
| **Sandbox** (Docker container lifecycle) | **Runtime providers** (tmux, subprocess, exec, k8s) | Different abstraction level. Sandbox isolates execution; GC's runtime manages agent sessions |

---

## What Gas City Gives You That Unpossible Doesn't Have

1. **Multi-agent parallelism** — Polecats work simultaneously on different beads. loop.sh is strictly sequential (one agent, one beat at a time).

2. **Autonomous recovery** — Witness detects crashed agents, salvages worktrees, returns beads to pool. Unpossible requires human intervention on failure.

3. **Declarative desired state** — `city.toml` declares what should be running. The controller reconciles. Unpossible is imperative (human runs make targets).

4. **Inter-agent communication** — Mail and nudges let agents coordinate without human mediation. Unpossible agents talk only to the human.

5. **Work routing** — Beads flow through a pipeline (pool → polecat → refinery → closed). Beats are consumed sequentially by one agent.

6. **Health patrol** — Deacon monitors system health, detects stuck agents, runs diagnostics. Unpossible has no self-monitoring.

7. **Pack composition** — Reusable infrastructure packs (maintenance, dolt, core) compose into any city. Makefile/loop.sh is monolithic.

---

## What Unpossible Has That Gas City Doesn't Provide

1. **Specification-driven development** — The full chain (brief → concept → requirements → plan → build → review) with structural vocabulary, glossary tags, and cross-references. Gas City is spec-agnostic.

2. **Reference graph** — File-and-git-native artifact tracking with a Go parser. Gas City's bead graph tracks work items, not knowledge artifacts.

3. **Platform-specific overrides** — The `platform/rails/` and `platform/go/` layering system. Gas City has no concept of spec inheritance.

4. **Practices as loadable context** — Discipline rules (coding.md, security.md, verification.md) loaded on demand by the agent. Gas City uses template-fragments but they're more operational than disciplinary.

5. **The Rails platform itself** — Agent run storage, analytics, sandbox, feature flags. Gas City orchestrates agents but doesn't store their outputs in a queryable database.

6. **Controlled commit with test gating** — The rollback guard + test-before-commit is more rigorous than Gas City's default (though mol-polecat-commit does gate on tests).

7. **Activity log as learning signal** — activity.md + LEDGER.jsonl feed back into planning. Gas City's events.jsonl is operational, not reflective.

---

## How to Build "Unpossible-like" Projects with Gas City

### Planning (make plan → Gas City)

| Unpossible | Gas City |
|---|---|
| `./loop.sh plan` reads specs, produces beats in IMPLEMENTATION_PLAN.md | Mayor reads spec files, creates beads with `bd create`, adds dependencies with `gc bd dep add` |
| Plan loop runs until no open unplanned questions | Mayor uses `mol-idea-to-plan` formula (dispatches parallel review legs, refines, creates bead graph) |
| IMPLEMENTATION_PLAN.md is the source of truth | Bead list (`bd list --status=open`) is the source of truth |

### Building (make build → Gas City)

| Unpossible | Gas City |
|---|---|
| `./loop.sh` picks oldest open beat, implements, commits | Polecat picks assigned bead, runs `mol-polecat-work` (worktree → implement → push → assign to refinery) |
| Single agent, sequential | Multiple polecats, parallel (pool-based dispatch) |
| RALPH_COMPLETE signals done | `gc runtime drain-ack` signals done; bead status → closed |
| Rollback guard (git stash) | Feature branch isolation (worktree per polecat) |

### Review (make review → Gas City)

| Unpossible | Gas City |
|---|---|
| Review loop analyses codebase, proposes new beats | Refinery patrol (`mol-refinery-patrol`) reviews branches, merges or rejects |
| Rejection = new beat proposed | Rejection = bead returned to pool with `metadata.rejection_reason` |

### Research (make research → Gas City)

| Unpossible | Gas City |
|---|---|
| `./loop.sh research <id>` runs one research iteration | No direct equivalent. Create a bead with research instructions, assign to a polecat or dog |
| Research findings stored in `specifications/research/` | Findings stored wherever you want (spec tree, bead notes, or committed files) |

---

## The Hybrid Path

Given the spec-heavy, knowledge-graph approach, the natural fit is:

1. **Keep `specifications/` hierarchy** — Gas City doesn't replace this. It's the knowledge layer.
2. **Replace `IMPLEMENTATION_PLAN.md` with beads** — `bd create "Task title" --description "acceptance criteria"` + `gc bd dep add` for ordering.
3. **Replace `loop.sh` with formulas** — Build loop becomes `mol-polecat-work` (or `mol-do-work` for simple single-agent). Plan loop becomes mayor + `mol-idea-to-plan`.
4. **Keep practices as template-fragments** — Move coding.md, verification.md etc. into `unpossible-city/template-fragments/` so they're injected into agent context.
5. **Replace PROMPT_*.md with formula steps** — Instructions live in the formula TOML, not separate markdown files.
6. **Replace Makefile with `gc` commands** — `gc start` replaces `make up`. `bd create` + `gc sling` replaces `make build`.

---

## Key Architectural Difference

**Unpossible** is a *platform that builds itself* — the Rails app stores agent runs, the Go sidecar manages execution, and loop.sh orchestrates. It's self-referential.

**Gas City** is *pure orchestration* — it doesn't care what you're building. It manages agent sessions, routes work, and reconciles state. The thing being built is opaque to it.

To build something like Unpossible's platform using Gas City: Gas City would be the orchestration layer coordinating the agents doing the building, but it wouldn't replace the platform itself. You'd still need a database, an API, and storage for the artifacts those agents produce.

---

## Deep Dive: Build Loop → Polecat Workflow

The core insight: the Unpossible build loop is a *single-agent, sequential, stash-guarded TDD cycle* that reads from a markdown plan. Gas City's polecat workflow is a *multi-agent, parallel, worktree-isolated implementation cycle* that reads from beads. The TDD discipline itself is NOT built into Gas City — you bring it via template-fragments or formula step descriptions.

### Step-by-Step Mapping

| Build Loop Step | Polecat Equivalent | Gap? |
|---|---|---|
| 1. Read IMPLEMENTATION_PLAN.md for oldest open beat | `load-context`: `bd show {{issue}}` — bead is pre-assigned by controller | ✅ Direct. Bead replaces markdown checkbox |
| 2. Read acceptance criteria + spec | `load-context`: bead description + metadata | ⚠️ Partial. Beads have description/notes but no structured "spec link." Put spec paths in `metadata.spec` |
| 3. Design the interface | `implement` step (no separate design step) | ❌ Gap. Polecat jumps to implementation. Add a step or encode in implement description |
| 4. Red — write failing test | Part of `implement` step | ❌ Gap. No TDD enforcement. Formula says "implement" without mandating red/green/refactor |
| 5. Green — make test pass | Part of `implement` step | Same |
| 6. Refactor | Part of `implement` step | Same |
| 7. Typecheck + lint | `self-review` step runs `{{typecheck_command}}` + `{{lint_command}}` | ✅ Direct |
| 8. Repeat 4-7 per criterion | Implicit in `implement` | ⚠️ No explicit loop structure. Agent decides when done |
| 9. Commit | Atomic commits during `implement`, final push in `submit-and-exit` | ✅ Different model — GC commits incrementally, not once at end |
| 10. Mark beat complete | `bd close {{issue}}` (or refinery closes after merge) | ✅ Direct |
| 11. Log to activity.md | No equivalent — bead history IS the log | ⚠️ Add a step or use `--notes` on bead close |
| RALPH_COMPLETE | `gc runtime drain-ack` | ✅ Direct |
| RALPH_WAITING | `gc mail send witness -s "HELP: ..."` | ✅ Async — sends mail instead of pausing loop |
| Rollback guard (git stash) | Worktree isolation (feature branch) | ✅ Stronger — failure = abandon branch, not stash pop |

### The TDD Gap — How to Bring It

Gas City's `mol-polecat-base` has a generic `implement` step. The Unpossible build loop enforces strict red/green/refactor. Three options to bring TDD discipline into Gas City:

**Option A: Template fragment (lightest touch)**

Create `unpossible-city/template-fragments/tdd-discipline.template.md` — injected into every polecat's context. The gastown pack already ships one (`tdd-discipline.template.md`). Customize with the specific cycle:

```
1. Design the interface — inputs, outputs, boundaries
2. Red — smallest test describing one behaviour. Run it. Must fail.
3. Green — minimum code to pass. Run it. Must pass.
4. Refactor — clean up without changing behaviour. Tests still green.
5. Repeat 2-4 for each acceptance criterion.
```

**Option B: Override the implement step (medium)**

Create a formula that extends `mol-polecat-base` and replaces the `implement` step with explicit TDD sub-steps (design → red → green → refactor → repeat). The step description becomes the instruction.

**Option C: Custom formula (heaviest)**

Write `mol-unpossible-build.toml` encoding the exact 11-step cycle as formula steps. Most control, most maintenance burden.

**Recommendation:** Option A for starting out. The gastown pack's existing `tdd-discipline.template.md` already enforces TDD — read it and decide if it's sufficient or needs customization.

### Isolation Model Comparison

```
Unpossible:                          Gas City:
┌─────────────────────┐              ┌─────────────────────────────┐
│ git stash push      │              │ git worktree add            │
│ ┌─────────────────┐ │              │ ┌─────────────────────────┐ │
│ │ agent works     │ │              │ │ polecat works on branch │ │
│ │ on main branch  │ │              │ │ in isolated worktree    │ │
│ └─────────────────┘ │              │ └─────────────────────────┘ │
│ success? commit     │              │ push branch                 │
│ failure? stash pop  │              │ refinery merges or rejects  │
└─────────────────────┘              └─────────────────────────────┘
```

Key differences:
- **Unpossible**: One agent, one branch (main), stash-based rollback. Failure = restore working tree. No parallel work possible.
- **Gas City**: N agents, N branches, worktree-based isolation. Failure = branch abandoned, bead returned to pool. Another polecat can retry. Parallel work is the default.

### Controlled Commit Comparison

Unpossible's `controlled-commit.sh` atomically:
1. Appends to LEDGER.jsonl (status transition)
2. Updates IMPLEMENTATION_PLAN.md (checkbox)
3. Commits code + ledger + plan together

Gas City's equivalent is split across steps:
1. Polecat commits code during `implement` (incremental)
2. Polecat pushes in `submit-and-exit`
3. Refinery merges and closes bead (`bd close`)
4. Bead status transition IS the ledger (Dolt commit history)

The atomicity guarantee differs: Unpossible's is "code + metadata in one git commit." Gas City's is "bead state is always consistent with branch state" (enforced by the formula contract, not a script).

### Signal Comparison

| Unpossible Signal | Gas City Equivalent | Mechanism |
|---|---|---|
| `RALPH_COMPLETE` | `gc runtime drain-ack` | Agent tells controller it's done. Controller reclaims session. |
| `RALPH_WAITING: <question>` | `gc mail send witness -s "HELP: ..."` | Agent mails witness/mayor. Doesn't block — continues or drains. |
| 3 iterations without signal → exit 2 | Controller timeout / witness stuck-detection | Deacon patrol detects stuck agents, files warrants for dog pool. |
| Runner scans stdout for signals | Controller watches session state + drain events | No stdout parsing. State is in the runtime, not the output stream. |

### What mol-polecat-commit Gives You (Simpler Variant)

For single-agent workflows closer to Unpossible's model, `mol-polecat-commit` skips the refinery entirely:
- Commits directly to base_branch (like Unpossible's commit-to-main)
- Push with retry (fetch + rebase on conflict, up to 3 attempts)
- Closes bead itself (no handoff)
- Still uses worktree isolation (safer than stash)

This is the closest Gas City equivalent to the Unpossible build loop's "commit on green" model. Use it when you don't need merge review.

---

## Deep Dive: Plan Loop → Mayor + mol-idea-to-plan

The Unpossible plan loop is a *single-agent, spec-reading, gap-analysis-driven beat generator* that writes markdown checkboxes. Gas City's planning workflow is a *multi-agent, parallel-review, iteratively-refined pipeline* that produces a bead DAG. The planning philosophies are fundamentally different.

### Philosophy Comparison

**Unpossible planning** is *deductive*:
- Start with specifications (concept + requirements + platform override)
- Run `analyse` tool against codebase to find gaps
- Gaps become beats (tasks) — each beat traces back to an acceptance criterion
- A beat is "the residue of concept + requirements + gap analysis in agreement"
- Single agent, sequential, deterministic

**Gas City planning** is *generative + adversarial*:
- Start with a raw idea or problem statement
- Draft a PRD, then attack it from 6 angles in parallel
- Human gate for clarification
- Generate design, then attack it from 6 more angles
- 3 rounds of PRD-alignment review (2 legs each)
- 3 rounds of plan self-review (2 legs each)
- Convert refined plan into beads with dependencies
- Multi-agent, parallel, iterative refinement

### Step-by-Step Mapping

| Plan Loop Step | mol-idea-to-plan Equivalent | Gap? |
|---|---|---|
| 1. Read IMPLEMENTATION_PLAN.md + concepts + requirements | `init-run`: prime environment, read problem + context | ⚠️ Different input. Unpossible reads existing specs; GC starts from raw idea |
| 2. Read platform override | No equivalent | ❌ Gap. GC has no concept of layered spec overrides |
| 3. Load planning.md + verification.md practices | Template-fragments injected at session start | ✅ Different mechanism, same effect |
| 4. Run `analyse` (compare spec vs codebase) | `prd-review` + `design-exploration` (6 parallel legs each) | ⚠️ Different approach. Unpossible does gap analysis; GC does adversarial review |
| 5. Create spike beats for unknowns | Captured in PRD "Open Questions" → deferred or resolved at human gate | ⚠️ Partial. GC resolves questions during planning; Unpossible defers to research loop |
| 6. Write beats to plan file | `create-beads`: `gc bd create` + `gc bd dep add` | ✅ Direct. Beads replace checkboxes |
| 7. Prune plan file | Not needed — beads are queryable, not a flat file | ✅ Solved by design |
| 8. Log to activity.md | Bead creation IS the log | ✅ |
| 9. RALPH_COMPLETE | Formula completes, session drains | ✅ |

### The Specification Gap

The biggest difference: Unpossible's plan loop REQUIRES pre-existing specifications. It cannot plan without them. The chain is:

```
interview → concept → requirements → plan → build → review
```

Gas City's `mol-idea-to-plan` starts from a raw idea and GENERATES the spec-equivalent (PRD + design doc) as part of planning. It collapses interview + concept + requirements + plan into one formula.

**Implication:** If you want spec-driven planning in Gas City, you have two paths:

**Path 1: Use mol-idea-to-plan as-is, treat PRD as your spec**
- The PRD draft + design doc become your specification
- Stored in `.prd-reviews/` and `.designs/` (committed to git)
- Less structured than Unpossible's concept/requirements split
- But iteratively reviewed (6+6+6+6 = 24 review legs)

**Path 2: Keep your spec hierarchy, write a custom planning formula**
- Keep `specifications/` as the source of truth
- Write a `mol-unpossible-plan.toml` that:
  1. Reads existing concepts + requirements
  2. Runs gap analysis against codebase (like the `analyse` tool)
  3. Dispatches review legs to validate the gaps found
  4. Creates beads from confirmed gaps
- This preserves the deductive model but adds Gas City's parallel review

### The Research/Spike Gap

Unpossible has a dedicated research loop (`./loop.sh research <id>`) that:
- Runs one iteration per invocation
- Stores findings in `specifications/research/`
- Blocks dependent build beats until research completes

Gas City has no dedicated research primitive. The closest equivalents:

| Unpossible Research | Gas City Option |
|---|---|
| `./loop.sh research <id>` | Create a bead with research instructions, assign to a dog or polecat |
| Research findings in `specifications/research/` | Findings stored in bead notes or committed files |
| Spike beats block dependent builds | `gc bd dep add` — dependent beads won't be dispatched until spike closes |
| Re-run to deepen | Create a new bead referencing the prior one |

### The Analyse Tool Gap

Unpossible's `analyse` tool is a structured gap-analysis primitive:
```
Source (spec) → Target (codebase) → {Missing, Stale, Complete}
```

Gas City has no equivalent single-step tool. The closest is the parallel review dispatch pattern:
- Create a bead describing what to analyse
- Sling it to a polecat with `mol-review-leg`
- Polecat reads the spec + codebase, writes findings to bead notes
- Coordinator synthesizes

This is more expensive (spawns an agent session) but produces richer output (full report vs. three-bucket list).

### Output Comparison

**Unpossible plan output:**
```markdown
- [ ] 2.2 — Implement analytics sidecar (go/cmd/analytics/main.go) [blocked by 2.1]
  Required tests: POST /capture returns 202, events flushed within 5s...
```

**Gas City plan output:**
```bash
gc bd create --title "Implement analytics sidecar" \
  --description "POST /capture returns 202. Events flushed within 5s or 100 events..." \
  --type task
gc bd dep add <this-bead> <spike-bead>  # blocked until spike closes
gc convoy add <convoy-id> <this-bead>   # grouped under initiative
```

Key differences:
- Beads are queryable (`bd list --status=open --blocked`)
- Beads have structured metadata (assignee, priority, type, custom fields)
- Beads form a DAG (not a flat ordered list)
- Beads are routable (controller can dispatch them to agents automatically)

### The Human Gate

Unpossible's plan loop has no explicit human gate — it runs until done, outputs RALPH_COMPLETE, and the human reviews the plan file.

Gas City's `mol-idea-to-plan` has ONE explicit human gate (`human-clarify` step):
- Presents consolidated questions from 6 PRD review legs
- Waits for numbered answers in chat
- Updates the PRD with clarifications
- Then continues autonomously through design + review rounds

This is more structured than Unpossible's approach (where the human reviews after the fact) but less interactive than Unpossible's interview tool (which asks questions until shared understanding).

### Parallel Review — What It Buys You

Unpossible's plan loop is one agent doing gap analysis sequentially. Gas City's planning dispatches up to 24 review legs across the pipeline:

```
PRD Review:        6 legs (requirements, gaps, ambiguity, feasibility, scope, stakeholders)
Design Review:     6 legs (api, data, ux, scale, security, integration)
PRD Alignment:     6 legs (3 rounds × 2 legs)
Plan Self-Review:  6 legs (3 rounds × 2 legs)
```

Each leg is a separate agent session running `mol-review-leg`. They execute in parallel within each phase, sequentially across phases. This means:
- Broader coverage (6 perspectives vs. 1)
- Faster wall-clock time (parallel execution)
- Higher token cost (24 agent sessions vs. 1)
- More structured output (each leg has a defined report format)

### Recommendation: Which Planning Model to Use

| Situation | Use |
|---|---|
| Small, well-specified feature (spec already exists) | Custom formula that reads specs + runs gap analysis → creates beads |
| New feature from scratch (no spec yet) | `mol-idea-to-plan` — it generates the spec as part of planning |
| Research spike needed | Create a bead, assign to dog/polecat, block dependent beads |
| Iterating on existing plan | Mayor reads bead list, creates/modifies beads directly |

For Unpossible's self-building model (specs exist, plan derives from gap analysis), a custom `mol-unpossible-plan.toml` that preserves the deductive approach while adding Gas City's bead output would be the best fit.

---

## Deep Dive: Multi-Agent Coordination

Unpossible uses a single-agent model where one LLM session does everything (plan, build, review, research) and the human is the coordinator. Gas City runs a persistent multi-agent system where specialized roles coordinate autonomously. Understanding this difference is key to deciding what Gas City buys you.

### The Unpossible Model: Human as Coordinator

```
Human (you)
  │
  ├── make plan    → single agent reads specs, writes beats
  ├── make build   → single agent picks beat, implements, commits
  ├── make review  → single agent analyses codebase, proposes beats
  └── make research → single agent researches topic, writes findings
```

Characteristics:
- **Sequential** — one thing happens at a time
- **Human-gated** — you decide what runs next
- **Stateless between runs** — each loop.sh invocation starts fresh (reads IMPLEMENTATION_PLAN.md)
- **No inter-agent communication** — there's only one agent
- **Failure recovery** — human notices, re-runs

### The Gas City Model: Controller as Coordinator

```
Controller (Go binary, always running)
  │
  ├── Mayor (city-scoped, 1 instance)
  │     └── Coordinates work, dispatches beads, strategic decisions
  │
  ├── Deacon (city-scoped, 1 instance)
  │     └── Health patrol: stuck agents, system diagnostics, Dolt health
  │
  └── Per-Rig agents:
        ├── Witness (1 per rig)
        │     └── Orphan recovery, refinery queue health, polecat stuck detection
        │
        ├── Refinery (1 per rig, on-demand)
        │     └── Merge review: rebase, test, merge or reject
        │
        └── Polecat pool (N per rig, on-demand)
              └── Implementation: pick bead, branch, implement, push, exit
```

Characteristics:
- **Parallel** — multiple polecats work simultaneously
- **Autonomous** — agents coordinate via mail/nudge without human
- **Persistent state** — beads in Dolt survive crashes, restarts, context resets
- **Self-healing** — witness recovers orphaned work, deacon detects stuck agents
- **Human is optional** — system runs unattended (human intervenes for decisions)

### Role Mapping: What Each Gas City Agent Does vs. Unpossible

| Gas City Role | Unpossible Equivalent | What It Adds |
|---|---|---|
| **Mayor** | Human + plan loop | Autonomous work dispatch, cross-rig coordination, strategic decisions without human |
| **Deacon** | Nothing (human monitors) | Automated health patrol, stuck-agent detection, system diagnostics, Dolt maintenance |
| **Witness** | Nothing (human re-runs on failure) | Orphan bead recovery, worktree salvage, refinery queue monitoring, polecat health |
| **Refinery** | Review loop (partial) | Automated merge review — rebase, test, merge or reject with feedback |
| **Polecat** | Build loop agent | Same job (implement a task), but parallel, worktree-isolated, and self-cleaning |
| **Dog** | Nothing | Utility pool for shutdown dances, maintenance tasks, one-off jobs |

### What Multi-Agent Coordination Solves

**Problem 1: Sequential bottleneck**

Unpossible processes one beat at a time. If you have 10 independent beats, they take 10× as long.

Gas City solution: Multiple polecats work in parallel. Independent beads are dispatched simultaneously. The controller spawns polecats as work appears and reclaims them when done.

**Problem 2: Failure requires human intervention**

If loop.sh crashes mid-beat, the human must notice, check git status, possibly stash pop, and re-run.

Gas City solution: Witness patrol detects orphaned beads (assigned to dead agents), salvages any unpushed work from the worktree, pushes the branch, and returns the bead to the pool. A new polecat picks it up and continues from the existing branch.

**Problem 3: No merge review automation**

Unpossible commits directly to main. The review loop proposes new beats but doesn't gate merges.

Gas City solution: Refinery patrol picks up branches pushed by polecats, rebases onto target, runs tests, and either merges (fast-forward) or rejects with a reason. Rejected beads go back to the pool with `metadata.rejection_reason` — the next polecat reads the reason and fixes the issue.

**Problem 4: No health monitoring**

If the Unpossible agent gets stuck in an infinite loop or burns tokens without progress, nothing detects it.

Gas City solution: Witness checks polecat progress (bead `UpdatedAt` timestamps). Deacon checks witness/refinery health. Stuck agents get warrants filed → dog pool runs shutdown dance (3 chances to prove alive before kill).

**Problem 5: No autonomous planning**

Unpossible's plan loop runs when the human invokes `make plan`. Between runs, no planning happens.

Gas City solution: Mayor is always running. When beads close, the mayor can assess what's next, create new beads, dispatch work — all without human input. The human can intervene via the mayor's live session (`gc session attach mayor`).

### The Communication Model

Unpossible has no inter-agent communication (single agent). Gas City has two channels:

**Mail (durable, bead-backed):**
```bash
gc mail send mayor/ -s "ESCALATION: polecat stuck" -m "details..."
gc mail inbox          # Check messages
gc mail archive <id>   # Close after processing
```
Use for: escalations, handoffs, completion notifications, anything that must survive restarts.

**Nudge (ephemeral, zero-cost):**
```bash
gc session nudge refinery "Work beads waiting for merge"
```
Use for: routine signals, wake-ups, status pokes. Lost on restart — that's fine.

**The litmus test:** "If the recipient dies and restarts, do they need this message?" Yes → mail. No → nudge.

### The Wisp Pattern (Continuous Patrol)

Witness and Deacon run as continuous patrol loops using the "wisp" pattern:

```
1. Pour a wisp (bead representing one patrol iteration)
2. Assign wisp to self
3. Execute patrol steps (check mail, recover orphans, health scan)
4. Pour NEXT wisp before burning current one
5. Wait for events (exponential backoff)
6. Burn current wisp
7. New session picks up next wisp → repeat
```

This gives:
- **Crash recovery** — if the agent dies mid-patrol, the wisp is still assigned. On restart, it re-reads formula steps and resumes.
- **Context management** — when context fills up, `gc runtime request-restart` blocks until controller kills the session. Next session starts fresh with the same wisp.
- **Observability** — wisp burn rate = patrol frequency. Stale wisps = stuck agent.

Unpossible has no equivalent. The closest is "human runs `make review` periodically."

### The Warrant System (Due Process for Killing Agents)

When a witness or deacon detects a stuck agent, they don't kill it directly. They file a warrant:

```bash
gc bd create --type=warrant \
  --title="Stuck: polecat-3" \
  --metadata '{"target":"polecat-3","reason":"No progress for 15min","requester":"witness"}' \
  --label=pool:dog
```

A dog from the utility pool picks up the warrant and runs `mol-shutdown-dance`:
1. Nudge the target: "Are you alive? Respond within 60s"
2. If no response: nudge again with escalation
3. If still no response: kill the session
4. Report outcome to requester

This prevents false positives (agent might be in a long tool call) and provides an audit trail.

Unpossible has no equivalent — the human decides when to kill a stuck loop (Ctrl+C).

### How This Would Augment Unpossible

If you adopted Gas City's multi-agent model for Unpossible:

| Current (single-agent) | With Gas City multi-agent |
|---|---|
| `make build` processes 1 beat | 3 polecats process 3 beats simultaneously |
| Human notices failures | Witness auto-recovers, re-dispatches |
| Human runs `make review` | Refinery auto-reviews every pushed branch |
| Human monitors progress | Deacon patrols, detects stuck agents |
| Human decides what's next | Mayor dispatches based on bead DAG |
| 1 beat/hour throughput | 3-5 beats/hour throughput (parallel) |

### Cost Tradeoff

Multi-agent coordination is not free:

| Resource | Single-agent (Unpossible) | Multi-agent (Gas City) |
|---|---|---|
| Active LLM sessions | 1 | 5-8 (mayor + deacon + witness + refinery + N polecats) |
| Token burn rate | Low (one agent working) | Higher (patrol agents consume tokens even when idle) |
| Dolt/storage | None | Dolt server + beads database |
| Complexity | Low (one loop, one plan file) | High (formulas, packs, controller, mail, wisps) |
| Human attention | High (you run everything) | Low (system runs autonomously) |

The tradeoff: more tokens and infrastructure complexity in exchange for parallelism, self-healing, and autonomous operation.

### Minimum Viable Multi-Agent Setup

You don't need the full gastown pack to get multi-agent benefits. The minimum:

1. **Mayor** — coordinates, dispatches beads
2. **1 Polecat** — implements (using mol-polecat-commit for direct commits)
3. **No witness, no refinery, no deacon** — human monitors

This gives you bead-based work tracking and formula-driven implementation without the full coordination overhead. Add roles as pain points emerge:
- Add **refinery** when you want automated merge review
- Add **witness** when you want crash recovery
- Add **deacon** when you want health monitoring
- Scale **polecats** when you want parallelism

---

## Deep Dive: Specification Integration (Practices → Template Fragments)

Unpossible has a rich, structured system for loading discipline rules into agent context. Gas City has template-fragments and skills. The two systems serve similar purposes but work differently. This section maps how to bring Unpossible's specification hierarchy into Gas City.

### How Context Loading Works in Each System

**Unpossible:**
```
Agent config (.kiro/agents/*.json)
  └── resources: [file paths]     ← static context, always loaded
      └── AGENTS.md, cost.md, version-control.md, skills/**/*.md

PROMPT_*.md
  └── instructions reference practices by name
      └── "Load planning.md and verification.md by file path"

On-demand loading:
  └── Agent reads a practice file when it hits an issue
      └── "Load coding.md" → agent uses file-read tool
```

Loading is selective per loop type (see practices.md File Map). Not all practices load every time — that would waste tokens.

**Gas City:**
```
city.toml
  └── global_fragments = ["command-glossary", "operational-awareness"]
      └── Injected into EVERY agent's system prompt at session start

Pack agent definitions (agents/*/prompt.template.md)
  └── {{ template "propulsion-polecat" . }}
  └── {{ template "tdd-discipline" . }}
  └── {{ template "architecture" . }}
      └── Go template syntax, rendered at session start

Skills (core/skills/*/SKILL.md)
  └── Loaded on demand via slash commands (/gc-work, /gc-dispatch, etc.)
```

### The Mapping

| Unpossible Mechanism | Gas City Equivalent | How It Works |
|---|---|---|
| Always-loaded practices (cost.md, version-control.md) | `global_fragments` in city.toml | Injected into every agent's prompt |
| Per-loop practices (planning.md for plan, coding.md for build) | Per-agent `prompt.template.md` | Each agent role gets different template includes |
| On-demand practices (security.md, threat-modeling.md) | Skills (`/gc-*` slash commands) or file reads | Agent loads when needed |
| Agent configs (.kiro/agents/*.json) | Pack agent definitions (agents/*/agent.toml + prompt.template.md) | Declares provider, model, context |
| PROMPT_*.md (loop instructions) | Formula step descriptions | Instructions live in the formula TOML |
| Structural vocabulary | Template-fragments (custom) | You'd create these yourself |
| Glossary | Template-fragment (custom) | You'd create this yourself |
| Platform overrides (platform/rails/) | No equivalent | Bring your own — reference from formula steps |

### Concrete Migration Plan

#### Step 1: Always-loaded practices → global_fragments

Your `city.toml` already has:
```toml
global_fragments = ["command-glossary", "operational-awareness"]
```

Add your always-loaded practices:
```toml
global_fragments = ["command-glossary", "operational-awareness", "cost-management", "version-control"]
```

Then create the template files:
```
unpossible-city/template-fragments/cost-management.template.md
unpossible-city/template-fragments/version-control.template.md
```

These would contain the content from `specifications/practices/cost.md` and `specifications/practices/version-control.md`, wrapped in Go template syntax:
```
{{ define "cost-management" }}
## Cost Management
[content from cost.md]
{{ end }}
```

#### Step 2: Per-role practices → agent prompt templates

In Unpossible, the build loop loads `coding.md` and `verification.md`. In Gas City, the polecat agent's prompt template would include these:

```
# In a custom pack: agents/polecat/prompt.template.md

{{ template "propulsion-polecat" . }}
{{ template "tdd-discipline" . }}
{{ template "coding-practices" . }}
{{ template "verification-practices" . }}
```

The mayor (planning role) would include different practices:
```
# agents/mayor/prompt.template.md

{{ template "propulsion-mayor" . }}
{{ template "planning-practices" . }}
{{ template "changeability" . }}
{{ template "structural-vocabulary" . }}
```

#### Step 3: On-demand practices → skills or file references

Practices loaded on demand in Unpossible (security.md, threat-modeling.md, retry.md) have two options in Gas City:

**Option A: Skills (slash commands)**

Create `unpossible-city/.gc/system/packs/core/skills/practices/SKILL.md`:
```markdown
---
name: practices
description: Load Unpossible practice files on demand
---

# Practices Reference

Load these by reading the file when needed:
- Security: specifications/practices/security.md
- Threat modeling: specifications/practices/threat-modeling.md
- Retry: specifications/practices/retry.md
- Multi-tenancy: specifications/practices/multi-tenancy.md
```

**Option B: Keep as files, reference in formula steps**

Formula step descriptions can say:
```
If you encounter a security concern, read `specifications/practices/security.md`
before proceeding.
```

This is closer to Unpossible's current model ("load by file path on demand").

#### Step 4: Structural vocabulary → template-fragments

The structural vocabulary (`core.md`, `extended.md`, `guarantees.md`, `faults.md`) is large. Loading all of it into every agent would waste tokens. Strategy:

- `core.md` → template-fragment for plan/review agents (always loaded for those roles)
- `extended.md`, `guarantees.md`, `faults.md` → keep as files, reference on demand

```
unpossible-city/template-fragments/structural-vocabulary.template.md
```

Contains only `core.md` content. Extended vocabulary stays in `specifications/` and is read on demand.

#### Step 5: Glossary → template-fragment or file reference

The glossary defines canonical terms. Two options:

- **Small glossary** (< 2000 tokens): template-fragment, loaded for plan/review agents
- **Large glossary** (> 2000 tokens): keep as file, reference on demand

Given your glossary is ~7KB, keep it as a file and reference it in formula steps:
```
Read specifications/practices/glossary.md for canonical term definitions.
```

### Loading Strategy Comparison

| Practice | Unpossible Loading | Gas City Equivalent |
|---|---|---|
| cost.md | Always (all loops) | `global_fragments` in city.toml |
| version-control.md | Always (build) | Polecat prompt template |
| planning.md | Plan loop always | Mayor prompt template |
| verification.md | Plan always, build on-demand | Mayor template + polecat reads file on demand |
| changeability.md | Plan/review always, build on-demand | Mayor/refinery template + polecat reads on demand |
| coding.md | Review always, build on-demand | Refinery template + polecat reads on demand |
| security.md | Build on-demand | File read when needed |
| structural-vocabulary/core.md | Plan/review always | Mayor/refinery template |
| structural-vocabulary/extended.md | On-demand | File read when needed |
| glossary.md | Plan/review always | Mayor/refinery template (or file if too large) |

### Key Differences in Philosophy

**Unpossible** treats practices as *loadable context with explicit loading rules*. The system spec (`practices.md`) defines exactly which practice loads in which loop. This is precise but rigid — changing loading rules requires updating the spec.

**Gas City** treats template-fragments as *role-scoped prompt components*. Each agent's prompt template declares what it includes. This is flexible (each agent can have different context) but less centralized — there's no single "loading rules" document.

**The tradeoff:**
- Unpossible: One place to see all loading rules (practices.md File Map). Centralized control.
- Gas City: Loading rules are distributed across agent prompt templates. Per-role flexibility.

### What You'd Lose

1. **The File Map** — Unpossible's single table showing which practice loads where. In Gas City, you'd need to check each agent's prompt.template.md to see what's included.

2. **Frontmatter-driven loading** — Unpossible practices have `loaded_by: [plan, build]` in frontmatter. Gas City has no equivalent metadata — inclusion is determined by the template, not the file.

3. **Provider-specific caching** — Unpossible's provider adapter applies prompt caching to stable practices (cost.md, version-control.md). Gas City's caching is handled by the provider overlay system, not per-practice.

### What You'd Gain

1. **Per-role customization** — Each Gas City agent can have completely different context. A polecat working on frontend code could include different practices than one working on Go code.

2. **Template composition** — Go template syntax lets you compose fragments conditionally:
   ```
   {{ if .HasTests }}{{ template "tdd-discipline" . }}{{ end }}
   ```

3. **Pack-level reuse** — Template-fragments in a pack are available to all agents in that pack. Create an "unpossible" pack with your practices and import it into any city.

4. **No token waste on irrelevant context** — Each role gets exactly what it needs. The refinery doesn't load planning.md. The deacon doesn't load coding.md.

### Recommended Architecture

```
unpossible-city/
├── template-fragments/
│   ├── cost-management.template.md        ← from practices/cost.md
│   ├── version-control.template.md        ← from practices/version-control.md
│   ├── coding-practices.template.md       ← from practices/coding.md
│   ├── verification.template.md           ← from practices/verification.md
│   ├── planning-practices.template.md     ← from practices/planning.md
│   ├── changeability.template.md          ← from practices/changeability.md
│   └── structural-vocabulary.template.md  ← from practices/structural-vocabulary/core.md
├── city.toml
│   └── global_fragments = ["command-glossary", "operational-awareness", "cost-management"]
└── agents/  (or in a custom pack)
    ├── polecat/prompt.template.md
    │   └── includes: tdd-discipline, coding-practices, verification, version-control
    ├── mayor/prompt.template.md
    │   └── includes: planning-practices, changeability, structural-vocabulary
    └── refinery/prompt.template.md
        └── includes: coding-practices, changeability, verification

specifications/  (kept as-is, referenced on demand)
├── practices/
│   ├── security.md              ← read on demand by agents
│   ├── threat-modeling.md       ← read on demand
│   ├── retry.md                 ← read on demand
│   └── structural-vocabulary/
│       ├── extended.md          ← read on demand
│       ├── guarantees.md        ← read on demand
│       └── faults.md            ← read on demand
└── system/, skills/, etc.       ← unchanged
```

This preserves your specification hierarchy as the source of truth while using Gas City's template system for efficient context injection per role.

---

## Cost Management Strategies for Gas City

Gas City's multi-agent model is inherently more expensive than Unpossible's single-agent loop. Here's where the cost comes from and how to control it.

### Where Tokens Go

| Agent | Default Behavior | Token Burn Pattern |
|---|---|---|
| **Mayor** | Always running, idle_timeout=1h | Burns tokens on every mail check, even when idle. Propulsion principle means it acts immediately on any signal. |
| **Deacon** | Always running, idle_timeout=1h | Patrol loop with exponential backoff (30s→300s). Burns tokens every cycle checking health, even when nothing is wrong. |
| **Witness** | Always running per rig, idle_timeout=1h | Same patrol pattern as deacon. Burns tokens checking for orphans that usually don't exist. |
| **Refinery** | On-demand, idle_timeout=2h | Only active when branches are pushed. But once awake, patrols continuously. |
| **Polecats** | Pool of up to 5, idle_timeout=2h | Most efficient — spawned with work, drain when done. But each gets full context injection. |
| **Dogs** | On-demand pool | Spawned for warrants/maintenance. Short-lived. Low cost individually. |

**The expensive part isn't implementation — it's patrol.** Polecats doing actual work are cost-efficient (tokens → code). Deacon/witness/refinery burning tokens to confirm "nothing is wrong" is pure overhead.

### Cost Levers You Can Pull

#### 1. Reduce patrol agent count (biggest impact)

**Start without deacon and witness.** These are safety nets. If you're actively watching the system, you ARE the deacon/witness.

```toml
# city.toml — minimal config
# Only mayor + polecats. No deacon, no witness.
# Add them later when you're running unattended.
```

In the gastown pack, deacon/witness/boot are `mode = "always"`. Override in your city.toml or create a minimal pack that only declares mayor + polecat.

**Savings:** ~60-70% of patrol token burn eliminated.

#### 2. Reduce polecat pool size

Default `max_active_sessions = 5`. For a solo developer:

```toml
# Override in city.toml or rig config
max_active_sessions = 1  # Sequential, like Unpossible
max_active_sessions = 2  # Mild parallelism
```

Each active polecat is a full LLM session with context. Fewer = cheaper.

**Savings:** Linear — 1 polecat costs 1/5 of 5 polecats.

#### 3. Use mol-polecat-commit instead of mol-polecat-work

`mol-polecat-commit` skips the refinery entirely:
- No refinery agent needed (saves its patrol cost)
- Polecat commits directly to main and closes the bead
- Simpler flow = fewer agent sessions

**Savings:** Eliminates refinery agent entirely.

#### 4. Increase event_timeout (backoff ceiling)

Patrol agents use exponential backoff between cycles. Default caps at 300s (5 min). You can increase this:

```toml
# In formula vars or city config
event_timeout = "120"  # Start at 2 min instead of 30s
# Backoff doubles: 120s → 240s → 300s (cap)
```

Or modify the cap in your formula override. Longer backoff = fewer patrol cycles = fewer tokens.

**Savings:** Proportional to backoff increase. 2× longer backoff ≈ 50% fewer patrol tokens.

#### 5. Use cheaper models for patrol agents

Patrol agents (deacon, witness) do judgment work but don't write code. They can often use cheaper models:

```toml
# In agent.toml or city.toml provider config
# Polecats: use capable model (writes code)
# Patrol agents: use cheaper model (reads status, makes decisions)
```

Gas City supports per-agent provider configuration. Use Sonnet for polecats, Haiku for patrol.

**Savings:** 5-10× cost reduction on patrol tokens (Haiku vs Opus/Sonnet).

#### 6. Suspend rigs when not working

The mayor can suspend rigs with no active work:

```bash
gc rig suspend <rig>  # Stops witness + refinery for that rig
gc rig resume <rig>   # Restart when work is queued
```

Suspended rigs consume zero tokens. Only resume when you have beads to process.

**Savings:** 100% for suspended rigs.

#### 7. Use mol-do-work for simple tasks

`mol-do-work` is the simplest formula — read bead, implement, close. No worktree, no branch, no refinery handoff. For small tasks:

```bash
bd create "Fix typo in README"
gc sling polecat <bead-id> --on mol-do-work
```

Fewer formula steps = fewer tokens per task.

#### 8. Batch work before starting the city

Instead of running the city continuously and feeding it work one bead at a time:
1. Create all beads while the city is stopped
2. Wire dependencies
3. Start the city — polecats grind through the backlog
4. Stop the city when the backlog is empty

This eliminates idle patrol cost between tasks.

### Cost Profiles by Configuration

| Configuration | Monthly Token Estimate* | Use Case |
|---|---|---|
| **Full gastown** (mayor + deacon + witness + refinery + 5 polecats) | High (5-8 active sessions continuously) | Unattended operation, multiple rigs |
| **Lean** (mayor + 2 polecats + refinery) | Medium (3-4 sessions, refinery on-demand) | Active development with merge review |
| **Minimal** (mayor + 1 polecat, mol-polecat-commit) | Low (2 sessions, polecat ephemeral) | Solo developer, sequential work |
| **Batch** (start city → grind backlog → stop) | Lowest (pay only for active work) | Periodic batch processing |

*Actual cost depends on model choice, task complexity, and idle time.

### Comparison: Unpossible vs Gas City Cost

| | Unpossible (loop.sh) | Gas City (minimal) | Gas City (full) |
|---|---|---|---|
| Sessions during work | 1 | 2 (mayor + polecat) | 5-8 |
| Sessions while idle | 0 | 0-1 (mayor idle timeout) | 3-5 (patrol agents) |
| Context per session | ~10-20K tokens (PROMPT + specs) | ~5-15K tokens (template-fragments + formula) | Same per session, more sessions |
| Cost per beat | 1× (baseline) | 1.5-2× (mayor overhead) | 3-5× (patrol + parallel) |
| Throughput per hour | 1 beat | 1-2 beats | 3-5 beats |
| Cost per beat-hour | 1× | 0.75-1× | 0.6-1× |

**Key insight:** Gas City costs more in absolute terms but can be more cost-efficient per unit of output due to parallelism. The question is whether you have enough work to keep the machinery busy.

### Recommended Starting Configuration

For your situation (just initialized, learning the system):

```
1. Mayor only (idle_timeout = 30m)
2. 1 polecat (max_active_sessions = 1)
3. mol-polecat-commit (no refinery)
4. No deacon, no witness, no boot
5. Batch mode: create beads → start → grind → stop
```

This gives you Gas City's bead-based work tracking and formula-driven implementation at roughly the same cost as Unpossible's single-agent loop. Scale up as you gain confidence and have enough work to justify parallelism.
