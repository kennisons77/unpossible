# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 19 iterations — initial planning pass, gap analysis, Rails skeleton + test infra, Sidekiq/Redis + Rubocop + SimpleCov fixes, gap analysis refresh x2, Gemfile.lock fix solid_queue, gap analysis refresh + IMPLEMENTATION_PLAN.md rewrite, docker-compose rename + full dev stack, Solid Queue configuration, Secret value object, Security::LogRedactor, Security::PromptSanitizer, rack-attack rate limiting, brakeman + bundler-audit Rake tasks, scaffold module directory structure + LOOKUP.md files (tag 0.0.8), JWT authentication (tag 0.0.9), Ledger::Node model + migration (tag 0.0.10), Ledger::NodeEdge model + migration (tag 0.0.11)]

---

## 2026-04-02 04:35 — Create Ledger::ActorProfile and Ledger::Actor models and migrations

**Mode:** Build
**Iteration:** 20
**Status:** Complete

**Task:** Section 4 — Create `ActorProfile` and `Actor` models and migrations

**Actions:**
- Created `web/db/migrate/20260402000003_create_ledger_actor_profiles.rb` — UUID PK, name/provider/model strings, allowed_tools jsonb default [], prompt_template nullable text, org_id uuid; index on org_id
- Created `web/db/migrate/20260402000004_create_ledger_actors.rb` — UUID PK, actor_profile_id FK, node_id FK, tools_used jsonb default [], created_at only
- Created `web/app/modules/ledger/models/actor_profile.rb` — `Ledger::ActorProfile` with presence validations
- Created `web/app/modules/ledger/models/actor.rb` — `Ledger::Actor` with belongs_to :actor_profile and :node
- Created `web/spec/factories/ledger_actor_profiles.rb`
- Created `web/spec/factories/ledger_actors.rb`
- Created `web/spec/models/ledger/actor_profile_spec.rb`
- Created `web/spec/models/ledger/actor_spec.rb`
- Tagged v0.0.12

**Acceptance criteria met:**
- allowed_tools defaults [] ✓
- tools_used defaults [] ✓
- Actor belongs_to ActorProfile and Node ✓
- factories valid ✓
- 108 examples, 0 failures, 100% line coverage ✓
