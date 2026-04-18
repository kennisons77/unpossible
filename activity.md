# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 75 iterations — initial planning through 0.0.57. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash across all adapters, IMPLEMENTATION_PLAN.md regenerated.]

---

## 2026-04-17 16:33 — parse_response normalisation (tag 0.0.57)

**Changes:**
- `ClaudeAdapter#parse_response`: returns `{text:, input_tokens:, output_tokens:, stop_reason:}` from Anthropic response shape
- `KiroAdapter#parse_response`: same shape, same Anthropic-style response
- `OpenAiAdapter#parse_response`: same shape, maps from OpenAI choices/usage fields
- `provider_adapter_spec.rb`: replaced string-return tests with hash-return tests; added missing-field graceful handling tests for all three adapters
- 270 RSpec examples, 0 failures, 99.21% coverage

---

## 2026-04-18 14:04 — Task 2.6b: Scope set_agent_run to current_org_id (tag 0.0.58)

**Changes:**
- `AgentRunsController#set_agent_run`: scopes lookup to `current_org_id` when JWT-authenticated; falls back to unscoped for sidecar auth (current_org_id nil)
- Added cross-org 404 test for `/input` endpoint
- Fixed existing `input` spec: factory now creates run with `org_id: org_id` so JWT-scoped lookup succeeds
- 271 examples, 0 failures, 99.41% coverage

**Thinking:**
- The `complete` action uses sidecar auth, which sets `current_org_id = nil` — scoping by nil would always 404
- The `input` action uses JWT auth, which sets `current_org_id` — scoping is correct and required
- Single `set_agent_run` handles both: scope when org_id present, unscoped when nil (sidecar)
- This is the minimal change: no new methods, no auth refactor

**Challenges:**
- The existing `input` spec created the run without `org_id: org_id`, so after scoping it would have returned 404 on the happy path — caught and fixed in the same change
- Sidecar auth intentionally has no org_id (it's a system-level token, not user-scoped), so the nil-check is load-bearing

**Alternatives considered:**
- Separate `set_agent_run_jwt` and `set_agent_run_sidecar` before_actions: more explicit but duplicates the rescue block and adds indirection for a two-line difference
- Scope `complete` by org_id too, requiring sidecar to pass org_id in the request: would require API contract change and sidecar update — disproportionate for Phase 0

**Tradeoffs taken:**
- Sidecar can access any org's run via `complete` — acceptable because sidecar token is a shared secret controlled by the platform, not a user credential
- If we ever add per-org sidecar tokens, `complete` will need scoping too — the nil-check makes that future change obvious
