# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 88 iterations — initial planning through 0.0.63, then tasks 1.1, 2.1, 2.2, 2.3, 2.4, 2.5. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash, LlmMetric on completion, rswag install, FeatureFlagsController org_id fix, all rswag spec conversions (auth, agent_runs, metrics, feature_flags).]

---

## 2026-04-22 09:55 — Task 2.6: Add rswag request spec for GET /health (tag 0.0.70)

**Changes:** Added `web/spec/requests/health_spec.rb` with rswag format covering 200 (DB reachable) and 503 (DB unreachable). Added `/health` path to `web/swagger/v1/swagger.yaml`. 297 examples, 0 failures, 99.11% coverage.

**Thinking:**
- The health endpoint is handled by `HealthCheckMiddleware` at Rack position 0, not by a Rails route. rswag's `run_test!` makes a real HTTP request through the full Rack stack, so the middleware intercepts it correctly — no special setup needed.
- The 503 test mocks `ActiveRecord::Base.connection.execute` to raise `PG::ConnectionBad`. This matches exactly what the middleware calls (`execute('SELECT 1')`), so the mock is precise.
- The swagger.yaml was updated manually (adding the `/health` path block) rather than via a container swaggerize run, because the container writes to `/app/swagger/` and there's no volume mount to sync back to the host. The generated content is deterministic and simple enough to write directly.

**Challenges:**
- The swaggerize rake task runs inside the container and writes to `/app/swagger/v1/swagger.yaml`. Extracting the output via `docker compose run ... && cat` is noisy (container startup messages go to stdout). Manual update of the host swagger.yaml is the pragmatic workaround until a volume mount is added.

**Alternatives considered:**
- Adding a volume mount for `web/swagger/` in docker-compose.test.yml to auto-sync the generated swagger.yaml — considered but deferred: it's a compose file change that affects all tasks, not just this one. Worth a dedicated task.
- Using `get '/health'` in a plain RSpec request spec (not rswag) — rejected: the task explicitly requires rswag format so the endpoint appears in the Swagger UI.

**Tradeoffs taken:**
- swagger.yaml is manually maintained for the `/health` entry. If the spec changes (e.g., adding a response code), the yaml must be updated by hand. Low risk: the health endpoint is stable.
- No volume mount for `web/swagger/` means every swaggerize run requires manual sync. Known debt — acceptable for Phase 0.
