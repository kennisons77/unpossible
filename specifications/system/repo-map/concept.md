---
name: repo-map
kind: concept
status: draft
description: AST-based codebase summary injected as agent context to reduce orientation cost
modules: []
---

# Repo Map

## What It Does

Generates a compact, token-budgeted summary of the codebase — class names, method
signatures, module boundaries — and injects it into agent context at the start of
every loop iteration. Agents see "what exists and where" without reading file bodies
or burning tool calls on exploratory searches.

## Why It Exists

Every loop iteration starts with the agent orienting itself: grepping for symbols,
globbing directories, reading file headers. This costs 5–15 tool calls and 2,000–5,000
tokens of output before any real work begins. A repo map eliminates most of that
overhead by front-loading a structural summary that fits within a fixed token budget.

The pattern is proven. Aider's tree-sitter repo map is the most widely adopted
implementation — it reduced initial orientation tool calls by 60–80% in their
benchmarks. We adapt the concept to our stack (Ruby + Go + markdown specs) and
our agent config system.

## Design Decisions

- **Generated, not hand-maintained.** The map is produced by a CLI tool that parses
  source files. Humans never edit it directly.
- **Token-budgeted.** The output is capped at a configurable token limit (default
  1024 tokens). When the codebase grows beyond the budget, the tool prioritizes
  files by relevance (recently changed, referenced in the current plan, or in
  active modules).
- **AST-based, not regex.** Uses tree-sitter grammars for Ruby and Go to extract
  class/module/method/function signatures. Markdown files are summarized by
  heading structure.
- **Injected as a resource.** The generated map is a file (`REPO_MAP.md`) referenced
  in agent configs via `file://REPO_MAP.md`. No special prompt assembly logic —
  it's just another resource.
- **Regenerated on file change.** A git hook or pre-loop script regenerates the map
  when source files change. Stale maps are acceptable (the agent can still use
  tools) but fresh maps are preferred.

## What the Map Contains

For each source file, the map includes the minimum needed to navigate without reading:

**Ruby files** (`web/app/**/*.rb`):
- Module and class names with nesting
- Public method signatures (name + parameters)
- Concern inclusions

**Go files** (`go/**/*.go`):
- Package name
- Exported type and function signatures

**Markdown specs** (`specifications/**/*.md`):
- Heading structure (H1 + H2 only)
- Frontmatter `name` and `description` if present

**Excluded:**
- Test files (specs describe behaviour, not structure)
- Vendor, node_modules, generated files
- Method bodies, comments, private methods

## Example Output

```
## web/app/modules/agents/

AgentRun < ApplicationRecord
  .create_from_config(config:, source_ref:)
  .find_active(organization_id:)
  #complete!(exit_status:, summary:)
  #append_turn(role:, content:)

AgentRunTurn < ApplicationRecord
  #token_cost

AgentConfig
  .load(name:)
  #resources
  #allowed_tools

## web/app/modules/sandbox/

DockerDispatcher
  #dispatch(image:, command:, env:)

ContainerRun < ApplicationRecord
  #timed_out?

## go/cmd/parser/

func main()
func ParseSpecFiles(root string) ([]Node, error)
func BuildGraph(nodes []Node, ledger []Event) Graph

## specifications/system/

reference-graph/concept.md — Reference Graph
  ## What It Does
  ## Design Decisions
  ## Components
  ## Acceptance Criteria

sandbox/concept.md — Sandbox Module
  ## What It Does
  ## Security
  ## Acceptance Criteria
```

## Token Budget Strategy

The map must fit within its budget. When it doesn't, apply these rules in order:

1. **Drop method parameters** — show `#dispatch(...)` instead of full signatures
2. **Drop H2 headings from specs** — show only file name and description
3. **Drop unchanged files** — keep only files modified in the last 20 commits
4. **Drop Go internals** — keep only `cmd/` entry points

The budget is configurable per agent config. Agents that need broad awareness
(plan, review) get a larger budget. Agents that work on a single beat (build)
get a smaller one focused on the active module.

## Generation Tool

A Go CLI binary in `go/cmd/repo-map/` that:

1. Walks the file tree, respecting `.gitignore`
2. Parses each file with the appropriate tree-sitter grammar
3. Extracts symbols according to the rules above
4. Ranks files by relevance (git recency, plan references, module activity)
5. Renders the map to stdout or a file, truncating at the token budget
6. Exits with code 0 on success

Invocation:

```bash
# Generate to stdout (default 1024 token budget)
go/bin/repo-map

# Generate to file with custom budget
go/bin/repo-map --output REPO_MAP.md --budget 2048

# Focus on a specific module
go/bin/repo-map --focus web/app/modules/agents/
```

The binary reuses tree-sitter bindings already available in the Go ecosystem
(`smacker/go-tree-sitter`). No new language runtimes required.

## Integration

### Agent Configs

Add `REPO_MAP.md` as a resource in agent configs that benefit from it:

```json
{
  "resources": [
    "file://REPO_MAP.md",
    "file://AGENTS.md",
    ...
  ]
}
```

Plan and review agents get the full map. Build agent gets a focused map
(regenerated with `--focus` on the active module). Research agent skips it
(research is about external information, not codebase structure).

### Regeneration Hook

A pre-loop script regenerates the map before each iteration:

```bash
# In loop.sh, before invoking the agent
go/bin/repo-map --output REPO_MAP.md --budget "${REPO_MAP_BUDGET:-1024}"
```

The map is gitignored — it's a derived artifact, not source of truth.

## Acceptance Criteria

- `go/bin/repo-map` produces a markdown summary of Ruby classes, Go types, and spec headings
- Output respects the `--budget` flag and truncates at the token limit
- Ruby extraction includes module/class names and public method signatures
- Go extraction includes package names and exported function/type signatures
- Spec extraction includes H1, H2 headings and frontmatter description
- `--focus` flag limits output to files under the specified directory
- `--output` flag writes to a file; default is stdout
- Generated map is deterministic — same inputs produce same output
- Agent configs can reference the map as `file://REPO_MAP.md`
- Test files, vendor directories, and generated files are excluded
- Token budget overflow applies the degradation rules in order

## Open Questions

| Question | Notes |
|---|---|
| tree-sitter grammar availability for ERB/Haml | Not needed Phase 0 — views are minimal. Revisit if view layer grows. |
| Should the map include database schema (db/schema.rb)? | Useful for agents writing migrations. Try including table + column names, measure token cost. |
| Relevance ranking weights | Start with git recency only. Add plan-reference weighting after measuring baseline. |
| Map freshness vs generation cost | Generation should be <1s for our codebase size. If it grows, add file-hash caching. |

## Research

See `specifications/research/repo-map.md` for full findings.

Key sources:
- Repo-map concept spec (this file) → informs acceptance criteria and output shape
- `specifications/research/agentic-context-management.md` → Aider repo map as dominant prior art
- `specifications/research/reference-graph-parser.md` → Go monorepo bootstrap pattern
- `smacker/go-tree-sitter` → Go binding with bundled Ruby/Go/Markdown grammars
