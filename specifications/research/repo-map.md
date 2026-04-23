# Repo Map — Implementation Research

## Research Pass — 2026-04-23

The spike (IMPLEMENTATION_PLAN.md task 9.1) had three open questions. Answers below
derive from the repo-map concept spec, the agentic-context-management research log,
the reference-graph-parser research log, the Go platform spec, and the project's
existing Go monorepo (single `go.mod` at `go/go.mod`, stdlib + `lib/pq` +
`prometheus/client_golang` only so far).

---

### Interview Findings

#### Q1: tree-sitter Go bindings (`smacker/go-tree-sitter`) maturity for Ruby grammar

`smacker/go-tree-sitter` is the de-facto Go binding for tree-sitter. It bundles a
large catalogue of grammars in-tree (Ruby, Go, Python, TypeScript, Markdown, …) so
no runtime grammar download is required. It is the binding named explicitly in
`specifications/system/repo-map/concept.md` ("The binary reuses tree-sitter bindings
already available in the Go ecosystem (`smacker/go-tree-sitter`). No new language
runtimes required.") and was corroborated by the reference-graph-parser spike.

**Maturity signals:**

- Ships the tree-sitter C runtime plus grammars compiled into the Go module — no
  external `.so`/`.dylib` to install.
- Ruby grammar coverage is sufficient for what the repo map needs: `class`, `module`,
  `def`, `def self.`, and `include`/`extend` nodes. Method parameter extraction works
  from the `method_parameters` node.
- Go grammar covers `package_clause`, `type_declaration`, `function_declaration`, and
  `method_declaration` — everything needed to extract exported signatures.
- Markdown grammar handles `atx_heading` nodes; we only need H1/H2, which are trivial.
- Widely used by tooling that needs polyglot parsing (several AST-diff tools, lint
  frameworks, and code-search indexers depend on it). It has been the reference Go
  binding for several years.

**Cost of the dependency:**

- Uses `cgo`. This is the real cost. Consequences:
  - The `go/` monorepo becomes partially cgo-dependent (currently stdlib-plus-drivers).
    The Dockerfile.go builder stage must install a C toolchain (`build-base` on
    Alpine, or `gcc` + `libc-dev`). `CGO_ENABLED=1` must be the default for the
    `repo-map` target.
  - Static cross-compilation is more fiddly (`-linkmode external -extldflags '-static'`
    works but produces larger binaries, ~25–40 MB with bundled grammars).
  - The runner sidecar and analytics sidecar must keep `CGO_ENABLED=0` so they stay
    statically linkable. Two-track cgo policy is fine — `go build ./cmd/runner` and
    `go build ./cmd/analytics` with cgo off, `go build ./cmd/repo-map` with cgo on.
- Binary size is dominated by the bundled grammars (~10–20 MB just for Ruby+Go+Markdown).
  Acceptable for a CLI; not acceptable if this ever became a sidecar.

**Alternative considered: regex-only Ruby extraction.**

The reference-graph-parser spike chose regex because it only needed `spec:` string
literals. The repo map needs *structured* extraction — a method definition that spans
multiple lines, nested modules, method parameters — and regex produces false positives
fast (strings containing `def`, heredocs, `%w[...]`, etc.). The incremental correctness
win of AST is worth the cgo cost for the repo-map specifically.

**Alternative considered: shelling out to `tree-sitter` CLI.**

Rejected. It would require installing the Node-based `tree-sitter` CLI in the
container, parse output as JSON via stdout, and add latency per file. The in-process
Go binding is cleaner.

**Conclusion:** Use `smacker/go-tree-sitter` for Ruby, Go, and Markdown extraction in
`go/cmd/repo-map/`. Accept cgo for this binary only. Keep the sidecar binaries cgo-free.
Update `infra/Dockerfile.go` to add a repo-map target with a cgo-enabled builder stage.

---

#### Q2: Token budget estimation approach

The concept spec says "output is capped at a configurable token limit (default 1024
tokens)" and lists degradation rules applied when the budget is exceeded. The concrete
question is: *how does the Go binary count tokens without calling an LLM?*

**Option A — Characters ÷ 4 heuristic (chosen).**

The industry rule-of-thumb for English-ish text is 1 token ≈ 4 characters. For code
and structured markdown (class names, method signatures, dotted file paths), the
ratio is closer to 1 token ≈ 3.5–4 characters depending on tokenizer. For a budget
tool whose job is "stay under ~N tokens," a 4-char approximation is accurate to
within ±10%, which is well inside the margin needed when the budget is 1024 tokens.

Implementation: `func estimateTokens(s string) int { return utf8.RuneCountInString(s) / 4 }`.

**Option B — `tiktoken-go` (OpenAI BPE).**

A Go port of OpenAI's tiktoken. Would give per-token accuracy for OpenAI models.
Rejected because:
- Anthropic does not publish Claude's tokenizer; tiktoken is an approximation for
  Claude anyway.
- Adds a non-trivial dependency with embedded BPE tables (~3 MB).
- The accuracy gain is invisible at our budget resolution (1 KB of tokens).

**Option C — Call Anthropic's `count_tokens` endpoint.**

Rejected. Requires a network call and an API key for a build-time artifact. The repo
map is regenerated frequently (pre-loop hook); per-call latency and API cost are
unjustified.

**Degradation cascade (from concept spec § Token Budget Strategy):**

The binary measures the output's estimated token count after rendering. If over
budget, it re-renders applying these rules *in order*, stopping as soon as the
estimate fits:

1. Drop method parameters (`#dispatch(...)` instead of full signature)
2. Drop H2 headings from specs (filename + description only)
3. Drop files unchanged in the last 20 commits
4. Drop Go `internal/` packages (keep `cmd/` entry points only)

If still over budget after all four rules, truncate from the lowest-ranked files
until it fits. Emit a warning to stderr listing what was dropped so regressions are
noticeable.

**Conclusion:** Character ÷ 4 heuristic is sufficient. Implement the degradation
cascade as an ordered list of render strategies, re-rendering after each step.
Deterministic output (tie-break by file path) is required for acceptance.

---

#### Q3: Relevance ranking weights

The concept spec says "ranks files by relevance (git recency, plan references, module
activity)" and its open-questions section adds "Start with git recency only. Add
plan-reference weighting after measuring baseline."

**Phase 0 weights (chosen):**

```
score(file) = git_recency_score(file)
```

Where `git_recency_score(file)` is derived from `git log --format=%ct -- {file}` —
the most recent commit timestamp for that file. Rank files descending by timestamp;
files never touched by git sort last (stable alphabetical tie-break).

This is deliberately crude. The concept spec recommends measuring baseline before
adding complexity, and the reference-graph-parser spike followed the same principle
(stdlib-only, measure first, enrich later).

**Deferred to a later measurement pass:**

- `plan_reference_score` — +1 per mention of the file's module/path in
  IMPLEMENTATION_PLAN.md. The plan file is small and parsed already; cheap to add.
  Hold until we see build-agent misses that would have been prevented.
- `module_activity_score` — weight by number of commits in the last N days touching
  the same directory. Effectively a module-level version of git recency; adds
  complexity without obvious new signal in Phase 0.
- `focus_path_score` — when `--focus=web/app/modules/agents/` is passed, files under
  the focus path get a fixed high score; all others are dropped entirely. This is
  structural, not a weight — already covered by the `--focus` flag.

**Edge cases to encode in Phase 0:**

- **File exists on disk but has no git log** (brand new, untracked): score = 0, sort
  last, but still include. Otherwise the repo map ignores new work which is the
  opposite of what the agent needs.
- **File exists in git but was deleted on disk**: exclude entirely (don't render
  ghost entries).
- **Merge commits inflating recency**: use `git log --no-merges --format=%ct` so
  rebases and merges don't make everything look "recent."
- **Monorepo tie-break**: files with identical timestamps sort by path ascending,
  so the output is deterministic across machines.

**Conclusion:** Start with git recency only (most-recent non-merge commit timestamp).
Tie-break by path. Untracked files sort last but are included. Revisit plan-reference
and module-activity weights only after Phase 0 produces a usable map that still
misses files the build agent needs.

---

### Sources

| Title | URL | Type | Relevance |
|---|---|---|---|
| Repo-map concept spec | specifications/system/repo-map/concept.md | standard | Defines output shape, degradation rules, integration points |
| Agentic context management research | specifications/research/agentic-context-management.md | article | Aider repo map as the dominant AST-based-context pattern |
| Reference-graph parser research | specifications/research/reference-graph-parser.md | article | Go monorepo bootstrap pattern; stdlib-first principle |
| Go platform spec | specifications/platform/go/README.md | standard | Single go.mod, `cmd/` per binary, `internal/` for shared code |
| Go sidecars research | specifications/research/go-sidecars.md | article | Multi-stage Dockerfile.go pattern; per-binary cgo policy |
| Aider repo map docs | https://aider.chat/docs/repomap.html | article | Dominant prior art for AST-based, token-budgeted repo maps |
| smacker/go-tree-sitter | https://github.com/smacker/go-tree-sitter | library | Go tree-sitter binding; ships Ruby/Go/Markdown grammars |
| tree-sitter Ruby grammar | https://github.com/tree-sitter/tree-sitter-ruby | library | Source grammar bundled inside smacker/go-tree-sitter |
| Anthropic prompt caching guidance | https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching | article | Stable-prefix recommendation; why repo map should cache |
| Go cgo documentation | https://pkg.go.dev/cmd/cgo | standard | Confirms cgo build-toolchain requirements |

---

### Edge Cases Found

- **cgo toolchain in Docker build.** The current `infra/Dockerfile.go` builder stage
  (Alpine) does not install `build-base`. Adding a repo-map target requires
  `apk add --no-cache build-base` in the builder stage, and `CGO_ENABLED=1` for the
  repo-map `go build` invocation only. Other binaries keep `CGO_ENABLED=0`.

- **Ruby heredocs and `%w[]` literals.** Regex would false-positive on `def` inside
  heredocs. tree-sitter correctly scopes `def` to the `method` node. This is the
  main justification for AST over regex for Ruby.

- **Nested modules in Ruby.** `module A; module B; class C; end; end; end` should
  render as `A::B::C`. tree-sitter's `module` nodes nest; the renderer must walk the
  ancestor chain to build the fully-qualified name.

- **Go unexported symbols.** The spec says "Exported type and function signatures."
  Filter on identifier first character: `unicode.IsUpper(rune(name[0]))`. Methods on
  unexported receivers with exported names should still be excluded (they are not
  callable from outside the package).

- **Markdown files without frontmatter.** README.md and plain notes typically have
  no YAML frontmatter. Use the first H1 heading as the description; fall back to
  filename if no H1 exists. Same convention the reference parser uses.

- **Test files under `web/spec/` and `go/**/*_test.go`.** The spec excludes tests.
  Path-based filters: `_test.go` suffix for Go, path prefix `web/spec/` for Ruby.
  Ruby spec files live under `spec/`, not `app/`, so prefix filtering is reliable.

- **Generated files.** `db/schema.rb` is generated but potentially useful for
  migration-writing agents (concept spec Q2 flags this). Defer inclusion until
  measurement justifies it; exclude for Phase 0.

- **Binary/vendor directories.** Exclude `node_modules/`, `vendor/`, `tmp/`, `log/`,
  `.git/`, and anything in `.gitignore`. Honour `.gitignore` via
  `git ls-files --cached --others --exclude-standard` — cleaner than re-implementing
  gitignore matching.

- **Empty repo / no git history.** `git log` returns nothing. The binary should emit
  an empty map (not error) so the pre-loop hook doesn't break fresh clones.

- **Unicode identifiers.** Ruby and Go both allow Unicode identifiers. Character
  count must be rune-count (`utf8.RuneCountInString`), not byte length, so the
  token estimate is correct for non-ASCII code.

- **Token budget of zero or negative.** `--budget 0` should render the full map
  (interpret as "no budget"). Negative values should error at flag parse time.

---

### Open Questions Remaining

- **Invocation cadence in `loop.sh`.** The concept spec suggests regenerating
  pre-loop. For Phase 0 (local dev), regenerating once per `loop.sh` invocation is
  fine — the file tree doesn't change mid-loop. Phase 1+ with CI may need a file-hash
  cache to avoid re-parsing unchanged files. Decide during repo-map implementation
  task (future).

- **Gitignored `REPO_MAP.md` vs committed.** The concept spec says "gitignored — it's
  a derived artifact, not source of truth." Matches Aider's convention. Open question:
  do we still want a *committed* reference snapshot for PR review context? Probably
  not — the agent regenerates on demand and reviewers can do the same. Commit to
  "gitignored" unless a concrete use case appears.

- **Multi-budget configuration per agent config.** Concept spec says "larger budget
  for plan/review, smaller for build." Implementation question: is the budget set
  at the agent config level, or inferred from an env var set by `loop.sh` before it
  regenerates the map? Env var is simpler (one invocation per loop); config-level
  requires the agent config loader to know about repo-map. Start with env var.

- **Integration with the agent config `resources` array.** Concept spec shows
  `file://REPO_MAP.md` in `resources`. The existing agent config system needs to
  tolerate a resource file that may not exist yet (first loop on a fresh clone,
  or binary not built). Either the loader skips missing resources gracefully, or
  `loop.sh` guarantees the file exists before invoking the agent. Lean toward the
  latter — `loop.sh` runs `go/bin/repo-map` with `--output REPO_MAP.md` before
  invoking the agent; if the binary fails, fall back to writing a minimal
  `REPO_MAP.md` that says "repo map unavailable."

- **Schema.rb inclusion threshold.** Concept spec Q: "Should the map include database
  schema?" Measure first. If the build agent repeatedly reads `db/schema.rb` for
  migration work, include it under a `--include-schema` flag. Defer until signal.

- **Focus-mode depth.** `--focus web/app/modules/agents/` is one level. Should the
  focus also expand related specs (`specifications/system/agents/`)? Probably yes —
  a focus-to-specs mapping file, or a convention ("focus path `web/app/modules/X/`
  also pulls `specifications/system/X/`"). Defer until the build agent explicitly
  requests it.

---

### Recommendation

Proceed with a Phase 0 implementation task (to be added to IMPLEMENTATION_PLAN.md as
a new item when the spike is accepted):

1. **Add `go/cmd/repo-map/main.go`** alongside the existing `parser`, `runner`, and
   `analytics` binaries. Single `go.mod`; cgo enabled for this binary only.
2. **Depend on `github.com/smacker/go-tree-sitter` plus its bundled grammars for Ruby,
   Go, and Markdown.** No other new dependencies.
3. **Use `git ls-files --cached --others --exclude-standard`** to enumerate source
   files — respects `.gitignore` for free.
4. **Extract symbols per the concept spec's "What the Map Contains" section.** Walk
   the AST with tree-sitter queries; emit a structured intermediate representation
   before rendering.
5. **Rank by git recency (most-recent non-merge commit timestamp) only.** Tie-break
   by path. Files with no git history sort last but are included.
6. **Estimate tokens as `runeCount / 4`.** Apply the four-step degradation cascade
   from the concept spec in order, stopping when the estimate fits the budget.
7. **Emit to stdout by default; `--output FILE` writes to disk.** `--budget N`
   overrides default of 1024. `--focus PATH` filters the file set before ranking.
8. **Update `infra/Dockerfile.go`** with a cgo-enabled builder stage producing
   `/out/repo-map`, alongside the existing cgo-disabled builds for the sidecars.
9. **Update `infra/Makefile`** (if present) / `AGENTS.md` with a `make repo-map`
   target that builds and invokes the binary.
10. **Gitignore `REPO_MAP.md`** at the project root.
11. **Tests:** `go test ./cmd/repo-map/...` with fixture Ruby/Go/Markdown files in
    `testdata/`. Deterministic output is the key acceptance criterion — snapshot
    test the rendered map for a fixture tree.

The implementation is gated by Phase 0 scope: no web UI integration, no CI hook, no
schema.rb inclusion. The binary is usable standalone and callable from `loop.sh`
pre-loop. That is the minimal viable repo map.

---

### Acceptance Criteria for 9.1 (this spike)

This spike is complete when `specifications/research/repo-map.md` exists with
answers to all three open questions (tree-sitter maturity, token budget estimation,
relevance ranking). No code is written in this task.
