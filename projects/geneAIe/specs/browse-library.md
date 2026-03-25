# Activity: Browse Library

## User Story

As a user, I want to browse my document library by concern and type so I can explore what I have.

## Capability Depth (POC)

**Basic** — Scaffold browse by concern and document type

## What the User Does

1. **Documents Index:** Views a list of all documents with key metadata
2. **Document Show:** Clicks a document to see full metadata and all extracted fields with provenance
3. **Concerns Index:** Views a list of all concerns (confirmed and LLM-proposed)
4. **Concern Show:** Clicks a concern to see all documents in that concern
5. **Confirm Concern:** Approves an LLM-proposed concern to mark it confirmed

## Why

Search is fast when you know what you're looking for, but browsing helps with discovery and understanding what's in the library. Grouping by concern provides a natural taxonomy. Provenance badges (LLM/OCR/human) build trust in the data.

## Acceptance Criteria

### Documents
- Documents index (`/documents`) lists all documents in a Bootstrap table
- Table columns: filename (from blob), document type, concern, stage, confidence score
- Clicking a row navigates to document show page
- Document show page displays:
  - Document metadata: type, concern, stage, confidence, content hash
  - Link to download original blob
  - All extracted fields (from DocumentField records) with source badge (LLM/OCR/human)
- Unauthenticated requests redirected to login

### Concerns
- Concerns index (`/concerns`) lists all concerns with confirmed status badge
- LLM-proposed concerns show "Proposed" badge and "Confirm" button
- Confirmed concerns show "Confirmed" badge
- Clicking a concern name navigates to concern show page
- Concern show page lists all documents in that concern
- Confirm action (`POST /concerns/:id/confirm`) sets `confirmed_at` timestamp and redirects back to concerns index
- Unauthenticated requests redirected to login

### Navigation
- Navbar includes "Documents" and "Concerns" links (visible when authenticated)

## Out of Scope (POC)

- Filtering or sorting on documents index
- Pagination (acceptable for POC with 10 documents)
- Bulk operations (delete, re-process)
- Document editing from show page (editing happens in review queue only)
- Concern editing or deletion
- Concern hierarchy or nesting
- Document preview (thumbnail, first page)
- Download all documents in a concern
