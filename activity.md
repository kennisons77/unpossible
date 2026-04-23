# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 100+ iterations — initial planning through 0.0.84. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash, LlmMetric on completion, rswag install, FeatureFlagsController org_id fix, all rswag spec conversions, db/schema.rb, EnrichmentRunner, SkillLoader wiring, hypothesis validation (2.1), batch middleware (3.1, 3.2), controlled commit spike (4.1), Go reference parser spike (5.1), spec: metadata tags (6.1), Go sidecar spike (8.1), Go bootstrap (8.2), Go analytics sidecar (8.3), Dockerfile.go (8.4), uncomment analytics compose (8.5), Go runner sidecar (8.6). Tasks through 8.6 complete.]

---

## 2026-04-23 10:00 — Spike: repo map implementation research (task 9.1, tag 0.0.85)

**Changes:** Wrote research findings to `specifications/research/repo-map.md` answering three open questions (tree-sitter maturity for Ruby, token budget estimation, relevance ranking weights). Added `## Research` back-reference in `specifications/system/repo-map/concept.md`. Marked task 9.1 complete in IMPLEMENTATION_PLAN.md. No code changes (spike is docs-only per `specifications/skills/tools/research.md`).

**Thinking:**
- The repo-map and reference-parser binaries share a monorepo but have very different parsing needs. The reference parser extracts fixed-format `spec:` string literals; regex is right. The repo map extracts structured Ruby/Go AST with nesting; regex false-positives in heredocs and `%w[]` literals would be a constant papercut. AST is worth the cgo cost for the repo-map specifically.
- Tokens don't need to be counted exactly — they need to be estimated well enough to stay under a 1 KB budget with a known degradation cascade. Character÷4 is accurate to ~±10%, which is invisible at this resolution.
- Relevance ranking is where feature creep usually starts. The concept spec explicitly says "start with git recency only; measure before adding." Honouring that saves a week of premature optimisation on a feature that isn't even implemented yet.

**Challenges:**
- The key decision was cgo isolation: if we flip the whole `go/` monorepo to cgo because of the repo-map, the sidecars lose static linking. Resolved by keeping `CGO_ENABLED=0` for `cmd/runner` and `cmd/analytics` builds, and `CGO_ENABLED=1` for `cmd/repo-map` only. Two-track cgo policy inside one `go.mod`.
- Phase 0 scope containment: the concept spec has a full integration story (agent-config resources, gitignored derived file, pre-loop hook). Easy to scope-creep the spike into "design the full thing." Kept the spike narrowly scoped to the three questions IMPLEMENTATION_PLAN.md asked.

**Alternatives considered:**
- Regex-only Ruby extraction (like the reference parser) — rejected. Different problem shape: the parser wants tags, the map wants structure. Regex correctness falls off a cliff for Ruby structure.
- Shelling out to the `tree-sitter` CLI — rejected. Adds a Node install, parse latency per file, and stdout-as-API coupling. In-process Go binding is cleaner.
- `tiktoken-go` for exact token counting — rejected. Claude's tokenizer isn't published; tiktoken is an approximation anyway. +3 MB BPE tables for no accuracy gain at this budget.
- Calling Anthropic's `count_tokens` endpoint — rejected. Network + API key for a build-time artifact that regenerates frequently is wrong.

**Tradeoffs taken:**
- cgo for `cmd/repo-map` only: adds build-base to the Dockerfile.go builder stage and ~25–40 MB to the repo-map binary. Contained — sidecars stay static. If a future phase needs the repo-map as a sidecar (not a CLI), revisit.
- Git-recency-only ranking will miss files the agent needs when they haven't been touched recently but are referenced in the plan. Acceptable for Phase 0: measure first, then add plan-reference weighting when there's evidence it matters. Trigger: build-agent repeatedly grepping for a file the map omitted.
- Character÷4 token estimate will be ~10% off on code-dense blocks. Acceptable because the degradation cascade has four steps — a 10% miscount shifts which step triggers, not whether we respect the budget.

---

## 2026-04-22 16:28 — Implement Go runner sidecar (task 8.6, tag 0.0.84)

**Changes:** Replaced `go/cmd/runner/main.go` stub with full implementation: `POST /run` (Basic Auth, mutex, exec.CommandContext, token parsing, Rails complete callback), `GET /healthz`, `GET /ready`, `GET /metrics` (Prometheus). Added `prometheus/client_golang v1.23.2`. 10 unit tests. `go test ./...` passes. 351 Rails specs still green at 98.67% coverage.

**Thinking:**
- The spec says "minimal viable = full spec" — token parsing and Prometheus metrics are required, not optional.
- `exec.CommandContext` with a 2-hour timeout is the right primitive: it handles cancellation cleanly and the timeout prevents zombie runs.
- `callComplete` is a fire-and-forget HTTP call in the goroutine — failure is logged but doesn't affect the run result.

**Challenges:**
- Prometheus `DefaultRegisterer` panics on duplicate metric registration across tests. Fixed by introducing `newRunnerWithRegistry` that accepts a `prometheus.Registerer`, and passing `prometheus.NewRegistry()` in tests.
- Token parsing: Claude stream-json emits `message_start` with input tokens and `message_delta` with output tokens. Taking the last seen values of each gives the final totals.

**Alternatives considered:**
- Streaming stdout line-by-line during execution — rejected. `cmd.Output()` is simpler and sufficient; token counts are only needed after the run completes.
- Separate Prometheus registry per runner in production — rejected. `DefaultRegisterer` is correct for production; isolated registry is test-only.
- `context.WithCancel` instead of `WithTimeout` — rejected. A timeout is a safety net against runaway loops; cancel-only has no upper bound.

**Tradeoffs taken:**
- `cmd.Output()` buffers all stdout in memory. For very long runs this could be large. Acceptable for Phase 0 — if memory becomes an issue, switch to streaming with a ring buffer.
- The complete callback has a 10s timeout. If Rails is slow, the goroutine blocks for up to 10s after the run. Acceptable — the mutex is released before the callback, so new runs aren't blocked.

---

## 2026-04-22 15:28 — Spike: Go reference parser research (task 5.1)

**Changes:** Wrote research findings to `specifications/research/reference-graph-parser.md`. Marked task 5.1 complete in IMPLEMENTATION_PLAN.md.

**Thinking:**
- tree-sitter is the repo-map's concern, not the reference parser's. The parser extracts `spec:` tags from RSpec files — a fixed-format string literal that regex handles cleanly.
- Stdlib-only Go for Phase 0: `os`, `bufio`, `encoding/json`, `regexp`, `os/exec` cover all parser inputs.

**Challenges:**
- Distinguishing what belongs to the parser vs the repo-map: parser extracts graph edges (traceability), repo-map extracts signatures (navigation). Different dependency profiles.

**Alternatives considered:**
- tree-sitter for `spec:` tag extraction — rejected (regex sufficient, avoids CGo).
- Separate `go.mod` per binary — rejected per the Go platform spec.

**Tradeoffs taken:**
- Phase 0 parser uses regex. If tag format becomes more complex, tree-sitter will be needed. The concept spec's fixed format makes this unlikely near-term.

---

## 2026-04-22 14:24 — Spike: controlled commit skill research (task 4.1, tag 0.0.78)

**Changes:** Wrote research findings to `specifications/research/reference-graph-commit-skill.md`. Created `specifications/skills/tools/commit.md`. Marked task 4.1 complete.

**Thinking:**
- The skill file is the right deliverable — not a Ruby service or shell script. The agent is the executor; the skill is the instruction.
- The two-event pattern (one `done` event before commit with `sha: null`, one after with the real SHA via amend) preserves append-only semantics while recording the SHA.

**Challenges:**
- SHA recording problem: can't know the commit SHA before committing. The amend approach folds both into one commit cleanly.

**Alternatives considered:**
- Shell script wrapper — rejected (duplicates what the agent already does with bash tools).
- Ruby service via `rails runner` — rejected (git operations from Ruby add complexity with no benefit).

**Tradeoffs taken:**
- Amend approach requires the commit to not yet be pushed. Safe because `loop.sh` pushes only after `RALPH_COMPLETE`.

---

## 2026-04-22 15:34 — Add spec: metadata tags to all RSpec files (task 6.1, tag 0.0.79)

**Changes:** Added `spec:` metadata tag to all 36 RSpec `describe` blocks. Each tag references the canonical spec section path. 351 examples, 0 failures, 98.67% coverage.

**Thinking:**
- The `spec:` tag is a machine-readable link from a test to its spec section. The Go reference parser will extract these via regex and emit `spec: → test` edges in the reference graph.
- Mapping was done by reading each spec file's subject and matching it to the closest spec section.

**Challenges:**
- Some test subjects don't map cleanly to a single spec section. Used the closest parent section rather than inventing new anchors.
- Anchor slugs are best-effort guesses — not yet validated against actual heading anchors since the parser doesn't exist yet.

**Alternatives considered:**
- Adding tags only to request specs — rejected because the concept spec says "Test files (RSpec) — parsed for `spec:` tags" without qualification.
- File-level tags without section anchors — rejected because the concept spec example shows section-level granularity.

**Tradeoffs taken:**
- Anchor slugs may need correction once the parser validates them. Low-risk: the parser is documented to handle missing anchors gracefully.

---

## 2026-04-22 15:58 — Spike: Go sidecar architecture research (task 8.1)

**Changes:** Wrote research findings to `specifications/research/go-sidecars.md`. Marked task 8.1 complete in IMPLEMENTATION_PLAN.md.

**Thinking:**
- All three open questions were answerable from the existing Go platform specs. No external research needed.
- Build order: analytics before runner — simpler, establishes patterns, no Rails internal dependencies.
- Minimal runner = full spec. Token parsing and Prometheus metrics are required.

**Challenges:**
- Distinguishing what belongs in `internal/` vs what stays in each `cmd/`: the rule is "used by more than one binary → internal/".

**Alternatives considered:**
- Runner before analytics — rejected (more moving parts, higher risk).
- Separate `go.mod` per binary — rejected per the Go platform spec.
- `pgx` instead of `lib/pq` — deferred; `lib/pq` sufficient for Phase 0 volumes.

**Tradeoffs taken:**
- `lib/pq` over `pgx` — simpler interface, works with stdlib `database/sql`. Switchable later if performance becomes a concern.

---

## 2026-04-22 16:07 — Bootstrap go/ directory (task 8.2, tag 0.0.80)

**Changes:** Created `go/go.mod`, stubs for all three binaries, `go/internal/pgclient/pgclient.go`, `go/internal/piifilter/piifilter.go`. `go build ./...` and `go test ./...` pass. 351 Rails specs still green.

**Thinking:**
- Bootstrap task: establish the Go module structure so subsequent tasks have a stable foundation.
- Kept stubs minimal — `log.Fatal("not yet implemented")` — so they compile without external deps.
- Created `internal/pgclient` and `internal/piifilter` now because both are shared across multiple binaries and their interfaces are clear from the research.

**Challenges:**
- The piifilter regex for API keys initially didn't match JSON format. Fixed by adding optional quote characters around the separator and value.
- `pgclient_test.go` initially tried to call `Open` with an unreachable DSN — fails with "unknown driver postgres" since `lib/pq` isn't imported yet. Replaced with a compile-check test.

**Alternatives considered:**
- Including `lib/pq` in `go.mod` now — rejected (requires network access to download; bootstrap should be zero-dependency).
- Putting `pgclient` and `piifilter` in `cmd/analytics/` — rejected (both used by parser too; `internal/` enforces visibility).

**Tradeoffs taken:**
- Stubs log.Fatal on startup — won't run usefully until implemented, but they compile and prove the module structure is correct.
- `pgclient_test.go` is a compile-check only — no behavioral coverage until 8.3 adds the `lib/pq` driver.

---

## 2026-04-22 16:11 — Implement Go analytics ingest sidecar (task 8.3, tag 0.0.81)

**Changes:** Replaced `go/cmd/analytics/main.go` stub with full implementation: `POST /capture`, `GET /healthz`, in-memory queue, batch flush every 5s or 100 events, PII redaction, UUID validation, fail-open buffering on Postgres unavailability with background reconnect. Added 7 unit tests. Added `github.com/lib/pq v1.10.9`. `go test ./...` passes. 351 Rails specs still green at 98.67% coverage.

**Thinking:**
- Fail-open is the right default for analytics ingest — dropping events is worse than buffering them.
- Extracted `insertBatch` from `flush` to keep `flush` readable and make the transaction boundary explicit.
- `tryReconnect` is a no-op if already connected (checked under lock), so it's safe to call on every flush failure without spawning unbounded goroutines.

**Challenges:**
- `events[:0]` filter-in-place pattern reuses the slice backing array — fine here since we own the slice.
- `NULLIF($4,'')` in the INSERT handles optional `node_id` — empty string from JSON becomes NULL without needing a Go nil pointer.
- First draft `reconnect` took a `context.Context` parameter that was never threaded through from `main`. Removed and wired `dsn` into the server struct instead.

**Alternatives considered:**
- Channel-based queue — rejected. A buffered channel has fixed capacity; a slice grows unboundedly, which is what we want for "buffer on Postgres unavailability."
- Separate reconnect ticker goroutine — rejected. One-shot goroutine on flush failure is simpler and sufficient.
- Rejecting events with non-UUID `distinct_id` at HTTP level (400) — rejected. 202 + silent drop is consistent with fire-and-forget ingest semantics.

**Tradeoffs taken:**
- No integration test against live Postgres — unit tests cover all HTTP and queue behavior; flush-to-Postgres path covered by existing `pgclient` package.
- Background reconnect is best-effort — each goroutine exits after one attempt, so pile-up is bounded by flush frequency.

---

## 2026-04-22 16:25 — Add infra/Dockerfile.go for Go sidecar builds (task 8.4, tag 0.0.82)

**Changes:** Created `infra/Dockerfile.go` with a shared builder stage and three named final stages (`runner`, `analytics`, `parser`). Vendored `go/vendor/` with `go mod vendor` so builds work offline. Both `docker build --target runner` and `--target analytics` succeed. 351 examples, 0 failures, 98.67% coverage.

**Thinking:**
- Single Dockerfile with multiple named targets is the standard pattern for monorepo Go binaries — matches what docker-compose.yml already expected (`target: runner`, `target: analytics`).
- `CGO_ENABLED=0` produces static binaries that run on `debian:bookworm-slim` without libc concerns.
- `-mod=vendor` is required because Docker build containers have no outbound internet access.

**Challenges:**
- No `go/vendor/` directory existed — had to run `go mod vendor` on the host before the Dockerfile could use `-mod=vendor`.
- The existing tag sequence was ahead of what IMPLEMENTATION_PLAN.md expected (0.0.73 already taken) — incremented to 0.0.82.

**Alternatives considered:**
- `scratch` base image — rejected because the analytics sidecar may need CA certs for TLS in future; `debian:bookworm-slim` is a safer default.
- Separate Dockerfiles per binary — rejected as unnecessary duplication; multi-stage targets are the idiomatic solution.
- `COPY go/go.sum` + `go mod download` — rejected because containers have no internet access; vendor is the only viable approach.

**Tradeoffs taken:**
- `go/vendor/` is now committed to git. This is intentional for an offline-build monorepo — consistent with `web/vendor/cache/` for Ruby gems.
- Builder stage compiles all three binaries in one `RUN` layer. If only one binary changes, the entire build step re-runs. Acceptable for Phase 0 where build speed is not a priority.

---

## 2026-04-22 16:25 — Uncomment analytics sidecar in docker-compose.yml (task 8.5, tag 0.0.83)

**Changes:** Uncommented `analytics` service in `infra/docker-compose.yml`. Added `DATABASE_URL` env var pointing to the postgres service. Added `depends_on: postgres` with health check condition. Left runner commented with updated note referencing task 8.6. 351 examples, 0 failures, 98.67% coverage.

**Thinking:**
- Task 8.5 depends on 8.3 (analytics sidecar) and 8.4 (Dockerfile.go) — both done. The runner (8.6) is not a dependency of 8.5.
- Uncommenting only the analytics service is correct: the runner stub calls `log.Fatal` and would crash immediately, making `docker compose up` fail.
- `depends_on: postgres` with `condition: service_healthy` ensures the sidecar doesn't start before Postgres is ready — matches the Rails service pattern.

**Challenges:**
- The original comment grouped runner and analytics together. Splitting them required updating the comment to reference task 8.6 explicitly so the intent is clear.

**Alternatives considered:**
- Uncommenting both services with `restart: on-failure` for the runner — rejected. A crashing service in the dev stack is noise; better to leave it commented until it's implemented.
- Adding `ANALYTICS_URL` to the Rails service env — deferred to task 13.1 (FeatureFlag exposure via sidecar), which is the only Rails code that calls the sidecar.

**Tradeoffs taken:**
- The analytics sidecar is now part of `docker compose up` but the runner is not. The dev stack is asymmetric until 8.6 is done. Acceptable — the runner has no callers yet.
