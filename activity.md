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

---

## 2026-04-18 14:08 — Task 1.1: Annotate Go sidecar stubs in docker-compose.yml (tag 0.0.59)

**Changes:**
- Added "Phase 0: Go sidecars not yet built" comment block above commented-out `go_runner` and `analytics` service stubs in `infra/docker-compose.yml`
- References tasks 8.2 and 8.6 as the unlock conditions
- `docker compose config` validates without errors; 271 examples, 0 failures

**Thinking:**
- Straightforward annotation. The stubs were already commented out; the task only required making the intent explicit so future readers don't wonder whether they were accidentally disabled.

**Challenges:**
- None. The change is purely documentary.

**Alternatives considered:**
- Deleting the stubs entirely: cleaner file, but loses the service shape as a reference when Go sidecars are eventually built. Annotation preserves intent at zero cost.

**Tradeoffs taken:**
- Commented-out code is normally dead code (delete it). Here it's a scaffold placeholder for a known future service — the annotation makes that distinction explicit. If the Go sidecars are never built, the stubs should be deleted at that point.

---

## 2026-04-18 14:17 — Task 2.1: Wire limits_concurrency in AgentRunJob (tag 0.0.60)

**Changes:**
- Added `limits_concurrency to: 1, key: ..., duration: 30.minutes` macro to `AgentRunJob`
- Key lambda calls `concurrency_key_for(run_id: agent_run_id.to_s, source_ref: source_ref)` using job arguments
- Updated `RunStorageService#start` and `#record_input` to pass `source_ref` as second arg to `perform_later`
- Updated `perform` signature to accept optional `_source_ref` (ignored — only needed for the key)
- Added 3 new tests: `concurrency_limit` is 1, key uses source_ref when present, falls back to run_id string
- Updated `record_input` re-enqueue test to assert `.with(run.id, run.source_ref)`
- 274 examples, 0 failures, 99.41% coverage

**Thinking:**
- Solid Queue's `limits_concurrency` key lambda is called via `instance_exec(*arguments)` — so it receives the job's `perform_later` arguments as positional params
- The key needs `source_ref` at enqueue time, but `perform` only received `agent_run_id` (DB integer). Two options: DB lookup in the lambda, or pass source_ref as a second argument. Passing it is cheaper (no extra query) and makes the concurrency key deterministic without I/O
- `_source_ref` in `perform` is intentionally ignored — it's only there so Solid Queue can deserialize the job correctly; the actual run lookup uses `agent_run_id`

**Challenges:**
- Needed to inspect the Solid Queue gem source (`active_job/concurrency_controls.rb`) to confirm the lambda receives `*arguments` via `instance_exec`, not the job instance. The public docs don't spell this out clearly
- `concurrency_key_for` uses `run_id` (UUID string) as fallback, but the job argument is the DB integer id. Used `.to_s` on the integer — unique enough for a fallback key since DB ids are unique per run

**Alternatives considered:**
- DB lookup in the key lambda: `AgentRun.find(agent_run_id)&.source_ref || agent_run_id.to_s` — works but adds a query at enqueue time, and the run may not be committed yet in edge cases
- Pass `run.run_id` (UUID) instead of `run.id` (integer): more semantically correct as a fallback, but requires changing the `perform` signature to accept UUID and look up by it — unnecessary complexity

**Tradeoffs taken:**
- The service-layer concurrent run check in `RunStorageService` is now redundant with the queue-level control, but both are kept: the service check gives an immediate 409 to the caller; the queue-level control handles the case where two jobs are enqueued before either starts executing
- `duration: 30.minutes` is a guess — if agent runs routinely exceed 30 minutes, a second job for the same source_ref could slip through. Should be revisited when real run durations are known
