# Knowledge

## What It Does

Indexes documents and LLM responses into a vector store. Provides scoped semantic
retrieval for agent loops. Source files are the source of truth — the vector store is
the query layer.

## LibraryItem Schema

```
LibraryItem
  id             UUID
  node_id        FK → Node (ledger) — the node this chunk belongs to (nullable)
  source_path    relative path of the source file (nullable — null for LLM responses)
  source_sha     SHA256 of source file at index time (nullable)
  chunk_index    position within the source file
  content_type   markdown | plain_text | link_reference | llm_response
  content        raw text of the chunk
  embedding      vector (1536 dimensions)
  org_id
```

`node_id` enables scoped retrieval — chunks associated with a node and its ancestors.
`source_sha` enables change detection — only re-embed when the file has changed.

## Content Types

| Type | Source | Notes |
|---|---|---|
| `markdown` | Spec files, research logs, principles | Chunked at paragraph/section boundaries |
| `plain_text` | Notes, comments | Chunked at paragraph boundaries |
| `llm_response` | Agent runner output | Full response body, tagged with originating node |
| `error_context` | Agent errors, RALPH_WAITING messages, failure reasons | Natural language errors worth finding by similarity |
| `link_reference` | URL + description | No fetched content — description only |

## Embedding

- Default model: OpenAI `text-embedding-3-small` (1536 dimensions)
- Chunking unit: paragraph/section level — semantic boundaries, not whole files or sentences
- Provider swappable via `EMBEDDER_PROVIDER=openai|ollama` — same interface, different implementation

## Indexing Pipeline

1. Detect change — compute SHA256 of source file, compare to `source_sha`
2. If unchanged, skip — no embedding call made
3. Split file into chunks at semantic boundaries
4. Embed each chunk
5. Upsert `LibraryItem` records keyed on `(source_path, chunk_index)`

Triggered by: file watcher detecting a changed spec, agent runner completing a run,
comment posted to a node, agent error or RALPH_WAITING signal captured.

Idempotent — running twice on an unchanged file produces no side effects.

## Retrieval Interface

```
ContextRetriever#retrieve(
  query:    string,
  limit:    integer,
  node_id:  UUID (optional) — scopes results to this node and its ancestors
)
→ LibraryItem[]  ordered by cosine similarity descending
```

## LLM Response Indexing

After every agent run, the runner POSTs the response body to the knowledge module with
the originating `node_id`. This is indexed as a `llm_response` chunk. Future loops
working on related nodes retrieve prior responses as context — avoiding re-reasoning
from scratch.

## Acceptance Criteria

- Markdown file indexed into paragraph-level chunks with embeddings
- Unchanged file (same SHA256) skipped — no embedding call made
- `ContextRetriever#retrieve(query:, limit:)` returns top-N chunks by cosine similarity
- `ContextRetriever#retrieve(query:, limit:, node_id:)` scopes to that node tree
- LLM response saved as `llm_response` chunk tagged with originating node ID
- Agent error or RALPH_WAITING message saved as `error_context` chunk tagged with originating node ID
- `ContextRetriever` with `node_id` returns relevant error_context chunks alongside spec and response chunks
- Embedder provider swappable via env var without code changes
- API key never appears in logs or error messages
- Upsert on `(source_path, chunk_index)` is idempotent

See [`prd.md`](prd.md) for intent and scenarios.
