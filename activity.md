# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 71 iterations — initial planning through 0.0.57. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, IMPLEMENTATION_PLAN.md regenerated, parse_response normalised to hash across all adapters.]

---

## 2026-04-17 16:33 — Tasks 2.1–2.3: parse_response normalisation (tag 0.0.57)

**Changes:**
- `ClaudeAdapter#parse_response`: returns `{text:, input_tokens:, output_tokens:, stop_reason:}` from Anthropic response shape
- `KiroAdapter#parse_response`: same shape, same Anthropic-style response
- `OpenAiAdapter#parse_response`: same shape, maps from OpenAI choices/usage fields
- `provider_adapter_spec.rb`: replaced string-return tests with hash-return tests; added missing-field graceful handling tests for all three adapters
- 270 RSpec examples, 0 failures, 99.21% coverage
