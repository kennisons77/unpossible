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

## 2026-04-18 14:31 — Task 2.3: Add agent_override flag to AgentRun (tag 0.0.62)

**Changes:**
- Migration: `add_column :agents_agent_runs, :agent_override, :boolean, null: false, default: false`
- `AgentRun`: `attribute :agent_override, :boolean, default: false` with explanatory comment
- `AgentRunJob`: extracted `load_enrichment` private method; bypass it when `run.agent_override` is true; callable tools still passed regardless
- 5 new tests: model defaults, model accepts true/false, job skips enrichment on override, job still completes run on override, job calls load_enrichment when override is false
- 296 examples, 0 failures, 99.47% coverage

**Thinking:**
- The spec says "enrichment tools skipped, callable tools still passed." Enrichment = context_chunks + principles loading. Callable tools are a separate concern (passed to the provider as tool definitions). The current job passes empty arrays for both — extracting `load_enrichment` makes the bypass point explicit and positions task 2.6 (skill assembly) cleanly: it only needs to fill in `load_enrichment`.
- `attribute :agent_override, :boolean, default: false` is redundant with the DB default but makes the model self-documenting and ensures the attribute is typed correctly in memory before a DB round-trip.

**Challenges:**
- No real challenges. The enrichment path is currently a stub (returns `[[], []]`), so the override branch and the non-override branch produce identical behavior today. The test for "calls load_enrichment when override is false" uses `expect(job).to receive(:load_enrichment)` to verify the code path is taken, not the output.

**Alternatives considered:**
- Inline the bypass in `perform` without extracting `load_enrichment`: saves one method but makes task 2.6 harder — the skill assembler would need to be wired into `perform` directly with no clear seam.
- Store `agent_override` as a jsonb metadata field instead of a column: avoids a migration but makes querying and validation harder. A boolean column is the right type for a boolean flag.

**Tradeoffs taken:**
- `load_enrichment` currently returns `[[], []]` regardless of the run — it's a stub. When task 2.6 is implemented, it will do real work. The override flag correctly bypasses it even now (no-op bypass of a no-op), which is correct behavior.
- The `attribute` declaration in the model is technically redundant with the DB column. If the column is ever removed, the attribute declaration would silently persist as an in-memory-only attribute. Low risk for a boolean flag.

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

---

## 2026-04-21 13:35 — Task 2.4: Create LlmMetric on agent run completion (tag 0.0.63)

**Changes:**
- `RunStorageService.complete` now calls `Analytics::LlmMetric.create!` after updating the run record
- Reads `org_id`, `provider`, `model`, `id` from the run; reads `input_tokens`, `output_tokens`, `cost_estimate_usd` from the updated run attributes
- Added test: completing a run creates an LlmMetric with correct org_id, provider, model, agent_run_id, input_tokens, output_tokens, cost_estimate_usd
- 297 examples, 0 failures, 99.47% coverage

**Thinking:**
- `RunStorageService.complete` is the single point where a run transitions to `completed` — the right place to create the metric. Putting it in the controller would duplicate the logic if `complete` is ever called from a job or another service path.
- Reading token/cost values from `run` after `update!` (not from `attrs` directly) ensures the metric reflects what was actually persisted, not what was passed in.

**Challenges:**
- None. The LlmMetric model and migration already existed; this was purely wiring the creation call into the completion path.

**Alternatives considered:**
- Creating the metric in `AgentRunsController#complete`: would work but couples the metric creation to the HTTP layer. If `complete` is ever called from a background job, the metric would be missed.
- Using an ActiveRecord callback (`after_update`) on `AgentRun`: more implicit, harder to test in isolation, and would fire on any status update (not just completion).

**Tradeoffs taken:**
- `LlmMetric.create!` is fail-closed — if it raises, the `complete` call fails and the run is not marked completed. This is intentional: a missing metric is a data integrity problem, not a side-effect. If this becomes too strict (e.g., metric creation fails due to a transient DB issue), it can be wrapped in a rescue and logged, but that decision should be explicit.

---

## 2026-04-18 14:23 — Task 2.2: Implement call_provider on all three adapters (tag 0.0.61)

**Changes:**
- `ClaudeAdapter#call_provider`: HTTP POST to `api.anthropic.com/v1/messages` via `Net::HTTP`, API key from `ANTHROPIC_API_KEY` wrapped in `Secret`, returns error hash on any exception without raising
- `OpenAiAdapter#call_provider`: HTTP POST to `api.openai.com/v1/chat/completions`, `Authorization: Bearer` from `OPENAI_API_KEY` Secret, same error handling
- `KiroAdapter#call_provider`: subprocess via `Open3.capture3("kiro-cli", "chat", "--no-interactive", "--trust-all-tools", "--", input)`, returns error hash on non-zero exit or missing binary
- Added `webmock`, `rexml`, `addressable`, `crack`, `hashdiff`, `public_suffix` to Gemfile/vendor/cache for HTTP stubbing in tests
- 20 new tests in `call_provider_spec.rb`: correct endpoint, headers, API key injection, parsed response, error handling, API key not in error output
- 290 examples, 0 failures, 99.46% coverage

**Thinking:**
- `Net::HTTP` is stdlib — no new gem needed for Claude and OpenAI. The spec says "Call provider HTTP API directly (no sidecar)" and the Gemfile had no HTTP client gem, so stdlib was the right choice
- Kiro is a CLI tool, not an HTTP API. The `kiro.md` provider spec shows `kiro-cli chat --no-interactive --trust-all-tools -- "$PROMPT"`. Using `Open3.capture3` with an array of args (not a shell string) avoids shell injection
- API keys are wrapped in `Secret` at the call site so they never appear in `inspect`, `to_s`, or error messages — the `expose` call happens only at the HTTP header assignment line

**Challenges:**
- `crack` gem (a WebMock dependency for XML parsing) requires `rexml`, which is a stdlib gem that must be explicitly required in Ruby 3.x. The `ruby:3.3-slim` base image doesn't bundle it. Had to add `rexml` as an explicit gem dependency and download it to vendor/cache
- WebMock blocks all real HTTP by default when required — this is the desired behavior for tests, but required adding `stub_request` calls for every HTTP-touching test

**Alternatives considered:**
- Using `Faraday` or `HTTParty` for HTTP: cleaner API but adds a gem dependency with no benefit over `Net::HTTP` for simple POST calls
- Mocking `Net::HTTP` directly with RSpec doubles instead of WebMock: more brittle (tied to implementation), harder to read, doesn't test the actual HTTP construction
- Raising on HTTP errors instead of returning an error hash: the spec says "handles HTTP errors gracefully (returns error hash, does not raise)" — the job layer decides what to do with the error

**Tradeoffs taken:**
- `KiroAdapter#call_provider` serializes the prompt to a flat string for the CLI. This loses the structured message format (roles, system/user separation). If Kiro ever exposes an HTTP API, the adapter should be updated to use it directly
- Error messages in the returned hash say "Provider call failed" without the original exception message — this prevents leaking internal details but makes debugging harder. The exception class is included (`e.class.name`) as a compromise
- `read_timeout: 120` is a guess for both Claude and OpenAI. Long-running completions may time out. Should be made configurable via env var if real usage shows timeouts
