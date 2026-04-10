# AGENTS.md — Unpossible 2

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

# Start full dev stack (requires Dockerfile.runner and Dockerfile.analytics)
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
| Module code | `web/app/modules/{name}/` | knowledge, tasks, agents, sandbox, analytics |
| Specs | `web/spec/` | RSpec, FactoryBot, Shoulda Matchers |
| Initializers | `web/config/initializers/` | lograge.rb, rack_attack.rb |
| DB migrations | `web/db/migrate/` | Rails migrations |
| Lib | `web/app/lib/` | Secret, AuthToken, Security::* |
| Ledger jobs | `web/app/modules/ledger/jobs/` | SpecWatcherJob polls specs/**/*.md every 10s |

## SQL NULL Gotcha

`where.not(column: value)` generates `WHERE column != value` which excludes NULLs in PostgreSQL.
Use `where("column IS NULL OR column != ?", value)` when NULLs should be included.

## Docker Context

The project uses Docker Desktop (desktop-linux context). If Docker Desktop is not running,
start it with `open -a Docker` and wait ~10s for the socket to appear at
`~/.docker/run/docker.sock`.

## Key Environment Variables (test container)

| Variable | Default | Purpose |
|---|---|---|
| `DB_HOST` | `postgres` | Postgres hostname |
| `POSTGRES_USER` | `unpossible2` | DB user |
| `POSTGRES_PASSWORD` | `unpossible2` | DB password |
| `POSTGRES_DB` | `unpossible2_test` | Test DB name |
| `RAILS_ENV` | `test` | Rails environment |

## Server Operations

| Service | Health endpoint | Log command |
|---|---|---|
| Rails | `GET /up` | `docker compose logs rails` |
| Postgres | `pg_isready` | `docker compose logs postgres` |
