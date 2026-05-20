# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 108 iterations — initial planning through 0.0.63, then tasks 1.1–2.6, analytics dashboard UI (0.0.86), db/schema.rb (0.0.87), FeatureFlag hypothesis validation (0.0.85), analytics ingest sidecar (0.0.89), Go reference parser research spike (0.0.96), Go reference parser binary (0.0.97), PR skill script (0.0.98), repo-map CLI (0.0.99). Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire, DashboardController), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash, LlmMetric on completion, rswag install, FeatureFlagsController org_id fix, all rswag spec conversions, db/schema.rb hand-crafted from migrations, Go analytics sidecar, Go reference parser, PR skill script, repo-map CLI binary.]

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
