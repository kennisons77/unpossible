> **SUPERSEDED — knowledge module removed. See `specs/system/reference-graph/spec.md`.**

# PRD: Knowledge

- **Status:** Draft
- **Created:** 2026-04-01
- **Last revised:** 2026-04-01

## Intent

The Knowledge module indexes documents and LLM responses into a vector store so agent
loops can retrieve relevant context by semantic similarity rather than loading every file
on every iteration. Source files remain the source of truth — the vector store is a
query layer on top.

## Personas

- **Loop agent:** needs targeted context for the current beat without loading all specs
  every iteration — reduces token cost and improves relevance
- **Reflect loop:** needs to query accumulated LLM responses to find patterns across runs
- **ContextRetriever:** needs a stable interface to retrieve chunks scoped to a node tree

## User Scenarios

**Scenario 1 — Spec indexed on change:**
A developer edits `specs/system/ledger/spec.md`. The file watcher detects the change,
computes the SHA256, finds it differs from the stored hash, and re-indexes the file into
paragraph-level chunks with fresh embeddings. The next loop iteration retrieves the
updated content.

**Scenario 2 — LLM response saved:**
The build loop completes a beat. The agent runner saves the response body as a
`LibraryItem` tagged with the beat's node ID. Future loops working on related beats
retrieve this response as context — the agent doesn't re-reason from scratch.

**Scenario 3 — Scoped retrieval:**
The plan loop is working on a feature. It calls `ContextRetriever#retrieve` with the
feature's node ID. Only chunks associated with that node tree are returned — not the
entire knowledge base.

## Functional Requirements

**MVP:**
- Index markdown files into paragraph-level chunks with embeddings
- Skip unchanged files (SHA256 dedup)
- Retrieve top-N chunks by cosine similarity, optionally scoped to a node ID
- Save LLM responses as indexed chunks tagged with the originating node
- Swappable embedder provider via environment variable

**Post-MVP:**
- Link reference indexing (URL + description, no fetched content)
- Cross-org knowledge isolation
- Chunk expiry / staleness detection

## Specs

| Spec file | Description |
|---|---|
| [`spec.md`](spec.md) | LibraryItem schema, indexing pipeline, retrieval interface |
