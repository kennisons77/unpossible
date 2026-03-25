# Activity: Search Document

## User Story

As a user, I want to search my document library by keyword so I can quickly find what I need.

## Capability Depth (POC)

**Basic** — Keyword full-text search (FTS) via PostgreSQL

## What the User Does

1. Types a search query into the search bar (present on all authenticated pages)
2. Submits the query
3. Views results ranked by relevance
4. Clicks a result to view the full document

## Why

A personal library is only useful if you can find things. Search-first navigation is faster than browsing hierarchies when you know what you're looking for. Full-text search on document content and metadata makes the system feel responsive and useful.

## Acceptance Criteria

- Search bar present in navbar on all authenticated pages
- Search query submitted to `/search?q=<query>`
- Query returns matching documents ranked by relevance (PostgreSQL `ts_rank`)
- Results page shows document cards with: document type, concern, confidence score, text snippet (via `ts_headline`)
- Clicking a result card navigates to document show page
- Empty query handled gracefully (returns empty set with message)
- No matches returns empty state message: "No documents found for '<query>'"
- Search works on: document content (from Markdown body), document type, concern name
- Unauthenticated requests redirected to login

## Out of Scope (POC)

- Semantic / vector search (pgvector column exists but queries deferred to v2)
- Search filters (by concern, document type, date range)
- Search suggestions / autocomplete
- Saved searches
- Search history
- Advanced query syntax (boolean operators, phrase search)
- Pagination (acceptable for POC with 10 documents)
