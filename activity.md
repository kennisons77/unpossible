# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 75 iterations — initial planning through 0.0.57. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash across all adapters.]

---

## 2026-04-18 14:04 — Task 2.6b: Scope set_agent_run to current_org_id (tag 0.0.58)

Scoped `AgentRunsController#set_agent_run` to `current_org_id` for JWT auth; unscoped for sidecar. Added cross-org 404 test. 271 examples, 0 failures, 99.41% coverage.

---

## 2026-04-18 14:08 — Task 1.1: Annotate Go sidecar stubs in docker-compose.yml (tag 0.0.59)

Added "Phase 0: Go sidecars not yet built" comment block above commented-out stubs. References tasks 8.2 and 8.6 as unlock conditions.

---

## 2026-04-18 14:17 — Task 2.1: Wire limits_concurrency in AgentRunJob (tag 0.0.60)

Added `limits_concurrency to: 1` macro. Key uses source_ref (falls back to run_id). Updated RunStorageService to pass source_ref as second arg. 274 examples, 0 failures, 99.41% coverage.

---

## 2026-04-18 14:23 — Task 2.2: Implement call_provider on all three adapters (tag 0.0.61)

ClaudeAdapter and OpenAiAdapter via Net::HTTP. KiroAdapter via Open3.capture3. Added webmock + dependencies. 20 new tests. 290 examples, 0 failures, 99.46% coverage.

---

## 2026-04-18 14:31 — Task 2.3: Add agent_override flag to AgentRun (tag 0.0.62)

Migration + model attribute + AgentRunJob bypass. Extracted `load_enrichment` method. 5 new tests. 296 examples, 0 failures, 99.47% coverage.

---

## 2026-04-21 13:35 — Task 2.4: Create LlmMetric on agent run completion (tag 0.0.63)

`RunStorageService.complete` now creates `Analytics::LlmMetric`. 297 examples, 0 failures, 99.47% coverage.

---

## 2026-04-21 13:41 — Planning loop: regenerate IMPLEMENTATION_PLAN.md

Deleted old plan, gap-analyzed specs vs code at tag 0.0.63. Key findings:
- Bug: FeatureFlagsController#create permits org_id from params instead of using current_org_id (task 1.1)
- rswag not installed — no OpenAPI docs or swagger UI (tasks 2.1–2.6)
- Batch request middleware not implemented (task 3.1)
- Agent runner skill assembly stub not filled in (task 5.1)
- No Go code exists — sidecars and reference graph parser deferred behind spike (tasks 8.1–8.5)
- No schema.rb/structure.sql committed (task 7.3)
- Proposed specs (analytics dashboard UI, agent runs UI, log tail relay, repo map) deferred — status proposed/draft
- Infrastructure verified: postgres not exposed, image tags use git SHA, health check works

## 2026-04-21 13:48 — Task 1.1: Fix FeatureFlagsController#create org_id from JWT (tag 0.0.64)

**Changes:** Removed `:org_id` from `create_params` permitted list. Merged `current_org_id` from token into new flag attributes. Added three new tests: org_id set from token, org_id in params ignored, 401 without auth. 299 examples, 0 failures, 99.47% coverage.

**Thinking:**
- The bug was a classic mass-assignment privilege escalation: permitting `org_id` from params lets any authenticated caller create a flag scoped to any org they choose.
- Fix is minimal: remove `:org_id` from `permit`, add it via `merge(org_id: current_org_id, ...)` — same pattern already used by `index` and `set_flag`.
- The existing tests passed because they happened to pass the correct org_id in params, masking the vulnerability.

**Challenges:**
- No challenge in the fix itself. The test update required removing `org_id` from `valid_params` and adding an explicit cross-org test to prove the param is ignored.

**Alternatives considered:**
- Keeping `org_id` in params but validating it matches `current_org_id` — rejected: unnecessary complexity, the token is the authoritative source.
- Adding a model-level validation that org_id matches the token — rejected: the controller is the right boundary; model doesn't know about the request context.

**Tradeoffs taken:**
- None. This is a pure security fix with no tradeoffs. The `org_id` in params is silently ignored rather than returning a 422 — acceptable because callers should not be sending it at all, and a 422 would break existing clients that happen to include it.
