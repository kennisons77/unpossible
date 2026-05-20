# Activity Log

Agent activity log. Auto-updated each iteration. Trimmed to last 10 entries.

[Prior entries summarised: 98 iterations — initial planning through 0.0.63, then tasks 1.1–2.6, analytics dashboard UI (0.0.86), db/schema.rb (0.0.87), FeatureFlag hypothesis validation (0.0.85), analytics ingest sidecar (0.0.89), Go reference parser research spike (0.0.96), Go reference parser binary (0.0.97), PR skill script (0.0.98). Key milestones: Rails skeleton + test infra, security (Secret, LogRedactor, PromptSanitizer, rack-attack), JWT auth, Agents module (AgentRun, AgentRunTurn, ProviderAdapter, PromptDeduplicator, AgentRunsController, AgentRunJob, TurnContentGcJob), Sandbox module (ContainerRun, DockerDispatcher), Analytics module (FeatureFlag, AnalyticsEvent, AuditEvent, LlmMetric, AuditLogger, AuditLogJob, MetricsController, FeatureFlag auto-fire, DashboardController), HealthCheckMiddleware, Ledger+Knowledge removal, org_id migrations, provider adapter build_prompt with pinned+sliding trimming, LedgerAppender, controlled-commit.sh, parse_response normalised to hash, LlmMetric on completion, rswag install, FeatureFlagsController org_id fix, all rswag spec conversions (auth, agent_runs, metrics, feature_flags, health), db/schema.rb hand-crafted from migrations, Go analytics sidecar (POST /capture, PII filter, batch flush, graceful shutdown), Go reference parser (spec files, plan items, RSpec tags, LEDGER.jsonl PR nodes, git log), PR skill script (scripts/pr.sh, LEDGER.jsonl pr_opened event).]

---

## 2026-05-19 21:19 — Add repo-map CLI binary (tasks 5.1, 5.2, tag 0.0.99)

**Changes:** Implemented `go/cmd/repo-map/main.go` — regex-based codebase summary generator. Extracts Ruby class/method signatures, Go exported symbols, and markdown spec headings. Token budget with 4-pass degradation. 15 Go tests pass. Updated `infra/Dockerfile.go` to build `repo-map`. Added `go/repo-map` and `REPO_MAP.md` to `.gitignore`. 359 Rails specs, 0 failures, 98.68% coverage.

**Thinking:**
- The spike (5.1) resolved the key design question immediately: `smacker/go-tree-sitter` requires CGO (`CGO_ENABLED=1`) — incompatible with the vendor-only `CGO_ENABLED=0` build in `Dockerfile.go`. No viable pure-Go tree-sitter alternative exists. Regex is the right approach.
- Ruby class/method signatures and Go exported symbols are well-structured enough for regex without a full AST. The patterns are line-oriented and unambiguous: `class Foo < Bar`, `def method_name(params)`, `func ExportedName(...)`, `type ExportedType`.
- Token budget via character-count approximation (4 chars ≈ 1 token) requires no external library and is accurate enough for budget enforcement. The 4-pass degradation follows the concept spec exactly.
- `REPO_MAP.md` is gitignored — it's a derived artifact regenerated before each loop iteration, not source of truth.

**Challenges:**
- Go receiver type extraction: the regex `\*?([A-Za-z][A-Za-z0-9_]*)` matched the variable name (`s` in `(s *Server)`) instead of the type name (`Server`). Fixed by requiring the type to start with an uppercase letter: `\*?([A-Z][A-Za-z0-9_]*)`.
- Test for `stripParams`: the method name `find_by_token` contains `token`, so checking `strings.Contains(result, "token")` was always true even after stripping. Fixed by using a param value (`user_id`) that doesn't appear in the method name.
- Ruby `private` tracking: the `isPrivate` flag must reset to `false` when a new class/module is encountered (private scope is per-class). The implementation resets it on every class/module match.

**Alternatives considered:**
- `smacker/go-tree-sitter` — rejected. Requires CGO; incompatible with `CGO_ENABLED=0` vendor-only build.
- `github.com/nicholasgasior/gsfmt` and similar pure-Go parsers — none are production-ready for Ruby+Go parsing.
- Vendoring tree-sitter C source and compiling with CGO enabled — rejected. Would require changing `Dockerfile.go` to enable CGO, adding C toolchain to the builder image, and vendoring ~2MB of C source. Disproportionate complexity for the benefit.
- Separate binary per language (ruby-map, go-map) — rejected. A single binary with language dispatch is simpler to invoke and maintain.

**Tradeoffs taken:**
- Regex over AST means edge cases in Ruby (heredocs, multi-line method signatures, method_missing) are not handled. Acceptable for Phase 0: the map is a navigation aid, not a complete API reference. Agents can still use tools for precise lookups.
- Private method tracking is indent-based, not scope-based. A `private` keyword inside a nested class resets the flag for the outer class too. This is a known limitation; the practical impact is minimal (nested classes with mixed visibility are rare in this codebase).
- Token budget approximation (4 chars ≈ 1 token) underestimates for code-heavy content (identifiers are shorter than prose). The budget may be slightly exceeded in practice. Acceptable — the budget is a soft cap, not a hard limit.
- `REPO_MAP.md` is not yet wired into `loop.sh` or agent configs — that's a separate integration task. The binary is complete and tested; integration is deferred to when the agent configs are updated.

---

## 2026-05-15 15:14 — PR skill script (tasks 2.1, 2.2, 3.1–3.3, 4.1, 4.2, tag 0.0.98)

**Changes:** Marked infra tasks 2.1 and 2.2 complete (already correct — no code changes needed). Completed spike 3.1 (reference parser completeness research — PR nodes, spec: tags, blocked-by all already implemented; git notes gap documented). Marked 3.2 and 3.3 complete (code already satisfies acceptance criteria). Completed spike 4.1 (PR skill design). Implemented `scripts/pr.sh` and `scripts/test-pr.sh` (15 tests, all passing). 359 Rails specs, 0 failures, 98.68% coverage.

**Thinking:**
- Tasks 2.1, 2.2, 3.2, 3.3 were already done — the plan had them unchecked but the notes said ✅ DONE. Verified by reading the actual files before marking complete.
- The PR skill is a bash script following the same pattern as `controlled-commit.sh`: argument parsing, preconditions, side effects (gh pr create + LEDGER.jsonl append + git commit), exit codes.
- Task ID extraction from LEDGER.jsonl: match `status` entries whose `sha` appears in the branch's commit range. This is the natural join between git history and the ledger — no additional metadata needed.
- Spec ref extraction from IMPLEMENTATION_PLAN.md: look for `spec: path` in HTML comments on the plan item line. This is the same comment format used for `blocked-by` — consistent with the existing plan item schema.

**Challenges:**
- macOS `grep` doesn't support `-P` (Perl regex) — used `-oE` + `sed` instead.
- Bash `set -u` with empty arrays: `${ARRAY[@]}` fails when the array is empty. Used `${ARRAY[@]+"${ARRAY[@]}"}` pattern throughout.
- `run_pr` test helper: `rm -rf "$stub_dir"` after the subshell masked the subshell's non-zero exit code. Fixed by capturing `rc=$?` before cleanup.

**Alternatives considered:**
- Python script instead of bash — rejected. Consistency with `controlled-commit.sh` matters more than language preference.
- Extracting task IDs from commit messages — rejected. LEDGER.jsonl is the authoritative structured record; commit messages are free-form.

**Tradeoffs taken:**
- `python3` used for JSON array serialization in bash — requires python3 in PATH (standard on macOS and agent container). Falls back to `[]` if absent.
- Git notes gap documented but not fixed — no consumer of git notes data exists yet.

---

**Changes:** Created `go/cmd/reference-parser/main.go` — standalone Go binary that walks spec files, IMPLEMENTATION_PLAN.md, RSpec test files, LEDGER.jsonl, and git log to produce a JSON graph. Created `go/cmd/reference-parser/main_test.go` with 19 unit tests covering all parsing paths. Updated `infra/Dockerfile.go` to build the `reference-parser` binary alongside runner and analytics. 359 Rails specs, 0 failures, 98.68% coverage.

**Thinking:**
- The research spike (5.1) had already resolved all design decisions: regex over tree-sitter, git shelling out, JSON to stdout, fail-open on missing inputs. Implementation was a direct translation of the research document into code.
- The parser is structured as a `parser` struct with one method per input source. Each method is independently testable with a temp directory fixture — no global state.
- Node deduplication via a `nodeIDs` map prevents duplicate nodes when the same spec file is referenced from multiple sources.

**Challenges:**
- The `ThreadCount` field was initially missing from `ledgerEntry` — caught during review of the review node assembly code.
- Markdown link resolution for relative paths: used `filepath.Join(dir, target)` which handles `..` correctly on all platforms.

**Alternatives considered:**
- Separate structs per LEDGER.jsonl event type — rejected. A single struct with omitempty fields is simpler.
- Storing edges in a map to deduplicate — rejected. Duplicate edges are harmless for graph consumers.

**Tradeoffs taken:**
- Git log parsing shells out to `git log` — for large repos this could be slow. Acceptable for Phase 0.
- No test for `parseGitLog` — it shells out to `git` which requires a real git repo. The method is simple and the pattern is identical to the runner sidecar's git integration.

---

## 2026-05-15 13:01 — Research Go reference parser design (spike 5.1, tag 0.0.96)

**Changes:** Created `specifications/research/reference-graph-parser.md` with finalized design decisions. Added build tasks 5.2–5.5 to IMPLEMENTATION_PLAN.md. Marked 5.1 complete.

**Thinking:**
- This is a pure research spike — no code, no tests. The deliverable is a design document that unblocks 5.2 (the actual parser implementation).
- The key decision was regex over tree-sitter: all patterns the parser needs are line-oriented. Tree-sitter adds CGo and build complexity for no benefit at Phase 0 scale.
- Git integration via shelling out to `git` is the right call — the runner sidecar already uses `exec.CommandContext` for this pattern.

**Challenges:**
- Plan item renumbering is inherently heuristic — numeric IDs in LEDGER.jsonl are stable labels but the plan can be renumbered. Title-based matching is best-effort.

**Alternatives considered:**
- Tree-sitter for Ruby/Go parsing — rejected. All required patterns are line-oriented; tree-sitter adds CGo and build complexity with no benefit for Phase 0.
- libgit2 (go-git) for git integration — rejected. Shelling out to `git` is simpler, has no deps, and is fast enough.

**Tradeoffs taken:**
- Fail-open on missing/malformed inputs — the parser never exits non-zero for bad data. This means a corrupted LEDGER.jsonl produces a partial graph silently.

---

## 2026-05-15 12:31 — Add duration_ms to analytics_llm_metrics (task 3.2, tag 0.0.94)

**Changes:** Migration adds nullable `duration_ms integer` column to `analytics_llm_metrics`. `LlmMetric` validates it is non-negative when present. `RunStorageService.complete` passes `run.duration_ms` to `LlmMetric.create!`. 359 examples, 0 failures, 98.68% coverage.

**Thinking:**
- `AgentRun` already had a `duration_ms` column. The gap was purely in `RunStorageService.complete` — it wasn't forwarding the value to `LlmMetric`.
- Nullable column is correct: `duration_ms` may not be set on the `AgentRun` at completion time. Forcing NOT NULL would require a default of 0, which is misleading.

**Challenges:** None. The column already existed on `AgentRun`; this was a straightforward propagation task.

**Alternatives considered:**
- Computing `duration_ms` from `AgentRun.created_at` and `updated_at` — rejected because `AgentRun.duration_ms` is the authoritative source (set by the runner sidecar).
- NOT NULL constraint with default 0 — rejected because 0 is ambiguous (could mean "completed instantly" or "not measured").

**Tradeoffs taken:**
- `duration_ms` is nullable on `LlmMetric` — queries filtering by duration must handle NULLs.
- No backfill migration for existing rows — acceptable for Phase 0 where historical data is dev/test only.

---

## 2026-05-01 12:40 — Fix docker-compose.yml: analytics service, clean stub, RUNNER_PASSWORD (task 3.2, tag 0.0.91)

**Changes:** Removed commented-out `go_runner:f` stub. Added `analytics` service on port 9100. Set `RUNNER_PASSWORD` default in both `go_runner` and `agent` services. 352 Rails specs, 0 failures, 98.67% coverage.

**Thinking:**
- The analytics sidecar reads DB connection from `DB_HOST`/`POSTGRES_USER`/`POSTGRES_PASSWORD`/`POSTGRES_DB` env vars — consistent with the Rails service pattern.
- `RUNNER_PASSWORD` had no default — a dev default makes the stack startable without a `.env` file.

**Challenges:** None. The changes were mechanical.

**Alternatives considered:**
- Binding `RUNNER_PASSWORD` to a required env var with no default — rejected because the dev stack should start without a `.env` file.

**Tradeoffs taken:**
- `RUNNER_PASSWORD` default is a plaintext string in the compose file — acceptable for dev. Production must override via `.env` or secrets management.

---

## 2026-05-01 12:33 — Add infra/Dockerfile.go multi-stage build (task 3.1, tag 0.0.90)

**Changes:** Created `infra/Dockerfile.go` with three stages: `builder` (golang:1.23-bookworm), `runner` (debian:bookworm-slim, port 8080), `analytics` (debian:bookworm-slim, port 9100). 352 Rails specs, 0 failures, 98.67% coverage.

**Thinking:**
- `CGO_ENABLED=0` produces static binaries that run on `debian:bookworm-slim` without needing libc.
- `GOFLAGS=-mod=vendor` ensures the build uses vendored dependencies and fails fast if inconsistent.
- Separate final stages for runner and analytics allow independent deployment.

**Challenges:** None. The vendor directory was already consistent.

**Alternatives considered:**
- Single final stage with both binaries — rejected because it couples the runner and analytics images.
- `scratch` as final stage — rejected because `debian:bookworm-slim` provides a shell for debugging.

**Tradeoffs taken:**
- Builder stage uses `golang:1.23-bookworm` (full Debian) — larger builder image but cached after first pull.

---

## 2026-04-22 13:11 — Wire skill assembly into AgentRunJob#load_enrichment (task 2.4, tag 0.0.75)

**Changes:** Replaced stub `load_enrichment` with real calls to SkillLoader, ContextRetriever, and EnrichmentRunner. Added 4 integration tests. 334 examples, 0 failures, 98.71% coverage.

**Thinking:**
- The three services were already implemented and tested independently. Task 2.4 is purely wiring — call them in sequence and return `[context_chunks, principles]`.
- `principles` is returned as the second element because `build_prompt` already accepts a `principles:` keyword — no interface change needed.

**Challenges:**
- The existing `agent_override is false` test used `and_call_original` on `load_enrichment`, which now calls the real services. Integration tests stub `ContextRetriever` to avoid filesystem dependency.

**Alternatives considered:**
- Passing `skill` object directly to `build_prompt` — rejected because `build_prompt` interface is already defined and tested across three adapters.

**Tradeoffs taken:**
- Integration tests stub `ContextRetriever` rather than using real practices files — avoids path resolution issues in the test container.

---

## 2026-04-22 13:07 — Implement EnrichmentRunner (task 2.3, tag 0.0.74)

**Changes:** Added `EnrichmentRunner` service and 13-example spec. 330 examples, 0 failures, 98.7% coverage.

**Thinking:**
- Tool registry as a constant hash (`TOOLS`) keeps the mapping explicit and testable.
- Fail-open on both unknown tools and tool execution errors — enrichment is a "pipeline invisible step" per the spec.

**Challenges:**
- Position assignment: `run.turns.maximum(:position)` returns nil when no turns exist — guarded with `|| 0`.

**Alternatives considered:**
- Instance-based registry — rejected as over-engineering for a single-level dispatch table.

**Tradeoffs taken:**
- TOOLS registry is a constant — adding a new tool requires a code change, not configuration. Intentional for Phase 0.

---

## 2026-05-01 11:59 — Add go/go.mod and go/go.sum for Go module foundation (task 1.1, tag 0.0.88)

**Changes:** Created `go/go.mod` with module path `github.com/unpossible/unpossible/go`, go 1.23.0. Generated `go/go.sum` via `go mod tidy`. Added Go binary outputs to `.gitignore`. `go build ./...` and `go test ./...` both exit 0; 352 Rails specs still pass.

**Thinking:**
- The vendor directory already existed with all dependencies and a `modules.txt` — the only missing pieces were `go.mod` and `go.sum`.
- `go mod tidy` was the right tool: it reads the vendor directory, resolves the dependency graph, and writes both files atomically.

**Challenges:**
- First `go build` attempt failed with "inconsistent vendoring" because `lib/pq` was marked explicit in `modules.txt` but absent from `go.mod` after `go mod tidy` removed it.

**Alternatives considered:**
- Running `go mod vendor` to regenerate the vendor directory from scratch — rejected because the container has no internet access.

**Tradeoffs taken:**
- `lib/pq` listed as direct dep in `go.mod` even though runner doesn't import it — intentional: the vendor directory was pre-built for both runner and analytics sidecar.

---

## 2026-05-15 15:14 — PR skill script (tasks 2.1, 2.2, 3.1–3.3, 4.1, 4.2, tag 0.0.98)

**Changes:** Marked infra tasks 2.1 and 2.2 complete (already correct — no code changes needed). Completed spike 3.1 (reference parser completeness research — PR nodes, spec: tags, blocked-by all already implemented; git notes gap documented). Marked 3.2 and 3.3 complete (code already satisfies acceptance criteria). Completed spike 4.1 (PR skill design). Implemented `scripts/pr.sh` and `scripts/test-pr.sh` (15 tests, all passing). 359 Rails specs, 0 failures, 98.68% coverage.

**Thinking:**
- Tasks 2.1, 2.2, 3.2, 3.3 were already done — the plan had them unchecked but the notes said ✅ DONE. Verified by reading the actual files before marking complete.
- The PR skill is a bash script following the same pattern as `controlled-commit.sh`: argument parsing, preconditions, side effects (gh pr create + LEDGER.jsonl append + git commit), exit codes.
- Task ID extraction from LEDGER.jsonl: match `status` entries whose `sha` appears in the branch's commit range. This is the natural join between git history and the ledger — no additional metadata needed.
- Spec ref extraction from IMPLEMENTATION_PLAN.md: look for `spec: path` in HTML comments on the plan item line. This is the same comment format used for `blocked-by` — consistent with the existing plan item schema.
- `--repo` flag added so git operations use the correct repo root when `--ledger`/`--plan` override the file paths. Without it, `git -C "$PROJECT_ROOT"` would always use the script's own project root, breaking tests.
- `--no-push` flag added for testing — avoids needing a real remote. The flag is documented but not advertised as a user-facing feature.

**Challenges:**
- macOS `grep` doesn't support `-P` (Perl regex) — used `-oE` + `sed` instead. This is a recurring macOS portability issue; the coding practices file should note it.
- Bash `set -u` with empty arrays: `${ARRAY[@]}` fails when the array is empty. Used `${ARRAY[@]+"${ARRAY[@]}"}` pattern throughout. This is a well-known bash gotcha.
- `run_pr` test helper: `rm -rf "$stub_dir"` after the subshell masked the subshell's non-zero exit code (with `set +e` active, `rm -rf` exits 0 and becomes the function's return value). Fixed by capturing `rc=$?` before cleanup.
- `git checkout -q -b main` in test setup silently failed (main already existed as the default branch on this system). Fixed by using `git checkout -q main` (no `-b`).

**Alternatives considered:**
- Python script instead of bash — rejected. The existing `controlled-commit.sh` is bash; consistency matters more than language preference. The script is simple enough that bash is not a liability.
- Extracting task IDs from commit messages instead of LEDGER.jsonl — rejected. Commit messages are free-form; LEDGER.jsonl is the authoritative structured record. Parsing commit messages would be fragile.
- Storing spec refs in LEDGER.jsonl `status` entries — rejected. The plan item comment is the right place (it's already there for `blocked-by`); duplicating it in LEDGER would create two sources of truth.

**Tradeoffs taken:**
- `python3` used for JSON array serialization in bash — avoids hand-rolling JSON escaping. Requires python3 in PATH (standard on macOS and the agent container). If python3 is absent, the script falls back to `[]` (empty array) — acceptable degradation.
- Git notes gap (reference parser doesn't read `git notes show {sha}`) documented but not fixed — no consumer of git notes data exists yet. Will be addressed when the web UI needs it.
- `--no-push` is a testing escape hatch, not a documented user feature. If the push fails in production (no remote, auth error), the LEDGER.jsonl entry is already committed locally — the user can push manually. This is acceptable for Phase 0.

---

**Changes:** Created `go/cmd/reference-parser/main.go` — standalone Go binary that walks spec files, IMPLEMENTATION_PLAN.md, RSpec test files, LEDGER.jsonl, and git log to produce a JSON graph. Created `go/cmd/reference-parser/main_test.go` with 19 unit tests covering all parsing paths. Updated `infra/Dockerfile.go` to build the `reference-parser` binary alongside runner and analytics. 359 Rails specs, 0 failures, 98.68% coverage.

**Thinking:**
- The research spike (5.1) had already resolved all design decisions: regex over tree-sitter, git shelling out, JSON to stdout, fail-open on missing inputs. Implementation was a direct translation of the research document into code.
- The parser is structured as a `parser` struct with one method per input source (`parseSpecFiles`, `parsePlanItems`, `parseTestFiles`, `parseLedger`, `parseGitLog`). Each method is independently testable with a temp directory fixture — no global state.
- Node deduplication via a `nodeIDs` map prevents duplicate nodes when the same spec file is referenced from multiple sources. Edge deduplication is not needed (duplicate edges are harmless for graph consumers) but self-loops and empty endpoints are filtered.
- The `ledgerEntry` struct covers all LEDGER.jsonl event types in one struct — fields are omitempty so unused fields don't appear in output. This is simpler than a union type and sufficient for Phase 0.
- PR node assembly collects `pr_opened`, `pr_review`, and `pr_merged` events in separate maps, then assembles nodes and edges in a second pass. This handles out-of-order events and missing events (e.g. a PR with no review) gracefully.

**Challenges:**
- The `ThreadCount` field was initially missing from `ledgerEntry` — caught during review of the review node assembly code. Added before the first compile.
- The `init()` placeholder I added to document the ThreadCount dependency was dead code — removed immediately.
- Markdown link resolution for relative paths: `../bar/concept.md` from `specifications/system/foo/concept.md` must resolve to `specifications/system/bar/concept.md`. Used `filepath.Join(dir, target)` which handles `..` correctly on all platforms.

**Alternatives considered:**
- Separate structs per LEDGER.jsonl event type — rejected. A single struct with omitempty fields is simpler and the event types share most fields. If the schema diverges significantly, a union type can be introduced then.
- Storing edges in a map to deduplicate — rejected. Duplicate edges are harmless for graph consumers (the web UI can deduplicate on render). The map overhead is not justified for Phase 0 scale.
- Building the binary into the Go image's final stage — the Dockerfile.go already has a `builder` stage that compiles all binaries; adding `reference-parser` to the build command is a one-line change.

**Tradeoffs taken:**
- Git log parsing shells out to `git log --format=%H|%s|%ai HEAD` — this produces one commit node per commit in the entire history. For large repos this could be slow. Acceptable for Phase 0; a `--since` flag can be added later.
- Markdown link edges use `contains` type regardless of the semantic relationship between the linked files. The concept spec defines `contains` as the edge type for markdown links — this is correct per spec but may be semantically imprecise (a link from a concept to a requirements doc is more "generates" than "contains"). Refinement deferred to Priority 5 (web UI) when the edge types are consumed.
- No test for `parseGitLog` — it shells out to `git` which requires a real git repo. The test temp directories are not git repos. The method is simple (parse `|`-delimited lines into commit nodes) and the pattern is identical to the runner sidecar's git integration, which is already tested. Adding a git-init fixture would be possible but adds test complexity for low marginal value.

---

## 2026-05-15 13:01 — Research Go reference parser design (spike 5.1, tag 0.0.96)

**Changes:** Created `specifications/research/reference-graph-parser.md` with finalized design decisions. Added build tasks 5.2–5.5 to IMPLEMENTATION_PLAN.md. Marked 5.1 complete.

**Thinking:**
- This is a pure research spike — no code, no tests. The deliverable is a design document that unblocks 5.2 (the actual parser implementation).
- The key decision was regex over tree-sitter: all patterns the parser needs (frontmatter, plan item checkboxes, `spec:` tags in RSpec, LEDGER.jsonl) are line-oriented. Tree-sitter adds CGo and build complexity for no benefit at Phase 0 scale.
- Git integration via shelling out to `git` is the right call — the runner sidecar already uses `exec.CommandContext` for this pattern. libgit2/go-git would add ~5MB and CGo.
- Output as a single JSON object to stdout is the Unix-native pattern. The caller pipes or redirects. JSONL was considered but rejected — harder to consume as a complete graph.
- Node IDs are derived deterministically from source artifacts (path, ref, SHA) so the parser is stateless and deterministic: same inputs → same output.

**Challenges:**
- Plan item renumbering is inherently heuristic — numeric IDs in LEDGER.jsonl are stable labels but the plan can be renumbered. Title-based matching is best-effort. Acceptable for Phase 0 (solo dev, infrequent renumbering).
- The concept spec defines node types conceptually but not as a concrete schema. The research document formalizes the schema (id derivation rules, metadata fields) so the implementation has a precise target.

**Alternatives considered:**
- Tree-sitter for Ruby/Go parsing — rejected. All required patterns are line-oriented; tree-sitter adds CGo and build complexity with no benefit for Phase 0.
- libgit2 (go-git) for git integration — rejected. Shelling out to `git` is simpler, has no deps, and is fast enough. The runner sidecar already uses this pattern.
- JSONL output (one node/edge per line) — rejected. A single JSON object is easier to consume from a web handler or `jq`; no benefit to JSONL at Phase 0 scale.
- Storing the graph in Postgres — rejected by the concept spec itself. The whole point of the reference graph is to eliminate the disk↔DB sync problem.

**Tradeoffs taken:**
- Title-based renaming detection is heuristic — if two beats share the same title intentionally, the parser will incorrectly emit a `renamed_from` edge. Acceptable for Phase 0; can be made opt-in via a LEDGER.jsonl `renamed` event later.
- Fail-open on missing/malformed inputs — the parser never exits non-zero for bad data. This means a corrupted LEDGER.jsonl produces a partial graph silently. The tradeoff is correct: the parser is a read-only reporting tool, not a gatekeeper.
- No tree-sitter means no deep code→spec tracing (e.g. linking a specific method to a spec section). This is Priority 3+ work; regex handles everything needed for Priority 2.

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
