# Research Loop

## What It Does

The research loop deepens a spec through structured interview and external source collection. It does not write code. Its outputs are:

1. An expanded spec with edge cases, open questions resolved, and acceptance criteria sharpened
2. A research log (`specs/research/{feature}.md`) with collected sources and findings
3. Back-references in the spec to research log entries — so future loops load targeted context instead of re-researching

The loop runs before planning, not during build. A spec that has been through a research loop produces a tighter, cheaper plan loop because the agent isn't discovering edge cases mid-build.

## Why It Exists

Specs written without research tend to be optimistic — they describe the happy path and leave edge cases for the build loop to discover. That's expensive: the build loop uses Sonnet/Opus, runs in a container, and commits code. Discovering a missing edge case there costs 10× what discovering it in a research loop costs.

Research also surfaces existing libraries, prior art, and competitor approaches that the agent would otherwise hallucinate or miss. Storing these as library items means future loops retrieve them by similarity rather than re-fetching or re-reasoning.

## Scope

Research loops run in two contexts:

1. **Unpossible itself** — before planning any new unpossible feature. Research logs live in `projects/unpossible2/specs/research/`.
2. **Unpossible's projects** — before planning features for projects under `projects/{name}/`. Research logs live in `projects/{name}/specs/research/`.

The loop is the same in both cases. The scope is set by `ACTIVE_PROJECT`.

## Loop Invocation

```bash
./loop.sh research <feature-id>
```

`feature-id` is the ID of an entry in `IDEAS.md` (e.g. `./loop.sh research 3`). The loop reads that idea entry and uses it as the seed for the interview.

A research loop always runs for exactly 1 iteration (`MAX_ITERATIONS=1`). If more depth is needed, run it again — each pass appends to the research log.

## What the Agent Does

### 1. Read the seed

Read the idea entry from `IDEAS.md` (injected into the prompt by `loop.sh`). Read the existing spec file if one exists (`specs/{feature}.md`). Read the existing research log if one exists (`specs/research/{feature}.md`).

### 2. Interview

Ask the human a focused set of questions to resolve ambiguity and surface edge cases. Questions are grouped by theme, not fired one at a time. Pause with `RALPH_WAITING: <questions>` and wait for answers before proceeding.

Good interview questions cover:
- **Scope boundaries** — what is explicitly out of scope for this feature?
- **Edge cases** — what happens when input is empty, malformed, very large, or arrives out of order?
- **Failure modes** — what should the system do when a dependency is unavailable?
- **Security surface** — does this feature touch secrets, PII, or external systems?
- **Performance expectations** — are there latency or throughput requirements?
- **Prior art** — are there existing tools, libraries, or competitor implementations worth studying?

### 3. Collect sources

For each prior art item identified (from the interview or the agent's own knowledge), collect:
- A URL and title
- A one-paragraph summary of what it does and what's relevant
- A relevance tag: `competitor`, `library`, `article`, `standard`, `video`

**Source type rules:**
- `competitor` — a product that solves the same problem (e.g. PostHog for analytics, pgvector docs for vector search)
- `library` — a gem, package, or crate that could be used directly
- `article` — a blog post, Medium article, or documentation page with relevant design decisions
- `standard` — an RFC, spec, or formal standard
- `video` — a conference talk or tutorial. **Store title + URL only. Do not fetch or parse video content — cost is prohibitive.** Note the timestamp of the relevant section if known.

Sources are stored as `link_reference` items in the knowledge base (`Knowledge::LibraryItem` with `content_type: :link_reference`). The agent creates these via `POST /api/knowledge/library_items` if the Rails app is running, or writes them directly to the research log if not.

### 4. Write the research log

Append findings to `specs/research/{feature}.md`. Format:

```markdown
## Research Pass — {date}

### Interview Findings
{summary of answers, resolved questions, edge cases discovered}

### Sources
| Title | URL | Type | Relevance |
|---|---|---|---|
| pgvector README | https://github.com/pgvector/pgvector | library | Cosine similarity index options, IVFFLAT vs HNSW tradeoffs |
| How PostHog does identity resolution | https://posthog.com/blog/... | article | Merge anonymous + identified distinct_ids — same pattern we need |
| Solid Queue deep dive | https://... | article | Active Job backend, concurrency model, queue priorities |

### Edge Cases Found
- {edge case}: {how it should be handled}

### Open Questions Remaining
- {question}: {why it's still open}
```

### 5. Update the spec

Back-reference the research log in the spec file. Add a `## Research` section at the bottom:

```markdown
## Research

See `specs/research/{feature}.md` for full findings.

Key sources:
- pgvector IVFFLAT vs HNSW tradeoffs → informs index choice in Embedding model
- PostHog identity resolution → informs PromptDeduplicator design
```

Also update the spec's acceptance criteria and edge case handling based on interview findings. Mark any previously open questions as resolved.

### 6. Index into knowledge base

If the Rails app is running, trigger `Knowledge::IndexerJob` for the updated spec and research log files. This makes their content available for future loop context retrieval without loading the full files.

If the Rails app is not running (Phase 0, before the app exists), skip this step — the files are on disk and will be indexed when the app is first started.

## Output Signals

- `RALPH_COMPLETE` — research log written, spec updated, sources collected
- `RALPH_WAITING: <questions>` — interview questions for the human

## Cost Profile

Research loops use:
- **Haiku** for reading existing files and formatting output
- **Sonnet** for interview question generation and source summarisation
- **No Opus** — research does not require deep reasoning, only structured collection

A single research pass should cost under $0.10. If it exceeds $0.50, something is wrong — the agent is probably loading too much context or running too many turns.

## Research Log Lifecycle

Research logs are append-only. Each pass adds a dated section. They are never overwritten — the history of what was researched and when is part of the audit trail.

When a spec is promoted to implementation and the feature is built, the research log is not deleted. It becomes a reference for the review loop ("does the implementation match what was researched?") and for the reflect loop ("did the research correctly predict the edge cases?").

## Acceptance Criteria

- `./loop.sh research <id>` runs exactly 1 iteration and exits
- Agent pauses with `RALPH_WAITING` to ask interview questions before writing anything
- Research log is created at `specs/research/{feature}.md` if it doesn't exist, or appended to if it does
- Research log contains: interview findings, sources table, edge cases, remaining open questions
- Spec file gains a `## Research` section with back-references to the log
- Video sources are stored as title + URL only — no content fetched
- Sources are stored as `link_reference` library items if the Rails app is running
- `RALPH_COMPLETE` is output after the log and spec are written
- Running the loop twice appends a second dated section — does not overwrite the first
