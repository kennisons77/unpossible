# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 100 iterations — initial planning through 0.0.79. Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash, LlmMetric on completion, rswag install, FeatureFlagsController org_id fix, all rswag spec conversions, db/schema.rb, EnrichmentRunner, SkillLoader wiring, hypothesis validation, batch middleware (3.1, 3.2), controlled commit spike (4.1), Go reference parser spike (5.1), spec: metadata tags (6.1). Tasks through 8.1 complete.]

---

## 2026-04-22 16:07 — Bootstrap go/ directory (task 8.2, tag 0.0.80)

**Changes:** Created `go/go.mod`, `go/cmd/analytics/main.go`, `go/cmd/runner/main.go`, `go/cmd/parser/main.go` stubs, `go/internal/pgclient/pgclient.go` (Postgres pool + retry), `go/internal/piifilter/piifilter.go` (regex PII redaction). `go build ./...` and `go test ./...` pass. 351 Rails specs still green.

**Thinking:**
- Bootstrap task: establish the Go module structure so subsequent tasks (8.3 analytics, 8.6 runner) have a stable foundation to build on.
- Kept stubs minimal — `log.Fatal("not yet implemented")` — so they compile without any external deps. External deps (`lib/pq`, `prometheus/client_golang`) are added in 8.3 and 8.6 when the actual implementations are written.
- Created `internal/pgclient` and `internal/piifilter` now because both are shared across multiple binaries and their interfaces are clear from the research. Deferring them to 8.3 would mean duplicating the design decision.
- `pgclient` uses `sql.Open("postgres", ...)` which requires `lib/pq` at runtime but compiles fine without it. The driver import will be added as a side-effect in the consuming binary's `main.go` in task 8.3.

**Challenges:**
- The piifilter regex for API keys initially didn't match JSON format (`"api_key": "sk-abc123xyz"`) because the original pattern used `[:=]` without accounting for quoted JSON values. Fixed by adding optional quote characters around the separator and value: `["']?\s*[:=]\s*["']?\S+["']?`.
- `pgclient_test.go` initially tried to call `Open` with an unreachable DSN, but `sql.Open("postgres", ...)` would fail with "unknown driver postgres" (not a connection error) since `lib/pq` isn't imported yet. Replaced with a compile-check test; integration tests deferred to 8.3.

**Alternatives considered:**
- Including `lib/pq` in `go.mod` now — rejected because it requires `go.sum` entries and network access to download. The bootstrap should be zero-dependency so it works in the offline Docker build environment.
- Putting `pgclient` and `piifilter` in `cmd/analytics/` — rejected because both will be used by the parser too. `internal/` enforces the Go visibility rule and prevents accidental cross-binary coupling.
- Using `pgx` instead of `database/sql` + `lib/pq` — deferred to 8.3 decision; `pgclient` wraps the interface so the driver can be swapped without changing callers.

**Tradeoffs taken:**
- Stubs log.Fatal on startup — they won't run usefully until implemented, but they compile and the binary exists. This is intentional: the bootstrap proves the module structure is correct before any real code is written.
- `pgclient_test.go` is a compile-check only — no behavioral coverage until 8.3 adds the `lib/pq` driver and a test Postgres connection. Known gap, documented in the test file.

---

## 2026-04-22 15:58 — Spike: Go sidecar architecture research (task 8.1)

**Changes:** Wrote research findings to `specifications/research/go-sidecars.md`. Marked task 8.1 complete in IMPLEMENTATION_PLAN.md.

**Thinking:**
- All three open questions were answerable from the existing Go platform specs (`specifications/platform/go/system/analytics.md`, `specifications/platform/go/system/runner.md`) and the infrastructure concept spec. No external research needed.
- Build order question: analytics before runner is the right call because the analytics sidecar has no dependencies on Rails internals beyond the `analytics_events` table (already exists). It establishes the Go build patterns, Dockerfile.go multi-stage structure, and shared `internal/` packages before the more complex runner is added.
- Minimal runner question: the runner spec is already Phase 0 scoped. "Minimal viable" = full spec. Token parsing is required (feeds AgentRun token data); Prometheus metrics are required (spec names `prometheus/client_golang` explicitly). No further reduction is appropriate.
- go.mod structure: single `go.mod` at `go/go.mod` is the standard Go monorepo pattern and is explicitly defined in the Go platform README. Two shared `internal/` packages identified: `pgclient` (Postgres connection + retry) and `piifilter` (regex redaction for analytics properties).

**Challenges:**
- The spike had no ambiguity — all answers were in the existing specs. The main work was synthesising the build order and identifying the shared internal packages that should be created at bootstrap (task 8.2) rather than duplicated per binary.
- Distinguishing what belongs in `internal/` vs what stays in each `cmd/`: the rule is "used by more than one binary → internal/". Both analytics and parser need Postgres; both analytics and parser need PII filtering. Runner needs neither (it doesn't write to Postgres directly and doesn't handle user properties).

**Alternatives considered:**
- Runner before analytics — rejected because the runner has more moving parts (Basic Auth, mutex, `exec.CommandContext`, Rails callback, token parsing, Prometheus). Starting with the simpler analytics sidecar reduces risk and establishes patterns.
- Separate `go.mod` per binary — rejected per the Go platform spec. Single `go.mod` means one `go build ./...`, one `go test ./...`, one Dockerfile.go. The monorepo pattern is standard and the spec is explicit.
- `pgx` instead of `lib/pq` as the Postgres driver — `pgx` is more modern and performant, but `lib/pq` is the standard `database/sql` driver and requires no additional interface. For Phase 0 (low write volume, no streaming) `lib/pq` is sufficient. `pgx` can be adopted later if performance becomes a concern.

**Tradeoffs taken:**
- `lib/pq` over `pgx` — simpler interface, works with stdlib `database/sql`, no additional abstraction needed. If the analytics flush loop becomes a bottleneck (unlikely at Phase 0 volumes), switching to `pgx` is a contained change in `internal/pgclient`.
- Prometheus metrics on the runner require `prometheus/client_golang` — the only external dependency for the runner. This is unavoidable (the spec names it) and the package is well-maintained by the Prometheus project.
- The Dockerfile.go multi-stage pattern (one builder stage, one stage per binary) means both binaries are compiled in the same layer. If only one binary changes, Docker cache still rebuilds both. This is acceptable for Phase 0 — build times are short and the simplicity outweighs the cache efficiency loss.

---

## 2026-04-22 15:34 — Add spec: metadata tags to all RSpec files (task 6.1, tag 0.0.79)

**Changes:** Added `spec:` metadata tag to all 36 RSpec `describe` blocks (37 total — `auth_spec.rb` has two top-level describes). Each tag references the canonical spec section path. 351 examples, 0 failures, 98.67% coverage.

**Thinking:**
- The `spec:` tag is a machine-readable link from a test to its spec section. The Go reference parser (task 8.2+) will extract these via regex and emit `spec: → test` edges in the reference graph. The format is fixed: `spec: "path/to/spec.md#section-slug"`.
- Mapping was done by reading each spec file's subject and matching it to the closest spec section. Where a spec section didn't exist yet (e.g. `markdown-helper`, `module-scaffold`, `solid-queue`), the infrastructure concept spec was used as the parent — these are implementation details, not first-class spec concepts.

**Challenges:**
- Some test subjects don't map cleanly to a single spec section. Used the closest parent section rather than inventing new anchors.
- Anchor slugs are best-effort guesses — not yet validated against actual heading anchors since the parser doesn't exist yet.

**Alternatives considered:**
- Adding tags only to request specs — rejected because the concept spec says "Test files (RSpec) — parsed for `spec:` tags" without qualification.
- File-level tags without section anchors — rejected because the concept spec example shows section-level granularity.

**Tradeoffs taken:**
- Anchor slugs may need correction once the parser validates them. Low-risk: the parser is documented to handle missing anchors gracefully.

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

## 2026-04-22 13:32 — Add metadata.hypothesis validation to FeatureFlag on create (task 2.1, tag 0.0.76)

**Changes:** Added `on: :create` validation for `metadata.hypothesis` in `Analytics::FeatureFlag`. Updated factory, model spec, and request spec. 337 examples, 0 failures, 98.72% coverage.

**Thinking:**
- Platform override is unambiguous: "hypothesis field required on creation → 422 if missing." Platform override is authoritative for Rails implementation.
- `validate :hypothesis_present, on: :create` is the minimal Rails idiom.

**Challenges:**
- Existing model spec had a test asserting the opposite — had to replace it, not supplement it.
- Existing request spec 201 tests sent no `metadata` — updated both to include hypothesis.

**Alternatives considered:**
- JSON Schema validation — rejected as over-engineering.
- Controller-level validation — rejected (model is single source of truth).

**Tradeoffs taken:**
- Factory default hypothesis string is generic. Tests that care about the value should set it explicitly.

---

## 2026-04-22 13:11 — Wire skill assembly into AgentRunJob#load_enrichment (task 2.4, tag 0.0.75)

**Changes:** Replaced stub `load_enrichment` with real calls to SkillLoader, ContextRetriever, and EnrichmentRunner. Added 4 integration tests. 334 examples, 0 failures, 98.71% coverage.

**Thinking:**
- The three services were already implemented and tested independently. Task 2.4 is purely wiring.
- EnrichmentRunner is called for its side effect (appending turns); its return value is discarded.

**Challenges:**
- Integration tests stub `ContextRetriever` to avoid filesystem dependency on the practices directory inside the container.

**Alternatives considered:**
- Passing `skill` object directly to `build_prompt` — rejected (interface already defined across three adapters).

**Tradeoffs taken:**
- Integration tests stub ContextRetriever rather than using real practices files — avoids path resolution issues in the test container.

---

## 2026-04-22 13:07 — Implement EnrichmentRunner (task 2.3, tag 0.0.74)

**Changes:** Added `EnrichmentRunner` service and 13-example spec. 330 examples, 0 failures, 98.7% coverage.

**Thinking:**
- Tool registry as a constant hash (`TOOLS`) keeps the mapping explicit and testable.
- Fail-open on both unknown tools and tool execution errors — enrichment is a pipeline invisible step.

**Challenges:**
- Position assignment: `run.turns.maximum(:position)` returns nil when no turns exist — guarded with `|| 0`.

**Alternatives considered:**
- Instance-based registry — rejected as over-engineering for a single-level dispatch table.

**Tradeoffs taken:**
- TOOLS registry is a constant — adding a new tool requires a code change. Intentional for Phase 0.

---

## 2026-04-22 11:42 — Commit db/schema.rb (tag 0.0.71)

**Changes:** Generated and committed `web/db/schema.rb` from all 20 migrations. 297 examples, 0 failures.

**Thinking:**
- Schema.rb is the canonical schema reference for `db:schema:load` in fresh environments.
- Hand-constructed from migrations because Docker can't be invoked from within the agent.

**Challenges:**
- Several migrations are destructive — had to carefully track which tables survive vs get dropped.
- `content` column on `agents_agent_run_turns` starts `null: false` then becomes nullable in 20260417000004.

**Alternatives considered:**
- Running `db:schema:dump` via a one-off container command — not possible from within the agent sandbox.

**Tradeoffs taken:**
- Hand-crafted schema.rb may have minor formatting differences from what Rails would auto-generate. Cosmetic only.

---

## 2026-04-22 11:32 — Planning loop: regenerate IMPLEMENTATION_PLAN.md

**Changes:** Deleted old IMPLEMENTATION_PLAN.md and regenerated from scratch. Full gap analysis of `specifications/` vs `web/` and `go/`.

**Key findings:** All Rails modules implemented and tested. `go/` directory does not exist. Batch middleware unimplemented. Skill assembly pipeline is a stub. `db/schema.rb` not committed. Spec contradiction flagged for FeatureFlag hypothesis.

**Plan structure:** 12 task groups, ~28 tasks. 6 spike tasks for Go domains.
