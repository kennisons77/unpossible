# Reference Graph — Go Reference Parser

## Research Pass — 2026-04-22

### Interview Findings

The spike had four open questions. Answers derived from codebase analysis, the
reference-graph concept spec, the repo-map concept spec, and the Go platform spec.

---

**Q1: tree-sitter Go bindings for Ruby parsing**

`smacker/go-tree-sitter` is the standard Go binding for tree-sitter. It bundles
grammars for many languages including Ruby. The repo-map concept spec already
references it by name: "The binary reuses tree-sitter bindings already available
in the Go ecosystem (`smacker/go-tree-sitter`). No new language runtimes required."

The reference parser needs to extract `spec:` metadata tags from RSpec files. These
are Ruby string literals in `RSpec.describe` calls — not complex AST traversal.
A regex over the file is sufficient for Phase 0 (the tag format is fixed:
`spec: "path/to/spec.md#section"`). Full tree-sitter Ruby parsing is only needed
if the parser must extract method signatures (that's the repo-map's job, not the
reference parser's).

**Conclusion:** tree-sitter is not required for the reference parser in Phase 0.
Regex extraction of `spec:` tags from RSpec files is sufficient and simpler.
tree-sitter is needed for the repo-map binary (`go/cmd/repo-map/`), not the parser
(`go/cmd/parser/`). The two binaries share the `go/` monorepo but have different
dependencies.

---

**Q2: LEDGER.jsonl event schema stability**

The LEDGER.jsonl schema is defined in `specifications/system/reference-graph/concept.md`
§ File Schemas. Current event types: `status`, `blocked`, `unblocked`, `spec_changed`,
`spec_removed`, `pr_opened`, `pr_review`, `pr_merged`.

The schema is stable for Phase 0. The only live events in the current LEDGER.jsonl
are `status` and `spec_removed`. PR events (`pr_opened`, `pr_review`, `pr_merged`)
are defined but not yet emitted (no PR skill implemented yet).

The parser must handle unknown event types gracefully — skip them rather than error.
This future-proofs the parser against new event types added before the parser is
updated.

**Conclusion:** Schema is stable enough to build against. Parse known types, skip
unknown. The `sha` field on `status` events is nullable (null before commit, SHA
after) — the parser must handle both.

---

**Q3: Graph output format for web UI consumption**

The concept spec defines the output format in § Go Reference Parser:

```json
{
  "id": "pr:42",
  "type": "pull_request",
  "branch": "ralph/20260417-1150",
  "state": "merged",
  "task_ids": ["3.2", "3.3"],
  "spec_refs": ["specifications/system/analytics/concept.md"],
  "commits": ["abc1234", "bcd2345", "def5678"],
  "reviews": [...],
  "merge_sha": "aaa1111"
}
```

The full output is a JSON object with two top-level arrays: `nodes` and `edges`.
Node types and edge types are enumerated in the concept spec. The web UI (Priority 5,
not yet built) will consume this JSON via a Rails endpoint that shells out to the
parser binary and returns the result.

**Conclusion:** Output format is `{"nodes": [...], "edges": [...]}` written to stdout
(or a file with `--output`). The Rails web UI endpoint reads it via `IO.popen` or
a cached file. No Postgres storage — the graph is computed on demand.

For Phase 0, the minimal viable output covers:
- Spec nodes (from markdown frontmatter)
- Plan item nodes (from IMPLEMENTATION_PLAN.md)
- Commit nodes (from git log)
- Status transition edges (from LEDGER.jsonl)
- `spec:` tag edges (from RSpec files)
- `blocked-by` edges (from IMPLEMENTATION_PLAN.md)

PR nodes and review nodes are deferred until the PR skill exists.

---

**Q4: How to bootstrap go.mod and the Go build in the monorepo**

The Go platform spec defines the structure:

```
go/
├── go.mod          # module: github.com/unpossible/unpossible/go
├── go.sum
├── cmd/
│   ├── runner/     # port 8080 sidecar
│   ├── analytics/  # port 9100 sidecar
│   ├── parser/     # reference-graph parser CLI
│   └── repo-map/   # repo map generator CLI
└── internal/       # shared packages
```

Single `go.mod` for all binaries. This is the standard Go monorepo pattern — one
module, multiple `cmd/` entry points. `go build ./...` builds all binaries.
`go test ./...` runs all tests.

The `infra/Dockerfile.go` (task 8.4) will build all binaries via multi-stage build.
For Phase 0 local dev, the parser runs on the host (not in Docker) since it reads
the local file tree and git history.

**Bootstrap sequence:**
1. `mkdir -p go/cmd/parser go/internal`
2. `go mod init github.com/unpossible/unpossible/go` (in `go/`)
3. Implement `go/cmd/parser/main.go` with the minimal graph output
4. `go build ./cmd/parser/` — produces `go/bin/parser` (or `go run ./cmd/parser/`)
5. No external dependencies needed for Phase 0 parser (stdlib only: `os`, `bufio`,
   `encoding/json`, `regexp`, `path/filepath`, `os/exec` for git log)

The parser does NOT need tree-sitter for Phase 0. It uses:
- `os.ReadFile` + `regexp` for frontmatter and `spec:` tag extraction
- `os/exec` + `git log --format=...` for commit history
- `bufio.Scanner` for LEDGER.jsonl line-by-line parsing
- `encoding/json` for output

This keeps the initial `go.mod` dependency-free (stdlib only), which avoids the
`vendor/` or module proxy problem in the air-gapped Docker build environment.

---

### Sources

| Title | URL | Type | Relevance |
|---|---|---|---|
| smacker/go-tree-sitter | https://github.com/smacker/go-tree-sitter | library | Go bindings for tree-sitter; needed for repo-map, not reference parser |
| reference-graph concept spec | specifications/system/reference-graph/concept.md | standard | Defines parser inputs, outputs, node/edge types, LEDGER.jsonl schema |
| repo-map concept spec | specifications/system/repo-map/concept.md | standard | Confirms tree-sitter usage pattern; parser and repo-map share go/ monorepo |
| Go platform spec | specifications/platform/go/README.md | standard | Defines go/ directory structure, single go.mod, cmd/ layout |
| Go stdlib encoding/json | https://pkg.go.dev/encoding/json | standard | JSON output; no external dependency needed |
| Go stdlib os/exec | https://pkg.go.dev/os/exec | standard | git log invocation; no external dependency needed |

### Edge Cases Found

- **Nullable `sha` in LEDGER.jsonl status events**: The `sha` field is null before
  commit and a SHA string after. Parser must handle both. Use `*string` in Go struct.

- **Unknown LEDGER.jsonl event types**: New event types will be added (e.g., future
  `spec_changed` events from CI drift detection). Parser must skip unknown types
  without erroring. Use a `type` field switch with a default no-op case.

- **IMPLEMENTATION_PLAN.md item format**: Current items do not have the
  `<!-- status: ..., spec: ..., test: ... -->` inline comment format defined in the
  concept spec. The parser must handle both formats: items with and without the
  comment. Extract task ID and title from the `- [ ] N.M Title` pattern; treat
  inline comment as optional enrichment.

- **Plan item renumbering**: The concept spec notes "Reference parser should use
  stable refs (title-based) not numeric IDs." For Phase 0, numeric IDs are stable
  enough (no items have been renumbered). Title-based stable refs are a future
  enhancement.

- **Git log on shallow clone**: If the repo is shallow-cloned (e.g., in CI), `git log`
  may not return full history. The parser should not fail — emit what git returns.
  Phase 0 is local dev only; shallow clones are not a concern yet.

- **Spec files with no frontmatter**: Some markdown files lack YAML frontmatter
  (e.g., README.md files). The parser must handle missing frontmatter gracefully —
  use the filename as the node ID and the H1 heading as the description.

- **`spec:` tags in RSpec `it` blocks vs `describe` blocks**: The concept spec shows
  the tag on `RSpec.describe`. Some tests may put it on nested `describe` or `context`
  blocks. The regex should match `spec:` anywhere in a Ruby string literal on a line
  containing `describe`, `context`, or `it`.

### Open Questions Remaining

- **Parser invocation from Rails web UI**: The web UI (Priority 5) needs to call the
  parser binary and serve its JSON output. Two options: (a) shell out via `IO.popen`
  on each request, (b) cache the output as a file and serve it statically. Option (b)
  is simpler and avoids blocking Rails on git operations. Recommendation: cache to
  `tmp/reference-graph.json`, regenerate via a rake task or pre-loop script.
  Decide when the web UI task (Priority 5) is planned.

- **Parser binary location**: `go/bin/parser` (built locally) vs `go/cmd/parser/`
  (source). The Makefile should have a `make parser` target. The binary is gitignored.
  Decide when task 8.2 (Go bootstrap) is planned.

- **CI drift detection (Priority 4)**: Requires the parser to emit `spec_changed`
  events by comparing content hashes. This is a separate concern from the basic graph
  output. Defer to when CI exists (Phase 1+).

### Recommendation

Implement task 8.2 (Go bootstrap) before the parser. The bootstrap creates `go/go.mod`
and stub `main.go` files for all four binaries (`runner`, `analytics`, `parser`,
`repo-map`). The parser implementation (a future task after 8.2) should:

1. Use stdlib only — no external dependencies for Phase 0
2. Parse: spec frontmatter, IMPLEMENTATION_PLAN.md items, LEDGER.jsonl events,
   git log, RSpec `spec:` tags
3. Output: `{"nodes": [...], "edges": [...]}` JSON to stdout
4. Skip unknown LEDGER.jsonl event types
5. Handle missing frontmatter gracefully
6. Be deterministic — sort nodes and edges by ID before output

The parser does NOT need tree-sitter for Phase 0. Regex extraction is sufficient
for the inputs defined in the concept spec. tree-sitter is the repo-map's concern.

The dependency order is: **8.1 (spike) → 8.2 (bootstrap) → parser implementation**.
The parser implementation should be a separate task after 8.2, not bundled with the
bootstrap.
