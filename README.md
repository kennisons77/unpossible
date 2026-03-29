# unpossible

A reusable bootstrap template for AI-assisted development based on the dev work of Clayton Farr and its inventor Geoffrey Huntley. The **Ralph Wiggum Loop** — an autonomous Claude loop that reads your specs, executes tasks one at a time, commits code, and iterates until done.

Generated code runs in Docker, so the loop works with **any language or framework** — Claude writes the `Dockerfile` based on your specs and all tests run inside the container.

## What is the Ralph Wiggum Loop?

Each loop iteration:
1. Claude reads your spec files (`specs/prd.md`, `specs/plan.md`, `specs/activity.md`)
2. Picks the next unchecked task from `IMPLEMENTATION_PLAN.md`
3. Writes code to `app/`, updates `infra/` as needed, runs tests via `docker compose`
4. Commits on green, marks the task complete, logs to `specs/activity.md`
5. Repeats until all tasks are done (outputs `RALPH_COMPLETE`)

The loop uses `--dangerously-skip-permissions` so Claude auto-approves all tool calls. Run it in a throwaway environment or a branch you can review before merging.

## Quickstart

### Development

To set the initial requirementschat locally with clause in a Docker sandbox as described [here](https://docs.docker.com/ai/sandboxes/get-started/).
Rename the template directory to your project name.

Start our sandbox
```bash
cd [my-project]
docker sandbox run unpossible
```

List active sandboxes:
```bash
docker sandbox ls
```

Access a running sandbox:
```bash
docker sandbox exec -it <sandbox-name> bash
```

Remove a sandbox:
```bash
docker sandbox rm <sandbox-name>
```

```bash
# 1. Copy this template
cp -r unpossible my-project
cd my-project
git init && git add -A && git commit -m "init from unpossible template"

# 2. Fill in your specs
$EDITOR specs/prd.md          # What are you building? Declare your language + base image here.
$EDITOR specs/plan.md         # What are the tasks?

# 3. (Optional) Run a planning pass to let Claude fill in IMPLEMENTATION_PLAN.md
./loop.sh plan 1

# 4. Run the build loop
./loop.sh                     # unlimited iterations
./loop.sh 20                  # or cap at 20
```

## File Structure

```
.
├── loop.sh                    # The runner — feeds prompts to Claude in a loop
├── PROMPT_plan.md             # Prompt for planning mode (gap analysis + IMPLEMENTATION_PLAN.md)
├── PROMPT_build.md            # Prompt for build mode (implement, test via docker, commit)
├── AGENTS.md                  # How to build/run/test THIS project (filled in by agent)
├── IMPLEMENTATION_PLAN.md     # Agent's working memory — updated each iteration
│
├── app/                       # All generated application code lives here
│
├── infra/
│   ├── Dockerfile             # Agent fills in FROM, deps, CMD from specs/prd.md
│   ├── docker-compose.yml     # `app` service (run) + `test` service (tests)
│   └── k8s/
│       └── deployment.yaml    # Kubernetes Deployment + Service (agent maintains)
│
├── practices/                 # Coding standards — loaded selectively, not every iteration
│   ├── general/
│   │   ├── coding.md          # Language-agnostic rules (comments, naming, structure)
│   │   ├── planning.md        # How to analyze specs and produce a plan (incl. JTBD scope test)
│   │   ├── verification.md    # Backpressure, LLM-as-judge, test discipline
│   │   └── prompting.md       # Load-bearing word choices for editing PROMPT_*.md files
│   ├── lang/
│   │   ├── go.md              # Go-specific patterns (add your language here)
│   │   ├── rust.md
│   │   └── ruby.md
│   └── framework/             # Framework-specific patterns (agent creates as needed)
│
└── specs/
    ├── audience.md            # Audiences, JTBDs, story map, current target SLC release
    ├── prd.md                 # Technical constraints (language, base image, test command, port)
    ├── [activity].md          # One spec per activity — acceptance criteria drive required tests
    ├── plan.md                # High-level human checklist (agent maintains IMPLEMENTATION_PLAN.md)
    ├── activity.md            # Agent activity log (auto-updated each iteration)
    ├── testing.md             # Testing strategy
    └── README.md              # Explains the specs directory and how to write good specs
```

## Usage

```bash
./loop.sh              # Build mode, unlimited iterations
./loop.sh 20           # Build mode, max 20 iterations
./loop.sh plan         # Plan mode, unlimited iterations
./loop.sh plan 1       # Plan mode, 1 iteration (dry run / gap analysis)
```

**Plan mode** reads your specs, scans `app/`, and updates `IMPLEMENTATION_PLAN.md` without writing any code — useful for reviewing Claude's understanding before letting it loose.

**Build mode** implements tasks, tests via `docker compose run --rm test`, and commits after each green run.

## Phase 1: Define Requirements (before running the loop)

This is human + LLM work done in a normal conversation — not in the loop. The goal is to produce
`specs/audience.md` and a set of activity spec files before Ralph touches any code.

### 1. Define your audience and their JTBDs
Open `specs/audience.md` and fill in:
- **Audiences** — who is this built for?
- **Jobs to Be Done** — what outcomes do they want? (why they'd use this, not what features it has)

### 2. Map activities and capability depths
For each JTBD, identify the activities users perform to accomplish it. Activities are **verbs** in
a user journey, not system capabilities:

```
✓  "upload photo"  →  specs/upload-photo.md
✗  "image system"  →  too broad, bundles multiple activities
```

For each activity, define capability depths (basic → enhanced → advanced). These become the rows
of your story map.

### 3. Draw your story map and choose a release slice
Arrange activities as columns, capability depths as rows. A horizontal slice is a candidate release:

```
UPLOAD      →   EXTRACT     →   ARRANGE     →   SHARE

basic           auto                            export        ← Release 1: Palette Picker
────────────────────────────────────────────────────────
                palette         manual                        ← Release 2: Mood Board
────────────────────────────────────────────────────────
batch           AI themes       templates       embed         ← Release 3: Design Studio
```

Mark your **Current target release** in `specs/audience.md`. The planning agent uses this to
scope `IMPLEMENTATION_PLAN.md` to that slice only — not the entire feature space.

A good release slice is **Simple** (narrow scope), **Lovable** (people actually want it),
and **Complete** (fully accomplishes a job — not a broken preview).

### 4. Write activity specs
One `specs/[activity-name].md` per activity in your target release. Each spec describes:
- What the user does and why
- **Acceptance criteria** — observable outcomes, not implementation details
- Capability depth in scope for this release

The acceptance criteria become the required tests the planning agent derives tasks from.

### 5. Fill in technical constraints
Complete `specs/prd.md` Technical Constraints: Language, Framework, Base image, Test command, Port.

Then run the loop.

## Setup Checklist

Before running the loop:

- [ ] Fill in `specs/audience.md` — audiences, JTBDs, activities, story map, current target release
- [ ] Write one `specs/[activity].md` per activity in the target release, with acceptance criteria
- [ ] Fill in `specs/prd.md` — **Language**, **Base image**, **Test command**, **Port**
- [ ] Ensure your repo has a remote (the loop pushes after each iteration)
- [ ] Docker is running locally (the loop builds and tests inside containers)

You do **not** need the target language installed locally — only Docker.

## How Language Flexibility Works

`specs/prd.md` declares the runtime:

```markdown
## Technical Constraints
- Language: Python 3.12
- Framework: FastAPI
- Base image: python:3.12-slim
- Test command (in container): pytest
- Port: 8080
```

On the first iteration, Claude reads these fields and fills in `infra/Dockerfile` and `infra/docker-compose.yml`. All subsequent test runs happen inside the container via:

```bash
docker compose -f infra/docker-compose.yml run --rm test
```

The loop itself is language-agnostic — swap in `node:20-alpine` + `npm test`, `golang:1.22-alpine` + `go test ./...`, or any other image and the rest of the template stays the same.

## Kubernetes

`infra/k8s/deployment.yaml` is maintained by the agent as the app evolves. For local clusters (kind, minikube), `imagePullPolicy: Never` lets you use locally-built images without a registry. For real deployments, update the `image:` field to a registry path and remove that flag.

## Operating the Loop

The loop works best when you sit *on* it, not *in* it. Your job is to observe and adjust, not to direct each step.

### Let it run
The loop is designed for eventual consistency — trust it to self-correct through iteration. Resist the urge to intervene after every imperfect output. If the agent makes a wrong turn, the next iteration often self-corrects; if it doesn't, that's the signal to act.

### When to regenerate the plan
`IMPLEMENTATION_PLAN.md` is disposable state, not a source of truth. Regenerate it freely:
```bash
./loop.sh plan 1
```
Regenerate when: the agent seems off-track, the plan has accumulated clutter, specs changed significantly, or the agent appears confused about what's complete.

### Tuning prompts
When the agent fails in a *specific, repeatable* way, add one targeted line to `PROMPT_build.md` or `PROMPT_plan.md` addressing that exact failure. Don't rewrite the whole prompt — small, precise additions compound well. See `practices/general/prompting.md` for the word choices that matter.

### Backpressure is the control mechanism
The agent cannot mark a task complete until tests, typechecks, and lints pass. This is intentional — it is the only reliable way to enforce correctness across a fresh context window every iteration. If the validation suite is weak, the loop produces the appearance of progress. Invest in tests before running the loop at scale.

### Emergency stops
- `Ctrl+C` stops the loop immediately
- `git reset --hard` reverts any uncommitted changes
- The loop only pushes after a successful commit, so remote state is always green

## Tips

- **Context budget**: Claude's 200K context window yields ~176K truly usable tokens. Every file loaded every iteration costs from that budget — keep specs, prompts, and practices files lean. Brevity compounds.
- **Markdown over JSON** for any files the agent reads — it tokenizes more efficiently.
- **Keep specs lean.** Every spec file loads into every loop iteration. Shorter = cheaper.
- **One task per iteration.** The loop is designed for focused, verifiable increments.
- **Review `specs/activity.md`** to see what the agent did in each iteration.
- **Model choice**: `loop.sh` defaults to `--model opus`. Opus costs more per call but reasons better, leading to fewer total iterations. For well-defined build tasks you can edit `loop.sh` to use `sonnet`.
- **Git history is your audit trail.** The agent commits after each passing task.
