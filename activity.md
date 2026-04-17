# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 65 iterations — initial planning through 0.0.50. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations (2.1, 2.2).]

---

## 2026-04-17 13:43 — Task 4.2: TurnContentGcJob (tag 0.0.52)

**Changes:**
- Created `web/app/modules/agents/jobs/turn_content_gc_job.rb` — :agents queue, batched purge of completed run turns older than 30 days
- Migration 20260417000004: allow null content on agents_agent_run_turns
- AgentRunTurn: content validates presence only when not purged
- Registered recurring job in config/recurring.yml (daily at midnight)
- Added agents queue to config/queue.yml; updated solid_queue_spec
- 235 examples, 0 failures, 98.6% coverage

## 2026-04-17 13:51 — Task 4.4: Provider adapter build_prompt with pinned+sliding token budget (tag 0.0.54)

**Changes:**
- Updated build_prompt signature to (node:, context_chunks:, principles:, turns:, token_budget:) across all adapters
- Implemented pinned+sliding trimming in ProviderAdapter#apply_turn_budget: always keeps agent_question/human_input, drops oldest llm_response/tool_result first
- Raises TokenBudgetExceeded when pinned turns alone exceed budget
- AgentRunJob calls build_prompt before call_provider; rescues TokenBudgetExceeded → waiting_for_input
- 254 examples, 0 failures, 99.19% coverage
