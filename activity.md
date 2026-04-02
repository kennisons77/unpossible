# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 6 iterations — initial planning pass, gap analysis (58 tasks, 5 ambiguities resolved), Rails app skeleton + test infra (tag 0.0.19), Sidekiq/Redis + Rubocop + SimpleCov fixes (tag 0.0.20), gap analysis refresh, full gap analysis + IMPLEMENTATION_PLAN.md full refresh]

---

## 2026-04-01 15:23 — Fix Gemfile.lock: solid_queue replaces sidekiq/redis

**Mode:** Build
**Iteration:** 7
**Status:** Complete
**Tag:** 0.0.1

**Actions:**
- Restored Gemfile.lock from git (was deleted from working tree)
- Removed `sidekiq`, `redis`, `redis-client` from Gemfile.lock GEM specs and DEPENDENCIES
- Added `solid_queue 1.4.0`, `fugit 1.12.1`, `et-orbi 1.4.0`, `raabro 1.4.0` to Gemfile.lock
- Updated Dockerfile.test: switched from `ruby:3.3-slim` (no build tools) to `ruby:3.3` (full image with gcc, libpq-dev, libyaml-dev pre-installed); removed apt-get step
- Downloaded all 112 gems to `app/vendor/cache`; Dockerfile.test uses `bundle install --local` (no network required in Docker build)
- Removed `REDIS_URL` env var and Redis service row from AGENTS.md
- Fixed `sidekiq.rb` initializer reference in AGENTS.md codebase patterns table
- Tests pass: `bundle exec rspec` exits 0; `bundle list` shows solid_queue 1.4.0, no sidekiq or redis

**Gotchas:**
- virtiofs mount corrupts large binary files (>~8MB) on write — large .deb packages downloaded to virtiofs path were silently zeroed out; only /tmp (tmpfs) is reliable for large binary downloads
- Docker containers have no outbound internet access in this environment; all gems must be pre-downloaded to vendor/cache on the host
- `ruby:3.3-slim` has no build tools and apt-get can't reach Debian repos; use `ruby:3.3` (full) which ships with gcc, libpq-dev, libyaml-dev
- Gemfile.lock DEPENDENCIES section must match Gemfile exactly — stale lock with sidekiq/redis in DEPENDENCIES causes bundler to fail even if GEM specs are correct

**Tasks completed:** Fix Gemfile.lock — resolve solid_queue, remove sidekiq
