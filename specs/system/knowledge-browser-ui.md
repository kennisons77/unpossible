# Knowledge Browser UI

<!-- status: proposed -->

## Problem

There is no way to see what has been indexed into the knowledge store or test
retrieval queries without hitting the API directly.

## Views

### Index — `GET /knowledge`
- Paginated list of LibraryItems grouped by source_path
- Shows: source_path, content_type, chunk count, last indexed timestamp

### Search — `GET /knowledge/search?q=`
- Text input for a retrieval query
- Results ranked by cosine similarity with score displayed
- Each result shows: content snippet, source_path, chunk_index, similarity score

## Constraints

- Server-rendered HTML (ERB), no JS framework
- Depends on Knowledge::LibraryItem and Knowledge::ContextRetriever
- Auth follows the same pattern as LedgerController
