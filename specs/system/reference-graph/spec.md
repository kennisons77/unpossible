# Reference Graph

- **Status:** Draft
- **Created:** 2026-04-14

## What It Does

Replaces the Postgres-backed ledger with a file-and-git-native system for tracking
project state, enforcing spec-to-code traceability, and producing a navigable graph
for humans and agents. No separate database for project state. Postgres is retained
only for operational metrics (agent runs, analytics).

## Why It Exists

The ledger module introduced a sync problem: files on disk and rows in Postgres had to
agree, requiring SpecWatcherJob, PlanFileSyncService, conflict detection, and stable_ref
hashing. The complexity was not justified by the value delivered. The question/answer
mental model is sound — but the storage layer should be files and git, not a parallel
database.

The reference graph preserves the question/answer hierarchy (ideology → concept →
practice → specification → code) as a convention in how files are organized and linked,
not as database columns. A deterministic parser reconstructs the graph on demand from
the artifacts that already exist.

## Design Decisions

- **Files + git are the source of truth** for all project state: specs, plans, status,
  dependencies, acceptance, audit trail.
- **Postgres is retained** for operational metrics only: AgentRun, AgentRunTurn,
  analytics events, feature flags.
- **No disk↔DB sync.** The graph is derived from files at query time, never maintained
  as a separate stateful system.
- **The question/answer model is preserved** as a file convention, not a schema.
  Specs are questions. PRDs, commits, research findings are answers. Tests are
  acceptance records.
- **Tests are the enforcement mechanism** for spec drift. Quantitative values live as
  constants in tests with comments referencing the spec section. Qualitative drift is
  detected by CI comparing spec content hashes against the last green run.

## Components

### 1. Controlled Commit Skill (Priority 1)

A skill invoked by the build loop that atomically commits code, appends to LEDGER.jsonl,
and updates IMPLEMENTATION_PLAN.md. The agent never runs raw `git commit` — it always
goes through this skill.

Atomic sequence:
1. Stage code changes
2. Append LEDGER.jsonl entry (status transition)
3. Update IMPLEMENTATION_PLAN.md (check box, update status comment)
4. `git add` all staged files + LEDGER.jsonl + IMPLEMENTATION_PLAN.md
5. `git commit` with structured message
6. Optionally `git notes add` for rich context (screenshots, flowcharts, reasoning)

If the commit fails, nothing is recorded. Consistency is guaranteed by git's atomicity.

### 2. Go Reference Parser (Priority 2)

A standalone Go binary that walks the file tree, git history, and LEDGER.jsonl to
produce a JSON graph. The graph is computed, not stored. Re-run on any change.

Inputs:
- Spec files (markdown) — parsed for frontmatter, section headers, inter-file links
- IMPLEMENTATION_PLAN.md — parsed for beat items with structured metadata
- Test files (RSpec) — parsed for `spec:` tags linking to spec sections
- LEDGER.jsonl — parsed for status transitions, blocking events
- Git log — commits, messages, SHAs
- Git notes — rich blobs attached to commits

Output: JSON graph of nodes and edges suitable for web UI consumption.

Node types (derived from file conventions, not a database enum):
- Spec section → question
- PRD → generative answer
- Beat (plan item) → question
- Commit → terminal answer
- Passing test suite → acceptance
- Failing test → rebuttal
- Research finding → terminal answer

Edge types (derived from file references):
- Markdown link between files → contains
- `blocked-by` in plan item → depends_on
- `spec:` tag in test → refs
- Git SHA in LEDGER.jsonl → refs

### 3. Spec Reference Tags in Tests (Priority 3)

Convention for linking RSpec tests to spec sections:

```ruby
RSpec.describe "Rate limiting", spec: "specs/system/api/spec.md#rate-limiting" do
  # From spec: "Requests are throttled at 100 per minute per API key"
  RATE_LIMIT_THRESHOLD = 100

  it "returns 429 when threshold exceeded" do
    (RATE_LIMIT_THRESHOLD + 1).times { get "/api/nodes" }
    expect(response).to have_http_status(429)
  end
end
```

Quantitative values from specs are referenced constants in tests — not parsed from
markdown at runtime. A comment above the constant cites the spec section. The `spec:`
metadata tag is the machine-readable link.

### 4. CI Drift Detection (Priority 4)

A CI step that compares spec content hashes against recorded hashes from the last green
run. When a spec section changes after its linked tests last passed, the CI step flags
it as "spec changed — tests may need review." Does not fail the build — surfaces drift
for human or agent review.

Content hashes are recorded in LEDGER.jsonl as `spec_changed` events by the reference
parser or a pre-commit hook.

### 5. Read-Only Web UI (Priority 5)

Server-rendered HTML that consumes the reference parser's JSON output. No editing — all
state changes happen in files and git.

Views (carried forward from ledger UI spec):
- **Current** — the in-progress beat and its ancestor chain (spec → PRD → pitch)
- **Open** — all non-done plan items, filterable by status and scope
- **Condensed** — full project tree, collapsible, with text search

### 6. Ledger + Knowledge Module Removal (Priority 6)

Remove all Postgres-backed ledger code:
- Models: Node, NodeEdge, NodeAuditEvent, Actor, ActorProfile, Project
- Services: TransitionService, VerdictService, NodeLifecycleService, NodeFactory,
  LedgerSnapshotService, PlanFileSyncService
- Controllers: NodesController, LedgerController
- Jobs: SpecWatcherJob
- Views: ledger UI templates

Remove all Knowledge module code:
- Models: LibraryItem
- Services: MdChunker, EmbedderService, OpenAiEmbedder, ContextRetriever
- Jobs: IndexerJob

Remove associated migrations, specs, and factories. Drop tables.

Retain: Agents module (AgentRun, AgentRunTurn), Analytics module, Sandbox module.

Update AgentRun to remove FK references to ledger Node/Actor. Replace `node_id` and
`actor_id` with string references (spec path or plan item ref) that the reference
parser can resolve.

### 7. Future: LLM-Resolved Acceptance Tests

A testing layer that uses Playwright MCP to evaluate amorphous acceptance criteria
(usability, clarity, responsiveness) via LLM judgment. Run on demand or in CI, not in
the tight build loop. Cost-controlled. Requires a separate spike and workflow definition.

## File Schemas

### LEDGER.jsonl

Append-only. One JSON object per line.

```json
{"ts":"2026-04-14T19:51:00Z","type":"status","ref":"12.5","from":"todo","to":"in_progress","sha":null,"reason":"picked up by build loop"}
{"ts":"2026-04-14T19:52:00Z","type":"status","ref":"12.5","from":"in_progress","to":"done","sha":"abc123f","reason":"tests green, 284 examples 0 failures"}
{"ts":"2026-04-14T19:53:00Z","type":"blocked","ref":"13.1","by":"12.5","reason":"needs IndexerJob"}
{"ts":"2026-04-14T19:53:30Z","type":"unblocked","ref":"13.1","by":"12.5","reason":"12.5 completed"}
{"ts":"2026-04-14T20:00:00Z","type":"spec_changed","path":"specs/system/api/spec.md","section":"rate-limiting","sha":"def456a","content_hash":"sha256:..."}
```

Event types: `status`, `blocked`, `unblocked`, `spec_changed`.

### IMPLEMENTATION_PLAN.md item format

```markdown
- [ ] 13.1 — Agent commit skill <!-- status: todo, spec: specs/system/agent-runner/spec.md#commit-protocol, test: spec/skills/commit_skill_spec.rb -->
- [ ] 13.2 — Reference parser <!-- status: blocked, blocked-by: 13.1, spec: specs/system/reference-graph/spec.md#go-reference-parser, test: n/a -->
- [x] 12.1 — LibraryItem model <!-- status: done, spec: specs/system/knowledge/spec.md#library-item, test: spec/models/knowledge/library_item_spec.rb -->
```

Status values: `todo`, `in_progress`, `done`, `blocked`.

### Git Notes

Used for rich blobs that don't belong in commit messages or LEDGER.jsonl: screenshots,
flowcharts, extended reasoning, research summaries. Attached to specific commits.
Pushed via `git push origin refs/notes/*`.

## Modules Affected

| Module | Action |
|---|---|
| Ledger | Remove entirely |
| Knowledge | Remove entirely |
| Agents | Retain. Update FKs to use string refs instead of ledger Node/Actor |
| Analytics | Retain unchanged. `node_id` on events becomes a string ref |
| Sandbox | Retain unchanged |

## Acceptance Criteria

- Controlled commit skill atomically updates code + LEDGER.jsonl + IMPLEMENTATION_PLAN.md in a single git commit
- LEDGER.jsonl is append-only — entries are never modified or deleted
- Reference parser produces a JSON graph from files + git + LEDGER.jsonl
- Reference parser is deterministic — same inputs always produce same output
- Reference parser runs as a standalone Go binary with no runtime dependencies
- `spec:` tags in RSpec files are parsed by the reference parser and appear as edges in the graph
- `blocked-by` references in plan items are parsed and appear as dependency edges
- CI drift detection flags spec sections that changed since linked tests last passed
- Web UI renders current, open, and condensed views from parser output
- All ledger and knowledge module code, migrations, and tests are removed
- AgentRun and analytics events use string refs instead of integer FKs to ledger tables
- No Postgres tables exist for project state (nodes, edges, audit events)
- Existing agent and analytics functionality is unaffected by removal

## Open Questions

| Question | Notes |
|---|---|
| Git notes merge conflicts under concurrent agent runs | Low risk for solo dev; revisit if collaborators are added |
| LEDGER.jsonl growth over time | Periodic summarization (like activity.md trimming) — define threshold later |
| How to handle plan item renumbering when items are removed | Reference parser should use stable refs (title-based) not numeric IDs |
| LLM-resolved acceptance tests — cost model and workflow | Future spike, not in scope for initial build |

---

See [`specs/system/analytics/spec.md`](../analytics/spec.md) for the retained metrics system.
