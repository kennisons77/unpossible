# Unpossible

An evolving platform for AI-assisted software development. It runs ralph loops (plan, build, review, reflect) against projects, stores everything those loops produce, and uses that evidence to improve itself over time.

Unpossible is both the platform and its own first project — it develops itself using its own loops.

## Stack

- Ruby 3.3 / Rails 8 (full stack)
- PostgreSQL 16 + pgvector
- Solid Queue (no Redis/Sidekiq)
- Go 1.22 runner sidecar
- Docker Compose (Phase 0 — local only)

## Quickstart

```bash
# Build test image
docker compose -f infra/docker-compose.yml build

# Run test suite
docker compose -f infra/docker-compose.yml run --rm test

# Run a specific spec
docker compose -f infra/docker-compose.yml run --rm test bundle exec rspec spec/path/to/spec.rb
```

## The Ralph Wiggum Loop

Each loop iteration:
1. Claude reads your spec files and picks the next unchecked task from `IMPLEMENTATION_PLAN.md`
2. Writes code to `app/`, updates `infra/` as needed, runs tests via `docker compose`
3. Commits on green, marks the task complete, logs to `activity.md`
4. Repeats until all tasks are done (outputs `RALPH_COMPLETE`)

```bash
make build       # Build loop, unlimited iterations
make build1      # Build loop, 1 iteration
make plan        # Plan loop, unlimited iterations
make plan1       # Plan loop, 1 iteration (gap analysis / dry run)
make reflect     # Reflect loop
make research    # Research loop
```

## File Structure

```
.
├── IMPLEMENTATION_PLAN.md   # Agent's working memory
├── AGENTS.md                # Build/run/test commands and codebase patterns
├── PROMPT_build.md          # Prompt for build mode
├── PROMPT_plan.md           # Prompt for plan mode
├── activity.md              # Agent activity log (last 10 entries)
├── Makefile                 # Loop and skill targets
│
├── app/                     # Rails application
│   └── app/modules/
│       ├── knowledge/       # Vector store, MD indexing, context retrieval
│       ├── ledger/          # Universal data model — nodes, edges, questions, answers
│       ├── agents/          # Agent run storage, prompt dedup, JWT auth
│       ├── sandbox/         # Container lifecycle, Docker dispatcher
│       └── analytics/       # LLM metrics, audit log, feature flags
│
├── infra/
│   ├── Dockerfile           # Rails app image (ruby:3.3-slim)
│   ├── Dockerfile.test      # Test image
│   ├── Dockerfile.runner    # Go runner sidecar (golang:1.22-alpine)
│   ├── Dockerfile.analytics # Go analytics sidecar
│   ├── docker-compose.yml   # Full dev stack
│   └── docker-compose.test.yml  # Ephemeral test stack
│
└── specs/
    ├── project-prd.md       # Technical constraints and phase model
    ├── system/              # Platform internals specs
    ├── platform/rails/      # Rails-specific overrides
    ├── practices/           # Discipline rules
    └── skills/              # Agent instructions
```

## Phase

Phase 0 — Local development. Docker Compose only. No CI, no staging, no production config.
