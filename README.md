# unpossible

A reusable bootstrap template for AI-assisted development using the **Ralph Wiggum Loop** — an autonomous Claude loop that reads your specs, executes tasks one at a time, commits code, and iterates until done.

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
└── specs/
    ├── prd.md                 # Product requirements — MUST include base image + test command
    ├── plan.md                # Task checklist
    ├── activity.md            # Agent activity log (auto-updated)
    ├── testing.md             # Testing strategy
    └── README.md              # Explains the specs directory
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

## Setup Checklist

Before running the loop:

- [ ] Fill in `specs/prd.md` — include **Language**, **Base image**, **Test command**, and **Port**
- [ ] Fill in `specs/plan.md` — break work into discrete, testable tasks
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

## Tips

- **Keep specs lean.** Every spec file loads into every loop iteration. Shorter = cheaper.
- **One task per iteration.** The loop is designed for focused, verifiable increments.
- **Review `specs/activity.md`** to see what the agent did in each iteration.
- **Model choice**: `loop.sh` defaults to `--model opus`. Opus costs more per call but reasons better, leading to fewer total iterations. For well-defined build tasks you can edit `loop.sh` to use `sonnet`.
- **Git history is your audit trail.** The agent commits after each passing task.
