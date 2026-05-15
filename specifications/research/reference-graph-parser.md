---
name: reference-graph-parser
kind: research
status: active
date: 2026-05-15
topic: Go Reference Parser Design (Reference Graph Priority 2)
spec: specifications/system/reference-graph/concept.md#2-go-reference-parser-priority-2
blocked_by: 4.1
---

# Research: Go Reference Parser Design

## Summary

The reference parser is a standalone Go binary that walks the file tree, git history,
and LEDGER.jsonl to produce a JSON graph. No blocking open questions remain. Ready to
build. Design decisions below are final for Phase 0.

## Findings

### What Already Exists

- `go/cmd/runner/` and `go/cmd/analytics/` — two Go sidecars with established patterns:
  package `main`, single file, stdlib + minimal deps, vendored dependencies.
- `go/go.mod` — module `github.com/unpossible/unpossible/go`, Go 1.23, vendored.
- `LEDGER.jsonl` at project root — append-only, format stabilized by task 4.1.
- `scripts/controlled-commit.sh` — produces LEDGER.jsonl entries in the format the
  parser must consume.
- `specifications/system/reference-graph/concept.md` — defines node types, edge types,
  LEDGER.jsonl schema, IMPLEMENTATION_PLAN.md item format, and acceptance criteria.

### Design Decisions

#### 1. Output Format

**Decision: JSON to stdout, one object.**

```json
{
  "generated_at": "2026-05-15T13:00:00Z",
  "nodes": [...],
  "edges": [...]
}
```

Rationale:
- The concept spec says "JSON graph of nodes and edges suitable for web UI consumption."
- Stdout is the Unix-native output for a CLI tool. The caller pipes or redirects.
- A single top-level object (not JSONL) is easier to consume from a web handler or
  shell script (`jq .nodes`).
- Deterministic: same inputs → same output. No timestamps in the graph itself (only
  in `generated_at`).

Alternative considered: JSONL (one node/edge per line). Rejected — harder to consume
as a complete graph; no benefit for Phase 0 scale.

#### 2. Node Types

Derived from file conventions, not a database enum. Each node has:

```json
{
  "id": "string (stable, derived from source)",
  "type": "spec_section | beat | commit | pull_request | review | test_suite | research_finding",
  "label": "human-readable title",
  "path": "file path or git ref (where applicable)",
  "status": "todo | in_progress | done | blocked (beats only)",
  "metadata": {}
}
```

Node ID derivation (stable across renames where possible):
- `spec_section`: `spec:{path}#{anchor}` — e.g. `spec:specifications/system/reference-graph/concept.md#go-reference-parser`
- `beat`: `beat:{ref}` — e.g. `beat:5.1`
- `commit`: `commit:{sha7}` — e.g. `commit:abc1234`
- `pull_request`: `pr:{number}` — e.g. `pr:42`
- `review`: `review:{pr_number}:{reviewer}:{ts_epoch}` — e.g. `review:42:ken:1713355200`
- `test_suite`: `test:{path}` — e.g. `test:spec/models/agents/agent_run_spec.rb`
- `research_finding`: `research:{path}` — e.g. `research:specifications/research/reference-graph-parser.md`

#### 3. Edge Types

```json
{
  "from": "node_id",
  "to": "node_id",
  "type": "contains | depends_on | refs | implements | addresses | reviews"
}
```

Edge derivation:
- Markdown link between spec files → `contains` (parent → child)
- `blocked-by` in plan item → `depends_on` (beat → beat)
- `spec:` tag in RSpec file → `refs` (test_suite → spec_section)
- LEDGER.jsonl `pr_opened.task_ids` → `implements` (pull_request → beat)
- LEDGER.jsonl `pr_opened.spec_refs` → `addresses` (pull_request → spec_section)
- LEDGER.jsonl `pr_review` → `reviews` (review → pull_request)
- PR → commit (from `sha_first`/`sha_last` range) → `contains`

#### 4. Plan Item Renumbering

**Decision: Title-based stable refs as primary key; numeric ID as human label only.**

The concept spec says: "Reference parser should use stable refs (title-based) not
numeric IDs." Beat node IDs use the numeric ref (`beat:5.1`) because that's what
LEDGER.jsonl records. When a plan item is renumbered, the old LEDGER.jsonl entries
retain the old ref. The parser emits both nodes and adds a `renamed_from` edge if
it detects a title match with a different ref.

Renaming detection: if two beats share the same title (after normalization) but
different refs, the later one is treated as a rename of the earlier one. A
`renamed_from` edge connects them. This is best-effort — not guaranteed to be
correct if titles are reused intentionally.

For Phase 0 (solo dev, infrequent renumbering), this is sufficient.

#### 5. Parsing Strategy: Tree-sitter vs Regex

**Decision: Regex + stdlib for Phase 0. No tree-sitter.**

Rationale:
- The parser needs to extract: frontmatter from markdown, `spec:` tags from RSpec
  `describe` blocks, `blocked-by` from plan item HTML comments, and LEDGER.jsonl
  entries.
- All of these are line-oriented patterns, not deep AST structures.
- Tree-sitter requires CGo bindings or WASM, adding build complexity and a non-trivial
  dependency. The concept spec says "standalone Go binary with no runtime dependencies."
- Regex handles all required patterns with zero additional dependencies.
- If the parser needs to understand Ruby method bodies (e.g. for deeper code→spec
  tracing), tree-sitter can be added then. That's Priority 3+ work.

Patterns needed:
- Frontmatter: `^---\n(.*?)\n---` (multiline, YAML key-value)
- Plan item: `^- \[([ x])\] (\d+\.\d+) — (.+?)(?:\s+<!--(.+?)-->)?$`
- `spec:` tag in RSpec: `RSpec\.describe\s+[^,]+,\s+spec:\s+"([^"]+)"`
- `blocked-by` in plan item comment: `blocked-by:\s*([\d.]+)`
- LEDGER.jsonl: `json.Unmarshal` per line (already structured)
- Git log: `git log --format="%H %s"` parsed line by line
- Markdown links: `\[([^\]]+)\]\(([^)]+\.md[^)]*)\)`

#### 6. Git Integration

**Decision: Shell out to `git` commands. No libgit2.**

- `git log --format="%H|%s|%ai" HEAD` — commit list
- `git notes list` — list notes refs
- `git notes show {sha}` — read note content
- `git rev-parse HEAD` — current SHA

Rationale: libgit2 Go bindings (go-git) add ~5MB to the binary and require CGo.
Shelling out to `git` is simpler, has no deps, and is fast enough for Phase 0
repo sizes. The runner sidecar already uses `exec.CommandContext` for this pattern.

#### 7. CLI Interface

```
go-reference-parser [flags]
  --root    string   project root (default: current directory)
  --output  string   output file path (default: stdout)
  --pretty           pretty-print JSON (default: compact)
```

Invocation from the web UI or shell:
```bash
./go-reference-parser --root /path/to/project --pretty
```

The binary is built as `go/cmd/reference-parser/main.go`, output binary
`go/reference-parser`. Added to `infra/Dockerfile.go` build stage.

#### 8. Error Handling

- Missing files (LEDGER.jsonl not found, no git history): emit empty arrays, log
  warning to stderr. Do not fail — the parser is read-only and should degrade
  gracefully.
- Malformed LEDGER.jsonl lines: skip line, log warning to stderr with line number.
- Git command failures: log to stderr, return empty result for that source.
- Fail-open: the parser never exits non-zero for missing/malformed input. It exits
  non-zero only for invalid flags or unreadable project root.

### Build Tasks Derived from This Research

| Task | Description |
|---|---|
| 5.2 | `go/cmd/reference-parser/main.go` — parser binary (walk files, parse LEDGER.jsonl, shell out to git, emit JSON graph) |
| 5.3 | `go/cmd/reference-parser/main_test.go` — unit tests with fixture files |
| 5.4 | Update `infra/Dockerfile.go` to build `reference-parser` binary |
| 5.5 | Update `specifications/system/reference-graph/concept.md` with finalized node/edge schema |

### Confidence Assessment

- Output format (JSON to stdout): **high** — standard CLI pattern
- Node/edge types: **high** — directly from concept spec
- Regex over tree-sitter: **high** — all patterns are line-oriented
- Git shelling out: **high** — established pattern in runner sidecar
- Plan item renaming: **medium** — title-based matching is heuristic; acceptable for Phase 0

### Open Questions — Resolved

| Question | Resolution |
|---|---|
| Output format | JSON to stdout, single object |
| Node/edge types | Derived from file conventions per concept spec |
| Plan item renumbering | Title-based stable refs; numeric ID as human label |
| Tree-sitter vs regex | Regex for Phase 0; tree-sitter deferred |
| Git integration | Shell out to `git`; no libgit2 |

## Back-References

- Spec: `specifications/system/reference-graph/concept.md` § Go Reference Parser
- Prior research: `specifications/research/reference-graph-commit.md`
- Existing Go sidecars: `go/cmd/runner/main.go`, `go/cmd/analytics/main.go`
- LEDGER.jsonl format: `specifications/system/reference-graph/concept.md` § LEDGER.jsonl
