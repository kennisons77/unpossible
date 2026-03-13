# unpossible

A reusable bootstrap template for AI-assisted development using the **Ralph Wiggum Loop** — an autonomous Claude loop that reads your specs, executes tasks one at a time, commits code, and iterates until done.

## What is the Ralph Wiggum Loop?

Each loop iteration:
1. Claude reads your spec files (`specs/prd.md`, `specs/plan.md`, `specs/activity.md`)
2. Picks the next unchecked task from `specs/plan.md`
3. Implements it, runs tests, commits
4. Marks the task complete and logs to `specs/activity.md`
5. Repeats until all tasks are done (outputs `RALPH_COMPLETE`)

The loop uses `--dangerously-skip-permissions` so Claude auto-approves all tool calls. Run it in a throwaway environment or a branch you can review before merging.

## Quickstart

```bash
# 1. Copy this template
cp -r unpossible my-project
cd my-project
git init && git add -A && git commit -m "init from unpossible template"

# 2. Fill in your specs
$EDITOR specs/prd.md       # What are you building?
$EDITOR specs/plan.md      # What are the tasks?
$EDITOR AGENTS.md          # How do you build/test this project?

# 3. (Optional) Run a planning pass first
./loop.sh plan 1

# 4. Run the build loop
./loop.sh                  # unlimited iterations
./loop.sh 20               # or cap at 20
```

## File Structure

```
.
├── loop.sh              # The runner — feeds prompts to Claude in a loop
├── PROMPT_plan.md       # Prompt for planning mode (analyzes specs, updates plan)
├── PROMPT_build.md      # Prompt for build mode (implements tasks, commits)
├── AGENTS.md            # How to build/run/test THIS project (filled in by you or the agent)
├── IMPLEMENTATION_PLAN.md  # Agent's working memory — updated each iteration
└── specs/
    ├── prd.md           # Product requirements (fill this in)
    ├── plan.md          # Task checklist (fill this in)
    ├── activity.md      # Agent activity log (auto-updated)
    ├── testing.md       # Testing strategy for this project
    └── README.md        # Explains the specs directory
```

## Usage

```bash
./loop.sh              # Build mode, unlimited iterations
./loop.sh 20           # Build mode, max 20 iterations
./loop.sh plan         # Plan mode, unlimited iterations
./loop.sh plan 1       # Plan mode, 1 iteration (dry run)
```

**Plan mode** reads your specs and updates `IMPLEMENTATION_PLAN.md` without writing any code — useful for reviewing the agent's understanding before letting it loose.

**Build mode** implements tasks from `IMPLEMENTATION_PLAN.md`, runs tests, and commits after each task.

## Setup Checklist

Before running the loop:

- [ ] Fill in `specs/prd.md` — describe what you're building, your tech stack, and what "done" looks like
- [ ] Fill in `specs/plan.md` — break work into discrete, testable tasks
- [ ] Fill in `AGENTS.md` — document how to build, run, and test your project
- [ ] Update `specs/testing.md` — describe your testing approach and commands
- [ ] Ensure your repo has a remote (the loop pushes after each iteration)

## Tips

- **Keep specs lean.** Every spec file loads into every loop iteration. Shorter = cheaper.
- **One task per iteration.** The loop is designed for focused, verifiable increments.
- **Review `specs/activity.md`** to see what the agent did in each iteration.
- **Model choice**: `loop.sh` defaults to `--model opus`. Opus costs more per call but reasons better, leading to fewer total iterations. For well-defined build tasks you can edit `loop.sh` to use `sonnet`.
- **Git history is your audit trail.** The agent commits after each passing task.
