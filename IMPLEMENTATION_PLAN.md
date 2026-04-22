# IMPLEMENTATION_PLAN.md — Unpossible

**Phase:** 0 (Local — Docker Compose only)
**Generated:** 2026-04-22
**Source of truth:** `specifications/` + `web/` + git state

## Scope

Phase 0 only. No CI, no k8s, no staging, no production config. Go sidecars are in scope
because `infra/docker-compose.yml` references them and the infrastructure spec requires
them for the local dev stack.

## Spec Contradiction

**FeatureFlag `metadata.hypothesis`:** The base spec (`system/feature-flags/requirements.md`)
says `metadata` is optional in Phase 0. The Rails platform override
(`platform/rails/product/analytics.md`) says `hypothesis` is required on creation → 422
if missing. The requirements spec's "Features Out" section explicitly lists
"`metadata.hypothesis` enforcement (optional, not required)" for Phase 0.

**Resolution needed from human:** Which behavior is correct for Phase 0? Current code
treats `metadata` as optional (matches base spec). Plan assumes base spec is authoritative
until told otherwise.

## Completed Work (discovered from code + git)

The following is implemented and tested (297 examples, 0 failures, 99.11% coverage):

- **Auth:** `AuthToken` (JWT encode/decode), `Secret` value object, `ApplicationController#authenticate!`,
  `Api::AuthController`, sidecar token auth, `DISABLE_AUTH` dev bypass
- **Security:** `Security::PromptSanitizer`, `Security::LogRedactor`, `Rack::Attack` rate limiting,
  `filter_parameters` configured, lograge with redaction
- **Agents module:** `AgentRun` model, `AgentRunTurn` model, `AgentRunsController` (start/complete/input),
  `RunStorageService`, `PromptDeduplicator`, `AgentRunJob` with pause/resume and concurrency control,
  `TurnContentGcJob`, `ProviderAdapter` base with pinned+sliding trimming,
  `ClaudeAdapter`, `KiroAdapter`, `OpenAiAdapter`
- **Sandbox module:** `ContainerRun` model, `DockerDispatcher` with timeout and secret filtering
- **Analytics module:** `AnalyticsEvent` (append-only), `AuditEvent` (append-only), `LlmMetric` (append-only),
  `FeatureFlag` with auto-fire `$feature_flag_called`, `AuditLogger` (async, fire-and-forget),
  `AuditLogJob`, `MetricsController` (llm/loops/summary/events/flag_stats),
  `FeatureFlagsController` (index/create/update)
- **Infrastructure:** `HealthCheckMiddleware` (Rack position 0), `Dockerfile`, `Dockerfile.test`,
  `docker-compose.yml`, `docker-compose.test.yml`, Solid Queue config, recurring jobs
- **API docs:** rswag installed, Swagger UI at `/api/docs`, all controllers have rswag request specs
- **Reference graph (partial):** `LedgerAppender`, `scripts/controlled-commit.sh`
- **LOOKUP.md** at `web/app/modules/`

---

## Tasks

### 1. Infrastructure Gaps

- [x] 1.1 — Commit `db/schema.rb` (`web/db/schema.rb`)
  No `schema.rb` is committed. This file is the canonical schema reference and is needed for
  `db:schema:load` in fresh environments. Generate it by running migrations and commit.
  Required tests: `db/schema.rb` exists and is loadable; `rails db:schema:load` succeeds in test container.

- [ ] 1.2 — Fix Postgres port exposure in `docker-compose.yml` (`infra/docker-compose.yml`)
  Spec says "Postgres is never bound to 0.0.0.0 — internal network only." Current compose
  file correctly has no `ports:` on postgres. **No change needed — verified compliant.**
  ~~Mark as done.~~
  **Status: already compliant — skip.**

- [ ] 1.3 — Add `db/schema.rb` to test Dockerfile COPY if needed (`infra/Dockerfile.test`)
  Verify that `Dockerfile.test` copies `web/` which includes `db/`. Currently it does
  (`COPY web/ .`). **No change needed — verified compliant.**
  **Status: already compliant — skip.**

### 2. Skill Assembly Pipeline (Agent Runner)

The `AgentRunJob#load_enrichment` method returns empty arrays — it's a stub. The spec
requires assembling prompts from skill files, context chunks, and principles.

- [x] 2.1 — Implement skill file loading in `AgentRunJob` (`web/app/modules/agents/jobs/agent_run_job.rb`, `web/app/modules/agents/services/skill_loader.rb`)
  Load the instruction body from the skill file referenced by `source_ref`. Parse YAML
  frontmatter for `tools.enrich` and `tools.callable` declarations.
  Required tests: loads skill file content from disk, parses frontmatter correctly, returns
  instruction body, handles missing file gracefully, handles malformed frontmatter.

- [x] 2.2 — Implement context chunk retrieval (`web/app/modules/agents/services/context_retriever.rb`)
  Load practices files declared in skill frontmatter (per `specifications/system/practices.md`
  loading strategy). Return as context chunks for prompt assembly.
  Required tests: loads declared practices files, respects mode-based loading rules,
  handles missing files without raising, returns empty array when no files declared.

- [x] 2.3 — Implement enrichment tool execution (`web/app/modules/agents/services/enrichment_runner.rb`)
  Run `tools.enrich` tools before the first LLM call. Append results as `tool_result` turns.
  Skip when `agent_override: true`.
  Required tests: runs enrich tools and appends tool_result turns, skips when agent_override
  is true, handles tool failure gracefully (fail open per pipeline invisible step rules).

- [x] 2.4 — Wire skill assembly into `AgentRunJob#load_enrichment` (`web/app/modules/agents/jobs/agent_run_job.rb`)
  Replace stub with calls to SkillLoader, ContextRetriever, and EnrichmentRunner.
  Required tests: full integration — job loads skill, retrieves context, runs enrichment,
  passes all to `build_prompt`. Existing agent_run_job_spec tests still pass.

### 3. Batch Request Middleware

Specified in `specifications/system/batch-requests.md` (status: active). Not implemented.

- [ ] 3.1 — Implement `BatchRequestMiddleware` (`web/app/middleware/batch_request_middleware.rb`)
  Rack middleware that intercepts `POST /api/batch`, fans out sub-requests internally,
  returns aggregated responses. Max batch size 100, returns 422 on overflow or malformed JSON.
  Sub-requests share auth context. Individual failures captured, don't abort batch.
  Required tests: fans out 2+ sub-requests and returns ordered responses, auth context
  shared across sub-requests, individual sub-request failure (404/500) captured in response
  array without aborting batch, batch size > 100 returns 422, malformed JSON returns 422,
  batch endpoint requires authentication.

- [ ] 3.2 — Add rswag request spec for `POST /api/batch` (`web/spec/requests/batch_spec.rb`)
  Required tests: happy path (200), auth failure (401), oversized batch (422), malformed
  JSON (422). Regenerate `swagger/v1/swagger.yaml`.

### 4. Reference Graph — Controlled Commit

`scripts/controlled-commit.sh` and `LedgerAppender` exist. Need to verify they meet the
spec's atomic sequence requirements.

- [ ] 4.1 — Verify and fix `controlled-commit.sh` against spec (`scripts/controlled-commit.sh`, `web/app/lib/ledger_appender.rb`)
  Spec requires atomic: stage code → append LEDGER.jsonl → update IMPLEMENTATION_PLAN.md →
  `git add` all → `git commit`. Verify the script implements this sequence. Add tests.
  Required tests: script stages files, appends to LEDGER.jsonl, updates plan, commits
  atomically. Failure at any step rolls back (no partial commit). LedgerAppender handles
  all event types defined in spec (status, blocked, unblocked, spec_changed, spec_removed,
  pr_opened, pr_review, pr_merged).

### 5. Reference Graph — Go Components

`go/` directory does not exist. The spec requires Go binaries for the reference parser
and repo map. These are Phase 0 deliverables per the infrastructure spec (the dev compose
file references `go_runner` and `analytics` sidecars).

- [ ] 5.1 — [SPIKE] Research Go project bootstrap — run `./loop.sh research go-bootstrap` (see specifications/skills/tools/research.md)
  Determine: Go module structure for `go/` with single `go.mod`, tree-sitter bindings
  for Ruby/Go/Markdown, CLI binary layout for `cmd/parser`, `cmd/repo-map`, `cmd/runner`,
  `cmd/analytics`. Blocks all Go build tasks.

- [ ] 5.2 — Bootstrap `go/` directory with `go.mod` and cmd stubs (`go/go.mod`, `go/cmd/parser/main.go`, `go/cmd/repo-map/main.go`, `go/cmd/runner/main.go`, `go/cmd/analytics/main.go`)
  depends_on: 5.1
  Create Go module, stub `main.go` for each binary. Verify `go build ./...` succeeds.
  Required tests: `go build ./cmd/parser`, `go build ./cmd/repo-map`, `go build ./cmd/runner`,
  `go build ./cmd/analytics` all exit 0.

- [ ] 5.3 — [SPIKE] Research tree-sitter Go bindings for Ruby/Go/Markdown parsing — run `./loop.sh research tree-sitter-go` (see specifications/skills/tools/research.md)
  Determine: which `smacker/go-tree-sitter` grammars are available, how to extract
  class/module/method signatures from Ruby, exported types/functions from Go, heading
  structure from Markdown. Blocks 5.5.

### 6. Reference Graph — Go Reference Parser

- [ ] 6.1 — Implement spec file parser (`go/cmd/parser/`)
  depends_on: 5.2, 5.3
  Walk `specifications/` directory, parse markdown frontmatter and section headers,
  extract inter-file links. Output JSON nodes.
  Required tests: parses frontmatter (name, kind, status), extracts H1/H2 headings,
  finds markdown links between files, handles missing/malformed frontmatter gracefully.

- [ ] 6.2 — Implement LEDGER.jsonl parser (`go/cmd/parser/`)
  depends_on: 5.2
  Parse LEDGER.jsonl events (status, blocked, unblocked, spec_changed, pr_opened,
  pr_review, pr_merged). Output JSON nodes and edges.
  Required tests: parses all event types, produces correct node types (status transition,
  PR node), produces correct edges (blocked-by, PR→commit, PR→task).

- [ ] 6.3 — Implement IMPLEMENTATION_PLAN.md parser (`go/cmd/parser/`)
  depends_on: 5.2
  Parse plan items with structured metadata comments (status, spec, test, blocked-by).
  Output task nodes with dependency edges.
  Required tests: parses checked and unchecked items, extracts status/spec/test/blocked-by
  from HTML comments, produces dependency edges from blocked-by refs.

- [ ] 6.4 — Implement git log integration (`go/cmd/parser/`)
  depends_on: 5.2
  Read git log for commit SHAs and messages. Read git notes on commits. Attach commits
  to PR nodes via LEDGER.jsonl sha ranges.
  Required tests: reads git log, reads git notes, links commits to PRs via sha range,
  deterministic output for same inputs.

- [ ] 6.5 — Implement graph assembly and JSON output (`go/cmd/parser/`)
  depends_on: 6.1, 6.2, 6.3, 6.4
  Combine all parsers into a single graph. Output JSON with nodes and edges.
  Deterministic — same inputs always produce same output.
  Required tests: full integration — spec files + LEDGER.jsonl + plan + git → JSON graph.
  Graph contains all node types (spec, task, commit, PR). Graph contains all edge types.
  Output is deterministic (run twice, compare).

### 7. Repo Map — Go CLI

- [ ] 7.1 — [SPIKE] Research repo-map token budgeting strategy — run `./loop.sh research repo-map-budget` (see specifications/skills/tools/research.md)
  Determine: token estimation approach (chars/4 or tiktoken-go), degradation rules
  implementation, relevance ranking by git recency. Blocks 7.2.

- [ ] 7.2 — Implement repo-map CLI (`go/cmd/repo-map/`)
  depends_on: 5.2, 5.3, 7.1
  Walk file tree (respecting .gitignore), parse Ruby/Go/Markdown with tree-sitter,
  extract symbols per spec rules, rank by relevance, render markdown output truncated
  at token budget.
  Required tests: extracts Ruby class/module/method signatures, extracts Go exported
  types/functions, extracts Markdown H1/H2 + frontmatter, respects `--budget` flag,
  `--focus` limits to specified directory, `--output` writes to file, excludes test/vendor
  files, deterministic output, applies degradation rules in order when over budget.

### 8. Go Sidecars

- [ ] 8.1 — [SPIKE] Research Go runner sidecar design — run `./loop.sh research go-runner-sidecar` (see specifications/skills/tools/research.md)
  Determine: what the runner sidecar does (port 8080), how it interacts with Rails,
  HTTP API shape. The infrastructure spec lists it but the agent-runner spec says
  "no sidecar — provider calls are made directly from Rails via HTTP." Clarify scope.
  Blocks 8.2.

- [ ] 8.2 — Implement Go runner sidecar (`go/cmd/runner/`)
  depends_on: 5.2, 8.1
  Implement based on spike findings. Port 8080.
  Required tests: TBD based on spike.

- [ ] 8.3 — [SPIKE] Research Go analytics ingest sidecar design — run `./loop.sh research go-analytics-sidecar` (see specifications/skills/tools/research.md)
  Determine: `POST /capture` endpoint, in-memory queue, batch flush to Postgres every
  5s or 100 events, buffer on Postgres unavailability. Port 9100.
  Blocks 8.4.

- [ ] 8.4 — Implement Go analytics ingest sidecar (`go/cmd/analytics/`)
  depends_on: 5.2, 8.3
  `POST /capture` returns 202 immediately. In-memory queue, batch flush to Postgres.
  Buffer on Postgres unavailability. Internal network only.
  Required tests: `POST /capture` returns 202, events flushed within 5s or 100 events,
  events buffered on Postgres unavailability, `distinct_id` validated as UUID format,
  batch array accepted, single event accepted.

- [ ] 8.5 — Add `Dockerfile.go` and uncomment Go services in compose (`infra/Dockerfile.go`, `infra/docker-compose.yml`)
  depends_on: 8.2, 8.4
  Multi-stage Dockerfile for Go binaries. Uncomment `go_runner` and `analytics` services
  in `docker-compose.yml`. Verify `docker compose up` starts all services.
  Required tests: `docker compose config` validates, Go services build, all services
  start and respond on expected ports.

### 9. FeatureFlag Exposure Tracking via Ingest Sidecar

The spec says `$feature_flag_called` should be fired via the analytics ingest sidecar,
not written directly to Postgres. Current implementation writes directly via
`AnalyticsEvent.create!`. This should be refactored once the Go ingest sidecar exists.

- [ ] 9.1 — Refactor `FeatureFlag.enabled?` to fire via ingest sidecar (`web/app/modules/analytics/models/feature_flag.rb`)
  depends_on: 8.4
  Replace `AnalyticsEvent.create!` with HTTP POST to `http://analytics:9100/capture`.
  Fire-and-forget — failure logged, never raises.
  Required tests: `enabled?` sends POST to ingest sidecar, failure does not raise,
  returns correct boolean regardless of sidecar availability.

### 10. Spec Reference Tags in Tests

Convention for linking RSpec tests to spec sections. Not yet adopted.

- [ ] 10.1 — Add `spec:` metadata tags to existing RSpec files (`web/spec/**/*_spec.rb`)
  Add `spec: "specifications/system/..."` metadata to describe blocks that test spec
  acceptance criteria. Start with agent_run_spec, container_run_spec, feature_flag_spec,
  analytics_event_spec, health_check_middleware_spec.
  Required tests: RSpec metadata is parseable, `spec:` values are valid file paths that
  exist in `specifications/`.

### 11. Missing `db/schema.rb`

- [x] ~~Covered by task 1.1~~

### 12. Swagger Completeness

- [ ] 12.1 — Add `/api/feature_flags` endpoints to swagger.yaml (`web/swagger/v1/swagger.yaml`)
  The feature flags endpoints (GET/POST /api/feature_flags, PATCH /api/feature_flags/:key)
  are not in the current swagger.yaml. Run `rake rswag:specs:swaggerize` to regenerate.
  Required tests: `rake rswag:specs:swaggerize` exits 0, swagger.yaml includes all
  feature flag endpoints.

---

## Dependency Graph

```
1.1 (schema.rb)                          — no deps, quick win
3.1 → 3.2 (batch middleware)             — no deps, self-contained
4.1 (controlled commit)                  — no deps, verify existing
10.1 (spec tags)                         — no deps, convention adoption
12.1 (swagger regen)                     — no deps, quick win

2.1 → 2.2 → 2.3 → 2.4 (skill assembly) — sequential, Rails-only

5.1 → 5.2 (Go bootstrap)
5.3 (tree-sitter spike)
5.2 + 5.3 → 6.1, 6.2, 6.3, 6.4 → 6.5 (reference parser)
5.2 + 5.3 + 7.1 → 7.2 (repo map)
5.2 + 8.1 → 8.2 (runner sidecar)
5.2 + 8.3 → 8.4 (analytics sidecar)
8.2 + 8.4 → 8.5 (Go compose integration)
8.4 → 9.1 (feature flag sidecar refactor)
```

## Recommended Build Order

1. **Quick wins (no deps):** 1.1, 12.1, 4.1, 10.1
2. **Self-contained Rails:** 3.1 → 3.2, then 2.1 → 2.2 → 2.3 → 2.4
3. **Go spikes (parallel):** 5.1, 5.3, 7.1, 8.1, 8.3
4. **Go bootstrap:** 5.2
5. **Go builds (parallel where deps allow):** 6.1–6.5, 7.2, 8.2, 8.4
6. **Go integration:** 8.5, 9.1

## Out of Scope (proposed/future specs — not Phase 0 build tasks)

- `analytics-dashboard-ui.md` — status: proposed
- `agent-runs-ui.md` — status: proposed
- `log-tail-relay.md` — status: proposed
- CI (Phase 1), staging (Phase 2), production (Phase 3)
- NixOS, k8s, SOPS secrets
- Streaming output, multi-provider fallback
- Apache AGE graph extension
- Outbound analytics adapters (PostHog, Datadog)
