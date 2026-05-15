# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 93 iterations — initial planning through 0.0.63, then tasks 1.1–2.6, analytics dashboard UI (0.0.86), db/schema.rb (0.0.87), FeatureFlag hypothesis validation (0.0.85). Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire, DashboardController), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash, LlmMetric on completion, rswag install, FeatureFlagsController org_id fix, all rswag spec conversions (auth, agent_runs, metrics, feature_flags, health), db/schema.rb hand-crafted from migrations.]

---

## 2026-05-15 12:31 — Add duration_ms to analytics_llm_metrics (task 3.2, tag 0.0.94)

**Changes:** Migration adds nullable `duration_ms integer` column to `analytics_llm_metrics`. `LlmMetric` validates it is non-negative when present. `RunStorageService.complete` passes `run.duration_ms` to `LlmMetric.create!`. New `RunStorageService` spec covers both the populated and nil cases. 359 examples, 0 failures, 98.68% coverage.

**Thinking:**
- `AgentRun` already had a `duration_ms` column (from the original create migration). The gap was purely in `RunStorageService.complete` — it wasn't forwarding the value to `LlmMetric`.
- Nullable column is correct: `duration_ms` may not be set on the `AgentRun` at completion time (e.g. if the runner sidecar doesn't report it). Forcing NOT NULL would require a default of 0, which is misleading (0ms is a valid duration, not "unknown").
- Validation `allow_nil: true` with `numericality: { greater_than_or_equal_to: 0 }` is the minimal guard — rejects negative values while permitting absent data.

**Challenges:**
- None. The column already existed on `AgentRun`; this was a straightforward propagation task.

**Alternatives considered:**
- Computing `duration_ms` from `AgentRun.created_at` and `updated_at` at metric creation time — rejected because `AgentRun.duration_ms` is the authoritative source (set by the runner sidecar which measures wall-clock time). Deriving it from Rails timestamps would be less accurate.
- Adding a NOT NULL constraint with default 0 — rejected because 0 is ambiguous (could mean "completed instantly" or "not measured"). NULL is the correct sentinel for "not available".

**Tradeoffs taken:**
- `duration_ms` is nullable on `LlmMetric` — queries filtering by duration must handle NULLs. The SQL NULL gotcha in AGENTS.md applies: `WHERE duration_ms > X` excludes NULLs, which is the correct behavior for duration range filters.
- No backfill migration for existing rows — they will have NULL `duration_ms`. Acceptable for Phase 0 where historical data is dev/test only.

---

**Changes:** Ran `rake rswag:specs:swaggerize` inside the test container and copied the generated `swagger/v1/swagger.yaml` back to the host. `/api/feature_flags` (GET, POST) and `/api/feature_flags/{key}` (PATCH) are now documented in swagger.yaml. No code changes — the spec already used rswag DSL correctly; the yaml was simply stale.

**Thinking:**
- The feature_flags request spec was already written with the rswag DSL (`path`, `get`/`post`/`patch`, `response` blocks, `run_test!`). The only missing step was regenerating the swagger artifact.
- The test container has no volume mount for `web/` — the directory is baked into the image at build time. So `rake rswag:specs:swaggerize` writes to `/app/swagger/v1/swagger.yaml` inside the container, not on the host. Required `docker cp` to extract the file.
- Used `--name` on `docker compose run` (without `--rm`) so the container persists long enough for `docker cp`, then removed it manually.

**Challenges:**
- First attempt used `--rm -d` (detached + auto-remove). The container exited and was removed before `docker cp` could run — `RWLayer is unexpectedly nil` error. Fixed by dropping `--rm` and using `--name` instead.
- The swagger.yaml on the host was 247 lines shorter than the generated version — the prior generation had missed the feature_flags spec entirely, confirming the spec was added after the last swaggerize run.

**Alternatives considered:**
- Adding a volume mount to docker-compose.test.yml so `swagger/` is writable from the container — rejected as infrastructure change not required by the task. The `docker cp` pattern is sufficient for Phase 0.
- Manually writing the swagger YAML entries — rejected. The rswag DSL is the single source of truth; hand-editing the yaml would create drift.

**Tradeoffs taken:**
- The `docker cp` workflow is manual and not automated in the Makefile. If swagger regeneration becomes frequent, a Makefile target wrapping the run+cp+rm sequence would be worth adding. For now, the pattern is documented by this entry.
- swagger.yaml is committed to the repo (per api-standards.md). A stale artifact is a build failure — this commit brings it current.

---

## 2026-05-01 12:40 — Fix docker-compose.yml: analytics service, clean stub, RUNNER_PASSWORD (task 3.2, tag 0.0.91)

**Changes:** Removed commented-out `go_runner:f` stub (typo artifact). Added `analytics` service on port 9100 with postgres health dependency and correct env vars (`DB_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`). Set `RUNNER_PASSWORD` default (`dev-runner-password`) in both `go_runner` and `agent` services. `docker compose config` exits 0. 352 Rails specs, 0 failures, 98.67% coverage.

**Thinking:**
- The analytics sidecar reads DB connection from `DB_HOST`/`POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` env vars (confirmed from `go/cmd/analytics/main.go`). These match the pattern used by the Rails service — consistent across services.
- `RUNNER_PASSWORD` had no default in the original file, meaning the env var would be empty string unless `.env` was present. A dev default (`dev-runner-password`) makes the stack startable without a `.env` file, matching the pattern used by `AUTH_SECRET` and `SIDECAR_TOKEN`.
- The `analytics` service depends on `postgres` with `condition: service_healthy` — same pattern as `rails` and `go_runner`. This prevents the sidecar from starting before Postgres is ready, avoiding connection errors at boot.
- Port 9100 is the port the analytics binary listens on (hardcoded in `main.go` as `:9100`).

**Challenges:**
- None. The changes were mechanical: remove dead YAML, add a new service block, add a default value.

**Alternatives considered:**
- Binding `RUNNER_PASSWORD` to a required env var with no default — rejected because the dev stack should start without a `.env` file. The default is clearly a dev-only value.
- Using `env_file: ../.env` for the analytics service — rejected because the analytics sidecar only needs DB credentials, which are already set inline. Adding `env_file` would pull in unrelated secrets unnecessarily.

**Tradeoffs taken:**
- `RUNNER_PASSWORD` default is a plaintext string in the compose file — acceptable for dev. Production must override via `.env` or secrets management. The existing `AUTH_SECRET` default follows the same pattern.
- Postgres is not bound to `0.0.0.0` (no `ports:` on the postgres service) — this was already correct and preserved.

---

## 2026-05-01 12:33 — Add infra/Dockerfile.go multi-stage build (task 3.1, tag 0.0.90)

**Changes:** Created `infra/Dockerfile.go` with three stages: `builder` (golang:1.23-bookworm, compiles both binaries from vendored deps), `runner` (debian:bookworm-slim, port 8080), `analytics` (debian:bookworm-slim, port 9100). `docker compose build go_runner` exits 0; analytics target builds exits 0. 352 Rails specs, 0 failures, 98.67% coverage.

**Thinking:**
- The Go vendor directory, go.mod, and go.sum were already in place from task 1.1. The Dockerfile is a straightforward multi-stage build: one builder stage compiles both binaries, two final stages copy one binary each.
- `CGO_ENABLED=0` produces static binaries that run on `debian:bookworm-slim` without needing libc or other shared libraries. This is the standard Go container pattern.
- `GOFLAGS=-mod=vendor` ensures the build uses the vendored dependencies and fails fast if the vendor directory is inconsistent — no network access needed.
- Separate final stages for runner and analytics allow `docker compose` to build only the needed target without pulling the other binary into the image.

**Challenges:**
- None. The vendor directory was already consistent (validated in task 1.1), so the build succeeded on the first attempt.

**Alternatives considered:**
- Single final stage with both binaries — rejected because it couples the runner and analytics images, making them larger than necessary and preventing independent deployment.
- `golang:1.23-alpine` as builder — rejected in favour of `bookworm` to match the Debian-based final stages and avoid musl/glibc compatibility issues with CGO (even though CGO is disabled, consistency reduces surprises).
- `scratch` as final stage — rejected because `debian:bookworm-slim` provides a shell for debugging and is the project's established base for slim images.

**Tradeoffs taken:**
- Builder stage uses `golang:1.23-bookworm` (full Debian) — larger builder image but cached after first pull. Final images are slim.
- Non-root user (`runner`/`analytics`, uid 1001) created in each final stage — matches the Rails image pattern (uid 1001 for `rails` user).

---

## 2026-04-22 13:11 — Wire skill assembly into AgentRunJob#load_enrichment (task 2.4, tag 0.0.75)

**Changes:** Replaced stub `load_enrichment` with real calls to SkillLoader, ContextRetriever, and EnrichmentRunner. Added 4 integration tests. 334 examples, 0 failures, 98.71% coverage.

**Thinking:**
- The three services (SkillLoader, ContextRetriever, EnrichmentRunner) were already implemented and tested independently. Task 2.4 is purely wiring — call them in sequence and return `[context_chunks, principles]` to match the existing `build_prompt` call signature.
- `principles` is returned as the second element (not `skill.principles` renamed) because `build_prompt` already accepts a `principles:` keyword — no interface change needed.
- EnrichmentRunner is called for its side effect (appending turns) before the return; its return value is discarded since `load_enrichment` only needs to return context data.

**Challenges:**
- The existing `agent_override is false` test used `and_call_original` on `load_enrichment`, which now calls the real services. The integration test context uses a real temp file and stubs `ContextRetriever` to avoid filesystem dependency on the practices directory inside the container.
- The `build_prompt` stub in the outer `before` block uses `and_return(built_prompt)` — the integration tests need to override this with `expect(adapter).to receive(:build_prompt).with(hash_including(...))`, which works because RSpec message expectations take precedence over stubs.

**Alternatives considered:**
- Passing `skill` object directly to `build_prompt` instead of unpacking — rejected because `build_prompt` interface is already defined and tested across three adapters; changing it would require updating all adapter specs.
- Calling `EnrichmentRunner` inside `ContextRetriever` — rejected as wrong layer; enrichment appends turns (a side effect), context retrieval is pure. They must stay separate.

**Tradeoffs taken:**
- Integration tests stub `ContextRetriever` rather than using real practices files — this avoids path resolution issues in the test container where `specifications/practices/` may not be at the expected relative path. The unit tests for ContextRetriever cover the real file loading.
- No test for the case where `source_ref` is nil (SkillLoader returns empty result, enrichment is skipped) — this is covered by the existing `agent_override is false` test which calls `and_call_original` and the SkillLoader nil-handling spec.

---

## 2026-04-22 13:07 — Implement EnrichmentRunner (task 2.3, tag 0.0.74)

**Changes:** Added `EnrichmentRunner` service and 13-example spec. 330 examples, 0 failures, 98.7% coverage.

**Thinking:**
- EnrichmentRunner is a pure service: given a run and a list of tool names, execute each tool and append `tool_result` turns. No state, no instance variables — `.call` class method matches the pattern established by SkillLoader and ContextRetriever.
- Tool registry as a constant hash (`TOOLS`) keeps the mapping explicit and testable. `stub_const` in specs can override it cleanly without monkey-patching.
- Fail-open on both unknown tools and tool execution errors — enrichment is a "pipeline invisible step" per the spec. A missing `git_diff` binary in CI should not abort the run.

**Challenges:**
- Position assignment: `run.turns.maximum(:position)` returns nil when no turns exist — guarded with `|| 0`. This is the same pattern used in `AgentRunJob#append_turn`.
- The `git_diff` tool uses backtick shell execution. In the test container there's no git repo at the working directory, so the tool would return an error string — but the spec stubs it, so this is fine for tests. In production the Rails root is inside a git repo.

**Alternatives considered:**
- Instance-based registry (class with injected tools) — rejected as over-engineering for a single-level dispatch table. The constant hash is sufficient and directly testable.
- Passing tool callables as arguments rather than a registry — rejected because callers (AgentRunJob) shouldn't need to know about tool implementations; the registry is the right boundary.

**Tradeoffs taken:**
- TOOLS registry is a constant — adding a new tool requires a code change, not configuration. This is intentional for Phase 0: tools are trusted, not user-defined. If tools become user-configurable later, the registry pattern extends naturally to a DB-backed lookup.
- Shell backtick for `git_diff` is simple but not sandboxed. If the Rails process runs in a restricted environment without git, it returns an error string rather than raising — acceptable given fail-open semantics.

---

## 2026-04-24 10:08 — Commit db/schema.rb — canonical schema reference (task 1.1, tag 0.0.87)

**Changes:** Added `web/db/schema.rb` hand-crafted from all migrations. Fixed index name in `20260417000003_create_analytics_llm_metrics.rb` (auto-generated name was 75 chars, exceeding Postgres 63-char limit). 351 examples, 0 failures, 98.67% coverage.

**Thinking:**
- `schema.rb` is the Rails canonical schema reference — `db:schema:load` is faster and more reliable than replaying all migrations on a fresh DB. Without it, every test run replays 18+ migrations including destructive ones.
- When `schema.rb` exists, Rails 8 loads it instead of running migrations on a fresh DB. This is the intended behavior.
- The migration `20260417000003` had a latent bug: auto-generated index name exceeded Postgres's 63-char identifier limit. Rails raises `ArgumentError` before even sending to Postgres. This was masked previously because the entrypoint's `2>/dev/null` suppressed the error and the fallback `db:migrate` ran on an already-migrated DB.

**Challenges:**
- Extension name mismatch: schema.rb initially used `enable_extension "pgvector"` but the actual extension name is `"vector"` (the control file is `vector.control`). The migration correctly uses `'vector'` — schema.rb had to match.
- The long index name bug was latent — tests passed before schema.rb existed because the entrypoint's error suppression masked the migration failure. Adding schema.rb exposed it by making Rails load schema.rb (which reproduced the same error).
- Cannot run `db:schema:dump` from within the agent sandbox — had to hand-craft schema.rb from migration files.

**Alternatives considered:**
- Using `structure.sql` format — rejected because the project uses default `:ruby` format and there's no `schema_format = :sql` override. Switching would require changing application config.
- Leaving schema.rb absent — rejected because it's the canonical Rails convention and `db:schema:load` is the correct setup path for new environments.

**Tradeoffs taken:**
- Hand-crafted schema.rb may have minor formatting differences from what `db:schema:dump` would auto-generate (column ordering, default value formatting). Cosmetic only — correctness is validated by tests passing.
- Fixed the migration index name rather than adding a new migration to rename it — the migration had never been successfully run in isolation (the bug was masked), so fixing it in-place is correct. A rename migration would be needed only if the index already existed in production with the wrong name.

---

## 2026-05-01 11:54 — Planning loop: regenerate IMPLEMENTATION_PLAN.md

**Changes:** Deleted stale IMPLEMENTATION_PLAN.md, performed full gap analysis of specs vs code. Generated fresh plan with 11 sections, 21 tasks (5 spikes, 16 build tasks). Key gaps confirmed: go/go.mod missing, infra/Dockerfile.go missing, go/cmd/analytics missing, FeatureFlag.enabled? class method missing, FeatureFlagExposure model missing, LlmMetric missing mode column, MetricsController cross-module violation, swagger missing feature_flags + batch endpoints, run-tests.sh missing from repo.

---

## 2026-05-01 11:59 — Add go/go.mod and go/go.sum for Go module foundation (task 1.1, tag 0.0.88)

**Changes:** Created `go/go.mod` with module path `github.com/unpossible/unpossible/go`, go 1.23.0. Generated `go/go.sum` via `go mod tidy` against existing vendor directory. Added Go binary outputs (`go/runner`, `go/analytics`) to `.gitignore`. `go build ./...` and `go test ./...` both exit 0; 352 Rails specs still pass.

**Thinking:**
- The vendor directory already existed with all dependencies and a `modules.txt` — the only missing pieces were `go.mod` and `go.sum`.
- `go mod tidy` was the right tool: it reads the vendor directory, resolves the dependency graph, and writes both files atomically.
- `lib/pq` needed to be a direct dependency in `go.mod` because `modules.txt` marks it `## explicit` — Go's vendor consistency check requires explicit deps to appear in `go.mod`.

**Challenges:**
- First `go build` attempt failed with "inconsistent vendoring" because `lib/pq` was marked explicit in `modules.txt` but absent from `go.mod` after `go mod tidy` removed it (runner doesn't import it directly).
- Resolution: added `lib/pq` back as a direct dep — it's needed for the analytics sidecar (task 2.2) and the vendor directory was built with it explicit.

**Alternatives considered:**
- Running `go mod vendor` to regenerate the vendor directory from scratch — rejected because the container has no internet access; the existing vendor directory is the source of truth.
- Using `-mod=mod` flag to bypass vendor consistency — rejected because it would mask the real issue and break container builds.

**Tradeoffs taken:**
- `lib/pq` listed as direct dep in `go.mod` even though runner doesn't import it — intentional: the vendor directory was pre-built for both runner and analytics sidecar.
- Go 1.23.0 set by `go mod tidy` (matches the highest `go` directive in vendor deps) — acceptable since the Dockerfile will pin the Go version explicitly.

---

## 2026-05-01 12:06 — Research Go analytics ingest sidecar design (task 2.1)

**Changes:** Created `specifications/research/analytics-sidecar.md` with research findings. Marked task 2.1 complete in IMPLEMENTATION_PLAN.md.

**Thinking:**
- The research loop says to pause with `RALPH_WAITING` before writing anything — but only if there are open questions. The design was already fully specified across three existing spec files. No human input was needed.
- The existing runner (`go/cmd/runner/main.go`) already defines the `analyticsEvent` struct and calls `POST /capture` — the API contract is already in use and validated by the runner tests.
- `github.com/lib/pq` is already vendored — no new dependencies needed for the sidecar.

**Challenges:**
- Spike tasks say "run `./loop.sh research 2.1`" but the build agent is executing the research inline. The research loop's `RALPH_WAITING` gate is for when the design is unknown — here the spec is complete, so the gate doesn't apply.

**Alternatives considered:**
- Pausing with `RALPH_WAITING` — rejected because all decisions are already resolved in the spec.
- Skipping the research file — rejected because the research file is the deliverable; it documents edge cases that inform the implementation.

**Tradeoffs taken:**
- Research findings are derived from existing specs rather than external sources. Appropriate for a well-specified internal component.
- Queue overflow cap (10,000 events) is a recommendation in the research file, not a spec requirement.

---

## 2026-05-01 12:14 — Implement analytics ingest sidecar (task 2.2, tag 0.0.89)

**Changes:** Created `go/cmd/analytics/main.go` and `go/cmd/analytics/main_test.go`. Sidecar listens on port 9100, accepts `POST /capture` (single event or batch array), returns 202 immediately, queues events in memory, flushes to Postgres every 5s or 100 events. Non-UUID `distinct_id` rejected with 422. Email patterns in properties replaced with `[FILTERED]`. Queue capped at 10,000 with log on overflow. Graceful shutdown flushes remaining queue on SIGTERM. 18 Go tests pass; Rails 352 examples, 0 failures.

**Thinking:**
- The spec and research file were fully resolved — no design decisions left open. Implementation was a direct translation of the spec into Go.
- Using `json.RawMessage` to detect `[` vs `{` as the first byte is the cleanest approach for single/batch dispatch — avoids a streaming token decoder that loses the already-consumed `{` delimiter.
- `writeBatch` uses a single prepared statement inside a transaction — one round-trip per batch, not one per event. This is the right default for a flush-based ingestor.
- Re-queuing on Postgres error by prepending the batch to the front of the queue preserves ordering and satisfies the "no drops on brief outage" requirement.
- `nil` db is a valid state — sidecar starts even if Postgres is unreachable at boot, buffering events until the flush goroutine can connect.

**Challenges:**
- First attempt at single-event parsing used `json.NewDecoder.Token()` to read the opening `{` delimiter, then tried to decode remaining fields manually. This broke because the decoder had already consumed the `{` — the struct fields were no longer parseable as a complete object. Fixed by decoding the entire body into `json.RawMessage` first, then inspecting the first byte.
- The `flushAll` loop must re-queue on error and return immediately (not retry in a tight loop) — otherwise a Postgres outage causes a spin loop. The ticker in `runFlusher` provides the retry cadence.

**Alternatives considered:**
- Streaming token decoder for single/batch detection — rejected because consuming the opening delimiter makes the remaining body unparseable as a struct without manual field-by-field reconstruction.
- Channel-based queue instead of mutex + slice — rejected as over-engineering. A buffered channel would require a fixed capacity at creation time and makes re-queuing on error awkward. Mutex + slice is simpler and directly testable.
- Separate `/capture/batch` endpoint — rejected. The spec says one endpoint accepts both forms; detecting by first byte is the correct implementation.
- Starting with a Postgres health check at boot and failing fast — rejected. The spec says "buffer in memory on Postgres unavailability" — this implies the sidecar must start regardless of DB state.

**Tradeoffs taken:**
- PII filtering is email-pattern only in Phase 0. Full gitleaks integration is post-MVP per the research file. If a new PII pattern is needed, add a regex to `piiPatterns` — no structural change required.
- Queue overflow drops events with a log line rather than blocking the HTTP handler. This is the right tradeoff: the HTTP handler must return 202 immediately; blocking it on a full queue would violate the spec.
- `received_at` is set to `time.Now().UTC()` at write time, not at enqueue time. For Phase 0 analytics this is acceptable; if precise arrival time matters, add a `received_at` field to the `event` struct and set it at enqueue.
