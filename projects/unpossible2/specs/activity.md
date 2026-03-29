# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 2 iterations — initial planning pass (28 tasks) and gap analysis (expanded to 58 tasks, resolved 5 ambiguities)]

---

## 2026-03-29 17:33 — Rails App Skeleton + Test Infra

**Mode:** Build
**Iteration:** 3
**Status:** Complete
**Tag:** 0.0.19

**Actions:**
- Created Rails 8 full-stack app skeleton under `projects/unpossible2/app/`
- Gemfile with all required gems: rails 8, pg, pgvector, rspec-rails, factory_bot_rails, shoulda-matchers, simplecov, lograge, sidekiq, redis, jwt, rack-attack, brakeman, bundler-audit, rubocop-rails-omakase
- RSpec configured with DatabaseCleaner, FactoryBot, Shoulda Matchers
- SimpleCov 90% minimum (skipped on empty suite — enforced once code exists)
- Rubocop configured with rubocop-performance, rubocop-rails, rubocop-rspec
- `infra/Dockerfile.test` + `infra/docker-compose.yml` for test stack (pgvector/pgvector:pg16 + redis:7-alpine)
- `AGENTS.md` with build/run/test commands and codebase patterns
- `docker compose run --rm test` exits 0 on empty suite

**Gotchas:**
- `ruby:3.3-slim` ships Ruby 3.3.11 — use `ruby '~> 3.3'` in Gemfile, not exact patch
- `psych` gem requires `libyaml-dev` in Dockerfile.test (not included in ruby:3.3-slim)
- Docker Desktop was not running — started with `open -a Docker`; socket at `~/.docker/run/docker.sock`
- Nested ERB in `database.yml` (`<%= ... <%= Rails.env %> %>`) is invalid — use flat ERB with env var

**Tasks completed:** Create Rails app skeleton, Create AGENTS.md

---
