# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 16 iterations — initial planning pass, gap analysis, Rails skeleton + test infra (tag 0.0.19), Sidekiq/Redis + Rubocop + SimpleCov fixes (tag 0.0.20), gap analysis refresh x2, Gemfile.lock fix solid_queue (tag 0.0.1), gap analysis refresh + IMPLEMENTATION_PLAN.md rewrite, docker-compose rename + full dev stack, Solid Queue configuration, Secret value object, Security::LogRedactor, Security::PromptSanitizer, rack-attack rate limiting, brakeman + bundler-audit Rake tasks, scaffold module directory structure + LOOKUP.md files (tag 0.0.8)]

---

## 2026-04-02 03:46 — Create JWT authentication

**Mode:** Build
**Iteration:** 17
**Status:** Complete

**Task:** Section 3 — Create JWT authentication

**Actions:**
- Created `app/app/lib/auth_token.rb` — `AuthToken.encode/decode` with HS256, `ExpiredToken`/`InvalidToken` error classes
- Updated `app/app/controllers/application_controller.rb` — `authenticate!` reads `Authorization: Bearer` or `X-Sidecar-Token`; renders 401 on failure
- Created `app/app/controllers/api/auth_controller.rb` — `POST /api/auth/token` issues JWT when shared secret matches `AUTH_SECRET`
- Created `app/spec/support/test_authenticated_controller.rb` — test-only controller for request specs
- Updated `app/spec/rails_helper.rb` — auto-requires `spec/support/**/*.rb`
- Created `app/spec/lib/auth_token_spec.rb` (5 examples)
- Created `app/spec/requests/api/auth_spec.rb` (9 examples)
- Added `AUTH_SECRET` and `SIDECAR_TOKEN` to `infra/docker-compose.test.yml`
- Tagged v0.0.9

**Acceptance criteria met:**
- Valid JWT authenticates ✓
- Expired → 401 ✓
- Tampered → 401 ✓
- Missing → 401 ✓
- Valid sidecar token authenticates ✓
- Wrong sidecar token → 401 ✓
- POST /api/auth/token with valid secret returns JWT ✓
- 56 examples, 0 failures, 100% line coverage ✓

---

## 2026-04-02 04:00 — Create Ledger::Node model and migration

**Mode:** Build
**Iteration:** 18
**Status:** Complete

**Task:** Section 4 — Create `Node` model and migration

**Actions:**
- Created `app/db/migrate/20260402000001_create_ledger_nodes.rb` — UUID PK, all schema fields per spec, indexes on stable_ref and (org_id, scope, status)
- Created `app/app/modules/ledger.rb` — Ledger namespace module
- Created `app/app/modules/ledger/models/node.rb` — `Ledger::Node` with enum validations, answer immutability, answer_type/status constraints, `before_validation` defaults
- Created `app/app/modules/ledger/{controllers,jobs,services}/.keep` directories
- Updated `app/config/application.rb` — added Zeitwerk collapse for module subdirs (models/, services/, jobs/, controllers/) so `Ledger::Node` resolves correctly
- Created `app/spec/factories/ledger_nodes.rb` — factory with :answer, :terminal_answer, :generative_answer traits
- Created `app/spec/models/ledger/node_spec.rb` (27 examples)
- Tagged v0.0.10

**Acceptance criteria met:**
- kind/scope enums validate ✓
- answer immutable after creation ✓
- terminal answer identified correctly ✓
- generative answer allows children ✓
- accepted defaults to pending ✓
- version defaults to 1 ✓
- org_id present ✓
- factory valid ✓
- 83 examples, 0 failures, 100% line coverage ✓
