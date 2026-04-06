# Implementation Plan

Generated: 2026-04-01 (gap analysis refresh)
Phase: 0 (Local Development — Docker Compose only)

> Scope: Phase 0 only. No CI, no k8s, no staging.
> Infra in scope: `infra/Dockerfile`, `infra/Dockerfile.test`, `infra/Dockerfile.runner`,
> `infra/Dockerfile.analytics`, `infra/docker-compose.yml`, `infra/docker-compose.test.yml`.

---

## Gap Analysis Notes

**Confirmed implemented:**
- `infra/Dockerfile` — multi-stage ruby:3.3-slim, non-root, port 3000 ✓
- `infra/Dockerfile.test` + `infra/entrypoint-test.sh` ✓
- `infra/docker-compose.yml` — test-only stack (test + postgres pgvector/pgvector:pg16) ✓ (needs rename)
- Rails skeleton: Gemfile, Gemfile.lock (solid_queue, no sidekiq/redis), config files ✓
- RSpec + Rubocop + SimpleCov + Lograge configured ✓
- AGENTS.md ✓ (references need updating after compose rename)
- `specs/practices/security.md` ✓

**Critical gaps:**
1. `infra/docker-compose.yml` is test-only — needs rename to `docker-compose.test.yml`; new `docker-compose.yml` for full dev stack required.
2. All domain code absent: no migrations, no modules, no lib files, no spec files beyond helpers.
3. No `loop.sh`, no `PROMPT_reflect.md`, no `PROMPT_research.md`.
4. No Go runner (`runner/`) or analytics sidecar (`analytics-sidecar/`).
5. Solid Queue not configured (no `config/queue.yml`, no `config/recurring.yml`, no migrations).
6. `practices/general/reflect.md` missing.
7. `practices/LOOKUP.md` missing (monorepo root).
8. `app/modules/LOOKUP.md` missing.
9. `specs/practices/LOOKUP.md` missing.
10. `specs/system/tasks/` does not exist — no base spec for Tasks module. Tasks spec only partially defined in `specs/platform/rails/system/` but that file is also absent. Spike required.
11. `analytics_events` needs first-class `node_id` indexed column (per analytics spec).
12. `ContainerRun` needs `stdout` and `stderr` columns (per sandbox prd.md).
13. `specs/README.md` has stale product spec references (`product/auth.md`, `product/analytics.md` don't exist at those paths).

**Spikes required:**
- `stable_ref` dedup strategy (blocks Ledger plan-file sync)
- Tasks module spec (blocks Tasks section — no base spec exists)

---

## Section 1 — Infrastructure (HIGH PRIORITY)

- [x] Create `infra/Dockerfile` (multi-stage ruby:3.3-slim, non-root, port 3000)
- [x] Create `infra/Dockerfile.test` + `infra/entrypoint-test.sh`
- [x] Configure RSpec + Rubocop + SimpleCov + Lograge
- [x] Create `AGENTS.md`
- [x] Fix Gemfile.lock — solid_queue, no sidekiq/redis

- [x] Rename docker-compose.yml → docker-compose.test.yml; create docker-compose.yml (full dev stack)
  Per `specs/system/infrastructure/spec.md`: `docker-compose.yml` = full dev stack (rails + go_runner + analytics + postgres + redis); `docker-compose.test.yml` = ephemeral test stack. Rename current file. Create new `docker-compose.yml` with: rails (ruby:3.3-slim, port 3000), go_runner (port 8080), analytics (port 9100), postgres (pgvector/pgvector:pg16, internal only), redis (redis:7-alpine, internal only). Image tags use git SHA. Update AGENTS.md and PROMPT_build.md.
  Files: `infra/docker-compose.yml` (new), `infra/docker-compose.test.yml` (renamed), `AGENTS.md`, `PROMPT_build.md`
  Required tests: `docker compose -f infra/docker-compose.test.yml run --rm test` exits 0; postgres/redis not bound to 0.0.0.0; image tags reference git SHA not `latest`

- [x] Configure Solid Queue
  Add `config.active_job.queue_adapter = :solid_queue` to `application.rb`. Create `config/queue.yml` (queues: default, knowledge, analytics, tasks, pipeline). Run solid_queue install migrations. Create `config/recurring.yml` (empty for now).
  Files: `web/config/application.rb`, `web/config/queue.yml`, `web/config/recurring.yml`, solid_queue migrations
  Required tests: job enqueued on correct queue; no Redis connection in tests

- [ ] Create `infra/Dockerfile.runner` (Go runner sidecar)
  Multi-stage golang:1.22-alpine builder → alpine:3.19 final, non-root, port 8080. Depends on Section 10.
  Files: `infra/Dockerfile.runner`
  Required tests: `docker build -f infra/Dockerfile.runner .` exits 0; `/healthz` returns 200

- [ ] Create `infra/Dockerfile.analytics` (Go analytics sidecar)
  Multi-stage golang:1.22-alpine builder → alpine:3.19 final, non-root, port 9100. Depends on Section 11.
  Files: `infra/Dockerfile.analytics`
  Required tests: `docker build -f infra/Dockerfile.analytics .` exits 0; `/healthz` returns 200


## Section 2 — Security Foundation

- [x] Create `Secret` value object
  `web/app/lib/secret.rb`. Overrides `inspect`, `to_s`, `as_json` → `"[REDACTED]"`. `.expose` returns raw value.
  Files: `web/app/lib/secret.rb`, `web/spec/lib/secret_spec.rb`
  Required tests: inspect → "[REDACTED]"; to_s → "[REDACTED]"; as_json → "[REDACTED]"; expose → raw value; JSON serialization redacted

- [x] Create `Security::LogRedactor`
  `web/app/lib/security/log_redactor.rb`. Regex patterns for OpenAI `sk-...`, `Bearer ...`, PEM headers, AWS `AKIA...`, JWT `eyJ...` → `[REDACTED:<type>]`. Plugged into lograge initializer.
  Files: `web/app/lib/security/log_redactor.rb`, `web/config/initializers/lograge.rb` (update), `web/spec/lib/security/log_redactor_spec.rb`
  Required tests: JWT redacted; OpenAI key redacted; PEM header redacted; normal lines pass through

- [x] Create `Security::PromptSanitizer`
  `Security::PromptSanitizer.sanitize(text)` — gitleaks patterns + PII (email→`[EMAIL]`, phone→`[PHONE]`, IP→`[IP]`). Logs warning on match. Called by every provider adapter.
  Files: `web/app/lib/security/prompt_sanitizer.rb`, `web/spec/lib/security/prompt_sanitizer_spec.rb`
  Required tests: email redacted; phone redacted; OpenAI key redacted; clean text passes; match triggers audit log warning

- [x] Configure rack-attack rate limiting
  Throttle by IP, return 429 on limit exceeded.
  Files: `web/config/initializers/rack_attack.rb`, `web/spec/config/initializers/rack_attack_spec.rb`
  Required tests: >N requests from same IP → 429; normal traffic passes

- [x] Configure brakeman and bundler-audit Rake tasks
  Files: `web/lib/tasks/security.rake`
  Required tests: `bundle exec brakeman --exit-on-warn` exits 0; `bundle exec bundler-audit check --update` exits 0


## Section 3 — Core Module Structure & Auth

- [x] Scaffold module directory structure + LOOKUP.md files
  Create `app/modules/{knowledge,tasks,agents,sandbox,analytics}/` each with `models/`, `services/`, `jobs/`, `controllers/` subdirs. Create `web/app/modules/LOOKUP.md` (maps all five modules to paths and public interfaces). Create `specs/practices/LOOKUP.md` (maps: Secret, cache_control, RALPH_COMPLETE, Ultrathink, module boundary, audit on destructive, effort parameter, ENV.fetch, filter_parameters, rack-attack, shared service pattern).
  Files: module `.keep` files, `web/app/modules/LOOKUP.md`, `specs/practices/LOOKUP.md`
  Required tests: each module namespace resolves without NameError; both LOOKUP.md files exist with required entries

- [x] Create JWT authentication
  `web/app/lib/auth_token.rb` — encode/decode JWT with `org_id`, `user_id`, `exp`. `ApplicationController#authenticate!` sets `current_org_id`/`current_user_id`. `X-Sidecar-Token` header for Go sidecar (from `SIDECAR_TOKEN` env var). `POST /api/auth/token` issues tokens (Phase 0: shared secret from `AUTH_SECRET` env var).
  Files: `web/app/lib/auth_token.rb`, `web/app/controllers/application_controller.rb` (update), `web/app/controllers/api/auth_controller.rb`, `web/config/routes.rb` (update), `web/spec/lib/auth_token_spec.rb`, `web/spec/requests/api/auth_spec.rb`
  Required tests: valid JWT authenticates; expired → 401; tampered → 401; missing → 401; valid sidecar token authenticates; wrong sidecar token → 401; POST /api/auth/token with valid secret returns JWT


## Section 4 — Ledger Module (blocks Sections 5–8)

- [ ] [SPIKE] Research stable_ref dedup strategy — run `./loop.sh research stable-ref` (see specs/skills/tools/research.md)
  Open question from `specs/system/ledger/spec.md`: agent title drift breaks SHA256(normalize(title)+parent_id). Candidates: semantic dedup, fuzzy matching, human-in-the-loop, canonical title enforcement. Spike must produce a recommendation.
  Blocks: Ledger::PlanFileSyncService, activity-log backfill.

- [x] Create `Node` model and migration
  Schema per `specs/system/ledger/spec.md`: id (uuid), kind (enum: question/answer), answer_type (enum: terminal/generative, nullable), scope (enum: intent/code/deployment/ui/interaction), body (text), title (string), spec_path (string, nullable), author (enum: human/agent/system), stable_ref (string, indexed), version (int, default 1), status (enum: open/in_progress/blocked/closed), resolution (enum: done/duplicate/deferred/wont_do/icebox, nullable), accepted (enum: true/false/pending, nullable), accepted_by (jsonb, default []), acceptance_threshold (int, default 1), conflict (boolean, default false), conflict_disk_state (text, nullable), conflict_db_state (text, nullable), org_id (uuid), recorded_at (timestamptz), originated_at (timestamptz, nullable). Indexes: (org_id, scope, status), stable_ref.
  Files: `web/app/modules/ledger/models/node.rb`, migration, `web/spec/models/ledger/node_spec.rb`, factory
  Required tests: kind/scope enums validate; answer immutable after creation; terminal answer rejects child question; generative answer allows children; accepted defaults to pending; version increments on status transition; org_id present; factory valid

- [ ] Create `NodeEdge` model and migration
  Schema: id (uuid), parent_id (FK→nodes), child_id (FK→nodes), edge_type (enum: contains/depends_on/refs), ref_type (string, nullable), primary (boolean, default false). Indexes: (parent_id, edge_type), (child_id, edge_type).
  Files: `web/app/modules/ledger/models/node_edge.rb`, migration, `web/spec/models/ledger/node_edge_spec.rb`, factory
  Required tests: edge_type validates; ref_type nullable; primary flag works; fan-in works; depends_on blocks in_progress transition

- [ ] Create `ActorProfile` and `Actor` models and migrations
  ActorProfile: id, name, provider, model, allowed_tools (jsonb, default []), prompt_template (text, nullable), org_id. Actor: id, actor_profile_id (FK), node_id (FK→nodes), tools_used (jsonb, default []), created_at.
  Files: models, migrations, factories
  Required tests: allowed_tools defaults []; tools_used defaults []; Actor belongs_to ActorProfile and Node; factories valid

- [ ] Implement `Ledger::NodeLifecycleService`
  Enforces: question cannot move to in_progress while depends_on question not closed; generative answer children not opened until acceptance_threshold reached; false verdict re-opens parent; true verdict closes when threshold met; terminal answer rejects child creation; version increments on every status transition.
  Files: `web/app/modules/ledger/services/node_lifecycle_service.rb`, `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb`
  Required tests: UAT-1 (question lifecycle); UAT-2 (dependency enforcement); UAT-3 (generative answer opens children); re-opens on false verdict; version increments; terminal blocks child creation

- [ ] Create `Ledger::NodesController`
  GET /api/nodes (filter by scope, status, resolution, author, parent_id), POST /api/nodes, GET /api/nodes/:id, POST /api/nodes/:id/verdict, POST /api/nodes/:id/comments. All JWT auth.
  Files: `web/app/modules/ledger/controllers/ledger/nodes_controller.rb`, routes update, `web/spec/requests/ledger/nodes_spec.rb`
  Required tests: GET filters; POST creates question; verdict true closes when threshold met; verdict false re-opens; comment triggers IndexerJob; unauthenticated → 401; answer immutable → 422 on update

- [ ] Create `Ledger::SpecWatcherJob`
  Polls `specs/**/*.md` every 10s. New file → create Node (scope: intent, status: open). Changed file → parse status header, apply. Deleted file → resolution: deferred. Git revert detected → conflict: true, never auto-resolve. After any change → enqueue Knowledge::IndexerJob.
  Files: `web/app/modules/ledger/jobs/spec_watcher_job.rb`, `web/spec/modules/ledger/jobs/spec_watcher_job_spec.rb`
  Required tests: new file creates Node; changed file updates status; deleted → deferred; git revert → conflict: true; IndexerJob enqueued; idempotent

- [ ] Implement `Ledger::PlanFileSyncService` — BLOCKED by stable_ref spike
  Reads IMPLEMENTATION_PLAN.md. For each checkbox: compute stable_ref, look up. If found, no-op. If not, create Node (scope: code). Checked → closed. Orphaned nodes flagged, not deleted. Idempotent.
  Files: `web/app/modules/ledger/services/plan_file_sync_service.rb`, `web/spec/modules/ledger/services/plan_file_sync_service_spec.rb`
  Required tests: UAT-4 (plan file sync); unchecked → open; checked → closed; re-sync = no duplicates; removed → orphaned; idempotent

