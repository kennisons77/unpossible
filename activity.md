# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 108 iterations — initial planning through 0.0.63, then tasks 1.1–2.6, analytics dashboard UI (0.0.86), db/schema.rb (0.0.87), FeatureFlag hypothesis validation (0.0.85), analytics ingest sidecar (0.0.89), Go reference parser research spike (0.0.96), Go reference parser binary (0.0.97), PR skill script (0.0.98), repo-map CLI (0.0.99). Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire, DashboardController), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash, LlmMetric on completion, rswag install, FeatureFlagsController org_id fix, all rswag spec conversions, db/schema.rb hand-crafted from migrations, Go analytics sidecar, Go reference parser, PR skill script, repo-map CLI binary.]

---

## 2026-05-20 09:40 — Analytics dashboard UI (tasks 6.3, 6.4, tag 0.0.101)

**Changes:** Implemented `Analytics::DashboardController` with `index` (summary cards: weekly cost/runs/failure rate, cost by provider/model table, recent 20 runs) and `llm` (cost/token breakdown by provider/model with date range filter). Added routes `/analytics` and `/analytics/llm`. Updated nav layout to include Analytics link. 7 new request specs; 374 total, 0 failures, 98.75% coverage.

**Thinking:**
- The spike (6.3) confirmed all dependencies exist: `LlmMetric`, `AgentRun`, layout CSS, auth pattern. No new gems needed.
- The `index` action reuses the same aggregation logic as `MetricsController#summary` and `MetricsController#llm` but renders HTML instead of JSON. No duplication — the controller queries directly rather than calling the JSON controller.
- The `llm` action mirrors `MetricsController#llm` with date range filtering, rendered as a table with a date picker form.
- Nav link added to the shared layout so both HTML UIs are discoverable from any page.

**Challenges:**
- Root cause of 503: `HealthCheckMiddleware` has `rescue StandardError` at the method level, which wraps `@app.call(env)`. Any unhandled exception from the Rails app returns 503 instead of propagating as 500. The `@cost_by_provider` query selected `SUM(cost_estimate_usd) AS total_cost_usd` etc. but the view called `row.call_count` — a method that didn't exist on the result objects. This raised `NoMethodError` (a `StandardError`), which the middleware caught and returned 503. Fix: add `COUNT(*) AS call_count` to the SELECT.
- The 503 was hard to diagnose because the direct Rack test returned 200 (no data in DB, so the `@cost_by_provider` loop never executed). Only when an `LlmMetric` existed did the view iterate and hit the missing method.
- `git add -A` again swept in unrelated files. Caught and removed via `git rm --cached` + `git commit --amend`.

**Alternatives considered:**
- Calling `MetricsController` actions internally and rendering the JSON as data — rejected. Adds coupling between controllers and requires parsing JSON in the view layer.
- Separate `SummaryController` and `LlmController` — rejected. The spec defines two views under `/analytics`; one controller with two actions is the natural Rails mapping.

**Tradeoffs taken:**
- `HealthCheckMiddleware` rescue behavior is a latent bug: any unhandled exception from the app returns 503 instead of 500. This makes debugging harder. The fix here was to eliminate the exception, not fix the middleware. A future beat should narrow the rescue to only the `SELECT 1` call.
- The `index` view queries `Agents::AgentRun` directly from the `Analytics` module. This crosses the module boundary (analytics querying agents). Acceptable for Phase 0 — the spec explicitly says "Depends on Analytics::LlmMetric and Agents::AgentRun models." A future beat could introduce a cross-module service interface.

---

## 2026-05-19 23:06 — Agent runs HTML UI (tasks 6.1, 6.2, tag 0.0.100)

**Changes:** Implemented `AgentRunsHtmlController` with `index` (paginated, filterable by mode/status) and `show` (run metadata + ordered turns). Created `application.html.erb` layout (first HTML views in the project). Turn content rendered via existing `MarkdownHelper`. Routes: `GET /agent_runs`, `GET /agent_runs/:id`. 8 new request specs; 367 total, 0 failures, 98.71% coverage.

**Thinking:**
- The spike (6.1) confirmed all needed gems (`redcarpet`, `rouge`) and helpers (`MarkdownHelper`) already existed. No new dependencies needed.
- Inline CSS in the layout is appropriate here: no asset pipeline, no CSS framework, and this is the only layout in the project. A separate stylesheet would require asset pipeline configuration that doesn't exist yet.
- The HTML controller sits alongside the JSON `AgentRunsController` — same module, different controller. This keeps the module boundary clean without mixing HTML and JSON concerns in one controller.
- Auth reuses `ApplicationController#authenticate!` exactly as specified — same JWT + sidecar + DISABLE_AUTH bypass. No new auth logic.
- Pagination is offset-based with a 25-item page size. Simple and sufficient for Phase 0 local use.

**Challenges:**
- `git add -A` swept in untracked files (`polyai-questions.html`, `unpossible-city/`) that were sitting in the repo root. Caught immediately and removed via `git rm --cached` + `git commit --amend`. Lesson: stage specific paths or check `git status` before committing.
- No existing layout to follow — had to establish the first one. Chose a minimal dark-theme monospace design consistent with a developer tool.

**Alternatives considered:**
- Separate stylesheet file — rejected. No asset pipeline configured; inline CSS avoids that complexity entirely for Phase 0.
- Reusing the JSON controller with `respond_to` format blocks — rejected. Mixing HTML and JSON in one controller violates single responsibility and makes the auth/render logic harder to follow.
- Tailwind or other CSS framework — rejected. No existing framework in the project; adding one is Phase N+1 scope.

**Tradeoffs taken:**
- Inline CSS means styling is duplicated if a second layout is ever added. Acceptable for Phase 0 — there's only one layout and the CSS is small (~60 lines).
- Offset pagination doesn't handle concurrent inserts gracefully (items can shift between pages). Acceptable for a local dev tool with low write volume.
- Parent run lookup in the show view does a DB query per render (`AgentRun.find_by`). For Phase 0 with single-user local use this is fine; would need eager loading if the view were high-traffic.

---

## 2026-05-20 11:43 — Log tail relay implementation (task 7.2, tag 0.0.102)

**Changes:** Added `logs-snapshot` Makefile target writing last 100 lines of a service's logs to `.data/logs-snapshot.txt`. `SERVICE` variable selects the service (default: rails). Documented the read path in AGENTS.md. No Ruby code changes — infrastructure-only. 374 tests, 0 failures, 98.75% coverage unchanged.

**Thinking:**
- The spike (7.1) established the approach: file relay via a Makefile target. Implementation is a direct translation of the spike findings.
- `$(or $(SERVICE),rails)` is the idiomatic Make way to default a variable — avoids a separate `ifdef` block.
- `@mkdir -p` ensures `.data/` exists even on a fresh clone before the first snapshot.
- The agent container mounts `..:/workspace`, so the snapshot is at `/workspace/.data/logs-snapshot.txt` in the agent — not `/.data/logs-snapshot.txt` (which is the rails container's mount). AGENTS.md documents the correct agent-container path.

**Challenges:**
- The spike notes said the agent reads `/.data/logs-snapshot.txt`. That's the rails container's mount path. The agent container mounts the whole repo at `/workspace`, so the correct path is `/workspace/.data/logs-snapshot.txt`. Caught by re-reading the compose file before writing the docs.

**Alternatives considered:**
- Separate `logs-snapshot-rails` and `logs-snapshot-postgres` targets — rejected. A single target with a `SERVICE` variable is more composable and follows the pattern of other Makefile targets in the project.
- Writing to `.data/snapshots/logs-snapshot.txt` — rejected. The spike spec says `.data/logs-snapshot.txt` (flat, not nested). Keeping it flat makes the path easier to remember and document.

**Tradeoffs taken:**
- The snapshot overwrites on each call — no history. Acceptable: the use case is "show me what's happening now," not log archival.
- `docker compose logs --tail=100` includes ANSI color codes if the service emits them. The agent reads the file as plain text — color codes appear as escape sequences. Acceptable for Phase 0; a `--no-color` flag could be added if it becomes noisy.

**Changes:** Researched three log relay approaches (file relay, HTTP sidecar, clipboard/pipe). Recorded findings in IMPLEMENTATION_PLAN.md, marked 7.1 complete, added 7.2 implementation task.

**Thinking:**
- The agent container already mounts `../.data:/.data` — any file written to `.data/` on the host is immediately visible to the agent at `/.data/`. No new infrastructure needed.
- File relay via `make logs-snapshot` is the minimal, correct solution: developer-triggered (opt-in), bounded (tail N lines), no Docker socket exposure, no new sidecar.
- The `.data/snapshots/` directory already exists, confirming the pattern is established.

**Challenges:**
- None. The existing volume mount made the answer obvious once confirmed.

**Alternatives considered:**
- HTTP sidecar with Docker socket access — rejected. Requires a new container, new port, new service in compose. Overkill for a single-user local tool.
- Clipboard/pipe CLI integration — rejected. Doesn't work in non-interactive agent sessions (the primary use case).

**Tradeoffs taken:**
- File relay is pull-based (developer must run `make logs-snapshot`). The agent cannot proactively fetch logs. This is intentional — the spec says "opt-in (developer initiates or approves the relay)." If proactive log access is needed later, the HTTP sidecar approach is the upgrade path.
- Snapshot is a point-in-time file, not a live stream. Sufficient for debugging boot failures and migration errors; not suitable for watching live output.
