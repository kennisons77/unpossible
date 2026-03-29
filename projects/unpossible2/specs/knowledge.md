# Knowledge Module

## What It Does

Indexes markdown files, research docs, specs, and practices into a vector store so ralph loops can retrieve relevant context by semantic similarity rather than loading every file on every iteration. MD files remain the source of truth — the vector store is a query layer on top.

## Why It Exists

Loading all specs and practices files every loop iteration is expensive and imprecise. As the project grows, targeted retrieval replaces the current "load everything" approach, reducing per-iteration token cost and improving context relevance.

## Content Types

- MD files (specs, research, practices, pitches)
- Plain text notes
- Link references (URL + description — no fetched content)

## Embedding

- Model: OpenAI `text-embedding-3-small` (1536 dimensions)
- Unit: paragraph/section level — semantic boundaries within MD files, not whole files or sentences
- Provider is swappable via config (`EMBEDDER_PROVIDER=openai|ollama`) — same interface, different implementation

## Indexing

- Triggered by git change detection — only re-embed files whose SHA256 has changed
- Implemented as a Rails Active Job (`Knowledge::IndexerJob`)
- Idempotent — running twice produces the same DB state

## Library Item Lifecycle

Each item has a `parent_id` (the feature/project context it belongs to). When a parent is removed, three options:
- Cascade delete children
- Archive children (sets `archived_at`, excluded from retrieval)
- Reassign children to another parent

Triggered as an async background job on parent deletion.

## Multi-tenancy

Schema includes `org_id` from day one. Phase 0 uses a single hardcoded org. Migration path to multi-tenancy is additive.

## Acceptance Criteria

- `Knowledge::IndexerJob` indexes an MD file into paragraph-level chunks with embeddings
- Unchanged file (same SHA256) is skipped — no redundant embedding calls
- `Knowledge::ContextRetriever#retrieve(query:, limit:)` returns top-N chunks ordered by cosine similarity
- Embedder provider is swappable via environment variable without code changes
- API key for embedder never appears in logs or error messages
- Destroy with cascade deletes all child library items
- Destroy with archive sets `archived_at` on children, excludes them from retrieval results
