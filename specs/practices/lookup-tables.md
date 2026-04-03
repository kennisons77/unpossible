# Lookup Tables

## What They Are

Lookup tables are Markdown tables that map key terms to their canonical locations — spec files, module paths, API endpoints, model names, or any other reference an agent needs to find something. They are loaded once at the start of a loop iteration and give the agent a precise index to navigate the codebase and specs without broad file scanning.

Loom's `specs/README.md` is the reference implementation: every spec maps to the crate(s) that implement it. An agent reading that table knows exactly where to look for any feature — no guessing, no scanning, no hallucination.

## Why They Matter

Without a lookup table, an agent discovering an unfamiliar term does one of three things:
1. Scans the entire codebase — expensive
2. Guesses a file path — often wrong
3. Hallucinates an answer — silently wrong

A lookup table eliminates all three. It is the **Determinism** principle applied to navigation: the system tells the agent where things are rather than relying on the agent to figure it out.

They also reduce token cost. A 20-row table costs ~200 tokens. The alternative — loading multiple files to find the same information — costs 10–50×.

## Where Lookup Tables Live

Every project built with unpossible maintains these lookup tables:

| File | Contains |
|---|---|
| `specs/README.md` | Spec → module → loop type |
| `AGENTS.md` | Build/run/test commands + key codebase patterns |
| `specs/practices/LOOKUP.md` | Term → practices file + rule name |
| `app/modules/LOOKUP.md` | Module name → path → public service interface |

These are the four tables an agent needs at the start of any iteration. They are loaded before anything else.

## Format Rules

Every lookup table follows the same structure:

```markdown
| Term / Key | Location | Purpose |
|---|---|---|
| Knowledge::ContextRetriever | app/modules/knowledge/services/context_retriever.rb | Semantic similarity search against embeddings |
| IndexerJob | app/modules/knowledge/jobs/indexer_job.rb | Re-indexes changed MD files into pgvector |
```

Rules:
- **Term column** — the exact name an agent would search for: class name, module name, concept, CLI flag
- **Location column** — the shortest unambiguous path or reference. For specs: relative path from project root. For code: path from `app/`. For external: URL.
- **Purpose column** — one sentence. What it does, not what it is.
- No nested tables. No prose between rows. Tables only.
- Keep rows alphabetical within each section — agents scan tables top-to-bottom and alphabetical order makes binary search possible.

## specs/README.md

The canonical index for all specs. Format: spec file → module → loop type that implements it.

Updated whenever a new spec is added. The planning agent reads this before any plan iteration to know what specs exist without loading them all.

## AGENTS.md

Operational reference. Contains:
1. Build/run/test commands (exact commands, copy-pasteable)
2. A lookup table of key codebase patterns: class name → file path → one-line description

The build agent reads `AGENTS.md` at the start of every build iteration. It is the first file loaded, before specs or practices. Keep it under 100 lines — if it grows beyond that, the codebase patterns section has become a spec and should be moved to `specs/`.

Example codebase patterns table:
```markdown
| Pattern | File | Notes |
|---|---|---|
| Agents::ProviderAdapter | app/modules/agents/services/provider_adapter.rb | Base class — subclass per provider |
| Analytics::AuditLogger | app/modules/analytics/services/audit_logger.rb | Fire-and-forget, never raises |
| Knowledge::ContextRetriever | app/modules/knowledge/services/context_retriever.rb | Call with query:, limit: |
| Ledger::SpecWatcherJob | app/modules/ledger/jobs/spec_watcher_job.rb | Triggered after plan loop completes |
| Secret | app/lib/secret.rb | Wrap all API keys — .expose for raw value |
```

## practices/LOOKUP.md

Maps concepts and rules to the practices file and section that defines them. Lets an agent find a specific rule without loading all practices files.

```markdown
| Term | File | Rule |
|---|---|---|
| cache_control | practices/general/cost.md | Prompt Caching — always ttl: "1h" |
| Secret | practices/general/security.md | Secret Value Object |
| module boundary | practices/lang/ruby.md | Module Boundaries |
| RALPH_COMPLETE | practices/general/prompting.md | Use These Words |
| Ultrathink | practices/general/prompting.md | Use These Words |
| effort parameter | practices/general/cost.md | Effort Parameter |
| audit on destructive | practices/framework/rails.md | Audit on Destructive Actions |
```

## app/modules/LOOKUP.md

Maps module names to their paths and public service interfaces. Prevents agents from reaching across module boundaries by making the correct entry point obvious.

```markdown
| Module | Path | Public interface |
|---|---|---|
| agents | app/modules/agents/ | Agents::AgentRunsService |
| analytics | app/modules/analytics/ | Analytics::AuditLogger, Analytics::LlmMetricsService |
| knowledge | app/modules/knowledge/ | Knowledge::ContextRetriever, Knowledge::IndexerJob |
| ledger | app/modules/ledger/ | Ledger::NodeLifecycleService, Ledger::SpecWatcherJob |
| sandbox | app/modules/sandbox/ | Sandbox::DockerDispatcher |
```

## Reference Style

Prefer concept references over path references in prose and spec bodies:

```
✓  "see the ledger spec"
✓  "see the knowledge spec"
✗  "see specs/system/ledger/spec.md"
```

The agent resolves concept references via the knowledge base — a rename doesn't break
them. Hard-coded paths belong only in lookup tables and `AGENTS.md`, where exactness
is required and the one-update rule (see version-control practice) keeps them current.

**Exception:** `AGENTS.md` operational commands and lookup table rows always use exact
paths — they are the resolution layer that concept references depend on.

## Maintenance Rules

- Update the relevant lookup table in the same commit that adds the thing being indexed
- A class, spec, or rule that isn't in a lookup table effectively doesn't exist to the agent
- If an agent scans files to find something that should be in a lookup table, add it — that's a signal the table is incomplete
- Lookup tables are never generated — they are maintained by hand (or by the build loop as part of the task that creates the thing being indexed)

## Acceptance Criteria

- `specs/README.md` exists and contains a table mapping every spec file to its module and loop type
- `AGENTS.md` exists and contains build/run/test commands and a codebase patterns table
- `practices/LOOKUP.md` exists and maps at least: `Secret`, `cache_control`, `RALPH_COMPLETE`, `Ultrathink`, `module boundary`, `audit on destructive`
- `app/modules/LOOKUP.md` exists and maps all five modules to their paths and public interfaces
- Every new spec added by the build loop includes an update to `specs/README.md` in the same commit
- Every new module service added by the build loop includes an update to `app/modules/LOOKUP.md` in the same commit
