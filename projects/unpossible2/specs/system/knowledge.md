# Knowledge Module

## What It Does

Indexes documents (markdown files, research docs, specs, practices) into a vector store so agent loops can retrieve relevant context by semantic similarity rather than loading every file on every iteration. Source files remain the source of truth — the vector store is a query layer on top.

## Why It Exists

Loading all specs and practices files every loop iteration is expensive and imprecise. As a project grows, targeted retrieval replaces the "load everything" approach — reducing per-iteration token cost and improving context relevance.

## Library Item Schema

Each `LibraryItem` record stores:
- `id` — UUID primary key
- `parent_id` — the feature/project context it belongs to
- `story_id` — FK to a Story record (nullable — set when the chunk originates from a spec or conversation associated with a story)
- `source_path` — relative path of the source file
- `source_sha` — SHA256 of the source file at index time
- `chunk_index` — position of this chunk within the source file
- `embedding` — vector (1536 dimensions)
- `content` — raw text of the chunk
- `org_id`

`story_id` enables scoped retrieval: `ContextRetriever#retrieve(query:, limit:, story_id:)` filters chunks to those associated with a specific story tree.

## Content Types

- Markdown files (specs, research, practices, pitches)
- Plain text notes
- Link references (URL + description — no fetched content)

## Embedding

- Model: OpenAI `text-embedding-3-small` (1536 dimensions)
- Unit: paragraph/section level — semantic boundaries within files, not whole files or sentences
- Provider is swappable via config (`EMBEDDER_PROVIDER=openai|ollama`) — same interface, different implementation

## Indexing

- Triggered by change detection — only re-embed files whose SHA256 has changed
- Idempotent — running twice produces the same state

## Library Item Lifecycle

Each item has a `parent_id` (the feature/project context it belongs to). When a parent is removed, three options:
- Cascade delete children
- Archive children (excluded from retrieval)
- Reassign children to another parent

## Multi-tenancy

Schema includes `org_id` from day one. Phase 0 uses a single hardcoded org. Migration path to multi-tenancy is additive.

## Acceptance Criteria

- Indexer indexes a markdown file into paragraph-level chunks with embeddings
- Unchanged file (same SHA256) is skipped — no redundant embedding calls
- `ContextRetriever#retrieve(query:, limit:)` returns top-N chunks ordered by cosine similarity
- `ContextRetriever#retrieve(query:, limit:, story_id:)` scopes results to chunks with that story_id
- Embedder provider is swappable via environment variable without code changes
- API key for embedder never appears in logs or error messages
- Destroy with cascade deletes all child library items
- Destroy with archive excludes children from retrieval results
