# AGENTS.md — Unpossible 2

Operational reference. Build/run/test commands and codebase patterns only.
Progress notes belong in IMPLEMENTATION_PLAN.md.

## Build / Run / Test

```bash
# Build test image
docker compose -f projects/unpossible2/infra/docker-compose.test.yml build

# Run test suite
docker compose -f projects/unpossible2/infra/docker-compose.test.yml run --rm test

# Run a specific spec
docker compose -f projects/unpossible2/infra/docker-compose.test.yml run --rm test bundle exec rspec spec/path/to/spec.rb

# Start full dev stack (requires Dockerfile.runner and Dockerfile.analytics)
GIT_SHA=$(git rev-parse --short HEAD) docker compose -f projects/unpossible2/infra/docker-compose.yml up
```

## Adding New Gems

Docker containers have no outbound internet access. All gems must be pre-downloaded to `app/vendor/cache/` on the host before building:

```bash
# Download a new gem and its platform-specific variant (if any)
curl -sf -o projects/unpossible2/app/vendor/cache/<name>-<version>.gem \
  https://rubygems.org/gems/<name>-<version>.gem
```

Then update `app/Gemfile` and `app/Gemfile.lock`, and rebuild the image.

## Codebase Patterns

| Concept | Location | Notes |
|---|---|---|
| Rails app root | `projects/unpossible2/app/` | All Ruby source |
| Infra config | `projects/unpossible2/infra/` | Dockerfiles, compose files |
| Module code | `app/app/modules/{name}/` | knowledge, tasks, agents, sandbox, analytics |
| Specs | `app/spec/` | RSpec, FactoryBot, Shoulda Matchers |
| Initializers | `app/config/initializers/` | lograge.rb, rack_attack.rb |
| DB migrations | `app/db/migrate/` | Rails migrations |
| Lib | `app/app/lib/` | Secret, AuthToken, Security::* |

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
