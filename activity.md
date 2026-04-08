# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 29 iterations — initial planning pass, gap analysis, Rails skeleton + test infra, Sidekiq/Redis + Rubocop + SimpleCov fixes, gap analysis refresh x3, Gemfile.lock fix solid_queue, docker-compose rename + full dev stack, Solid Queue configuration, Secret value object, Security::LogRedactor, Security::PromptSanitizer, rack-attack rate limiting, brakeman + bundler-audit Rake tasks, scaffold module directory structure + LOOKUP.md files (tag 0.0.8), JWT authentication (tag 0.0.9), Ledger::Node model + migration (tag 0.0.10), Ledger::NodeEdge model + migration (tag 0.0.11), Ledger::ActorProfile + Ledger::Actor models + migrations (tag 0.0.12), Ledger::NodeLifecycleService (tag 0.0.13), Ledger::NodesController (tag 0.0.14), Ledger::PlanFileSyncService (tag 0.0.15), gap analysis + IMPLEMENTATION_PLAN.md refresh (iteration 24), Ledger bug fixes (tag 0.0.23, iteration 25), ledger-node-audit-event-spec (tag 0.0.23, iteration 26), ledger-audit-events + ledger-node-level-fix + ledger-ui-request-specs (tag 0.0.24, iteration 27), gap analysis refresh + IMPLEMENTATION_PLAN.md rewrite (iteration 28), Task 8.1: AUTH_SECRET env var extraction (iteration 29)]

---

## 2026-04-07 15:57 — Task 9.1: Rewrite NodesController#comment to create comment nodes

**Mode:** Build
**Iteration:** 30
**Status:** Complete

**Tasks completed:**
- Rewrote `NodesController#comment` from stub to full implementation
- Comments now create answer nodes (kind: answer, answer_type: terminal, scope: intent)
- Created `contains` edge linking comment to parent node
- Removed incorrect guard rejecting comments on answer nodes — comments attach to any node
- Missing body returns 422
- `Knowledge::IndexerJob` enqueued with parent node ID after comment creation
- Rewrote comment specs: 7 examples covering creation, edge, IndexerJob, answer node comments, missing body, auth
- Also includes uncommitted Task 8.1 changes (AUTH_SECRET env var extraction in docker-compose.yml)
- Full test suite passes (215 examples, 0 failures, 93.96% coverage)

**Changes:**
- `web/app/modules/ledger/controllers/nodes_controller.rb` — comment action rewrite
- `web/spec/requests/ledger/nodes_spec.rb` — comment spec rewrite
- `infra/docker-compose.yml` — AUTH_SECRET/SIDECAR_TOKEN/DEFAULT_ORG_ID env vars (from 8.1)
- `IMPLEMENTATION_PLAN.md` — marked 9.1 complete

---

## 2026-04-07 16:02 — Tasks 9.2, 9.3, 9.4: Ledger test gaps (attach_research, research blocking, dependency enforcement on accepted)

**Mode:** Build
**Iteration:** 31
**Status:** Complete
**Tag:** v0.0.16

**Tasks completed:**
- 9.2: Added 3 tests for `NodeLifecycleService.attach_research` — creates code-scoped question, status proposed, research edge to parent
- 9.3: Added 2 tests for research spike blocking on `accepted` transition — blocks when open spike exists, allows when closed
- 9.4: Added 2 tests for dependency enforcement on `accepted` transition — blocks when dependency not closed, allows when closed
- Full test suite passes (222 examples, 0 failures, 95.41% coverage)

**Changes:**
- `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb` — 7 new test examples
- `IMPLEMENTATION_PLAN.md` — marked 9.2, 9.3, 9.4 complete

---

## 2026-04-07 16:45 — Task 9.5: Add MarkdownHelper spec + fix escape_html and Rouge regex

**Mode:** Build
**Iteration:** 32
**Status:** Complete
**Tag:** 0.0.25

**Tasks completed:**
- Added `spec/helpers/markdown_helper_spec.rb` (6 examples: blank input, markdown rendering, syntax highlighting, tables, XSS escaping, html_safe)
- Fixed bug: Redcarpet renderer missing `escape_html: true` — raw `<script>` tags passed through unescaped
- Fixed bug: Rouge highlighting regex matched `class="language-(\w+)"` but Redcarpet outputs `class="(\w+)"` — syntax highlighting never applied
- Also committed previously uncommitted 9.2-9.4 test additions
- Full test suite passes (228 examples, 0 failures, 96.38% coverage)

**Changes:**
- `web/spec/helpers/markdown_helper_spec.rb` — new file
- `web/app/helpers/markdown_helper.rb` — escape_html + regex fix
- `web/spec/modules/ledger/services/node_lifecycle_service_spec.rb` — uncommitted 9.2-9.4 tests
- `IMPLEMENTATION_PLAN.md` — marked 9.5 complete
