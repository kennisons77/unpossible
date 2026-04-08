# Knowledge Module — Rails Platform Override

Extends `specs/knowledge.md`. Rails-specific implementation details only.

## Models
- `Knowledge::LibraryItem` — ActiveRecord, `app/modules/knowledge/models/library_item.rb`
- `Knowledge::Embedding` — ActiveRecord with pgvector `vector(1536)` column, IVFFlat index for cosine similarity

## Background Jobs
- `Knowledge::IndexerJob` — Active Job, enqueued on `knowledge` queue via Solid Queue

## Services
- `Knowledge::EmbedderService` — abstract interface, `embed(text) → Array<Float>`
- `Knowledge::OpenAiEmbedder` — implements EmbedderService, API key wrapped in `Secret`
- `Knowledge::MdChunker` — splits markdown at paragraph/section boundaries
- `Knowledge::ContextRetriever` — embeds query, runs pgvector cosine similarity search

## Schema Details
- `content_type` enum: `md_file / plain_text / link_reference`
- `embedding` column: `vector(1536)` via pgvector
- `archived_at` nullable — archived items excluded from default scope

## Files
- `web/app/modules/knowledge/models/library_item.rb`
- `web/app/modules/knowledge/models/embedding.rb`
- `web/app/modules/knowledge/jobs/indexer_job.rb`
- `web/app/modules/knowledge/services/embedder_service.rb`
- `web/app/modules/knowledge/services/open_ai_embedder.rb`
- `web/app/modules/knowledge/services/md_chunker.rb`
- `web/app/modules/knowledge/services/context_retriever.rb`
- `web/app/modules/knowledge/controllers/knowledge/library_items_controller.rb`

## Rails-specific Acceptance Criteria
- `IndexerJob` enqueued on `knowledge` queue
- pgvector nearest-neighbor query returns results ordered by cosine distance
- `LibraryItem` default scope excludes archived items
- Destroy triggers async job for cascade/archive/reassign
