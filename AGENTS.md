# AGENTS.md — Unpossible

Operational reference. Build/run/test commands and codebase patterns only.
Progress notes belong in IMPLEMENTATION_PLAN.md.

## Build / Run / Test

```bash
# Build test image
docker compose -f infra/docker-compose.test.yml build

# Run test suite
docker compose -f infra/docker-compose.test.yml run --rm test

# Run a specific spec
docker compose -f infra/docker-compose.test.yml run --rm test bundle exec rspec spec/path/to/spec.rb

# Start full dev stack
GIT_SHA=$(git rev-parse --short HEAD) docker compose -f infra/docker-compose.yml up
```

## Adding New Gems

Docker containers have no outbound internet access. All gems must be pre-downloaded to `web/vendor/cache/` on the host before building:

```bash
# Download a new gem and its platform-specific variant (if any)
curl -sf -o web/vendor/cache/<name>-<version>.gem \
  https://rubygems.org/gems/<name>-<version>.gem
```

Then update `web/Gemfile` and `web/Gemfile.lock`, and rebuild the image.

## Codebase Patterns

| Concept | Location | Notes |
|---|---|---|
| Rails app root | `web/` | All Ruby source |
| Infra config | `infra/` | Dockerfiles, compose files |
| Module code | `web/app/modules/{name}/` | agents, sandbox, analytics |
| Specs | `web/spec/` | RSpec, FactoryBot, Shoulda Matchers |
| Initializers | `web/config/initializers/` | lograge.rb, rack_attack.rb |
| DB migrations | `web/db/migrate/` | Rails migrations |
| Lib | `web/app/lib/` | Secret, AuthToken, Security::* |

## SQL NULL Gotcha

`where.not(column: value)` generates `WHERE column != value` which excludes NULLs in PostgreSQL.
Use `where("column IS NULL OR column != ?", value)` when NULLs should be included.

## Docker Context

The project uses Docker Desktop (desktop-linux context). If Docker Desktop is not running,
start it with `open -a Docker` and wait ~10s for the socket to appear at
`~/.docker/run/docker.sock`.

## Sandbox Limitation

The agent runs in a sandboxed environment that cannot see or reach the host's Docker daemon.
**Never attempt to check container status, run `docker compose` commands, or verify running
services from within the agent.** The dev stack (Rails, Postgres, sidecars) runs exclusively
on the host machine. All Docker operations — starting the stack, checking logs, running
migrations, verifying container health — must be performed by the developer on the host.
Do not assume you can observe or interact with running services.

## Key Environment Variables (test container)

| Variable | Default | Purpose |
|---|---|---|
| `DB_HOST` | `postgres` | Postgres hostname |
| `POSTGRES_USER` | `unpossible` | DB user |
| `POSTGRES_PASSWORD` | `unpossible` | DB password |
| `POSTGRES_DB` | `unpossible_test` | Test DB name |
| `RAILS_ENV` | `test` | Rails environment |

## Agent Configs

Agent configs live in `.kiro/agents/`. Each config references resource files that are
injected as context. If a referenced file is renamed or moved, update the agent config
in the same commit.

| Agent            | Config                              | Resources                                                          | Model          |
|------------------|-------------------------------------|--------------------------------------------------------------------|----------------|
| `ralph_build`    | `.kiro/agents/ralph_build.json`     | AGENTS.md, cost.md, version-control.md, skills/**/*.md             | sonnet-4.6     |
| `ralph_plan`     | `.kiro/agents/ralph_plan.json`      | AGENTS.md, cost.md, planning.md, verification.md, changeability.md, structural-vocabulary.md, skills/**/*.md | auto           |
| `ralph_research` | `.kiro/agents/ralph_research.json`  | AGENTS.md, cost.md, skills/**/*.md                                 | auto           |
| `ralph_review`   | `.kiro/agents/ralph_review.json`    | AGENTS.md, cost.md, changeability.md, coding.md, structural-vocabulary.md, skills/**/*.md | auto           |
| `interview`      | `.kiro/agents/interview.json`       | specifications/README.md, AGENTS.md, cost.md, skills/**/*.md                | auto           |
| `review`         | `.kiro/agents/review.json`          | specifications/README.md, AGENTS.md, cost.md, changeability.md, coding.md, structural-vocabulary.md, skills/**/*.md | auto |

## Server Operations

| Service | Health endpoint | Log command |
|---|---|---|
| Rails | `GET /up` | `docker compose logs rails` |
| Postgres | `pg_isready` | `docker compose logs postgres` |
