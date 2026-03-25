# Product Requirements Document — The Sovereign Library

## Overview

A self-hosted personal data governance system built on Rails 8. Functions as a private 6-stage ETL pipeline that ingests fragmented digital and physical records (government IDs, medical records, bills, and more), classifies them using an LLM, normalizes them into structured Markdown+YAML files tracked in git, and makes them searchable via full-text search.

Built for personal use first, designed to scale. The system prioritizes human control over automation: the LLM proposes, the human confirms.

---

## Goals

1. **Ingest** documents via file upload (web UI), folder watcher, or API webhook
2. **Run** documents through a reliable 6-stage ETL pipeline end-to-end
3. **Classify** documents using Claude Haiku with PII redacted via regex before any LLM call
4. **Store** original blobs immutably in MinIO and normalized records in a git-tracked Markdown repo
5. **Surface** documents via full-text postgres search with a clean search-first UI
6. **Gate** low-confidence extractions through a human review queue with a diff-view interface
7. **Prove** the pipeline on 10 real documents (priority: Government IDs, Medical Records)

---

## Non-Goals (v1)

- Multi-user access — data model is designed with an owner FK from day one, but no other-user auth flows
- Push notifications or reminders — actionable metadata is surfaced in the UI only; no email/push
- Local LLM (Ollama) — deferred until the pipeline is proven; Claude Haiku is the starting point
- Family history / genealogy records — deferred entirely
- Email ingestion adapter — deferred to post-POC
- Semantic / vector search — pgvector column added to schema but queries deferred to v2
- Scheduled alerts or due-date notifications — dashboard display only in v1

---

## Technical Constraints

- **Language:** Ruby 3.3
- **Framework:** Rails 8
- **Base image:** ruby:3.3-slim
- **Test command:** bundle exec rspec
- **Port:** 3000

---

## Phase

**Current Phase:** Phase 0 (Local — app runs and tests pass on dev machine)

---

## Technical Architecture

### Stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | Rails 8 | "One Person Framework" philosophy |
| Database | PostgreSQL | With pgvector extension (column present, queries deferred) |
| Background Jobs | Solid Queue | ETL pipeline stages run as jobs |
| Cache | Solid Cache | Memoize LLM responses, search results |
| LLM | Claude Haiku (Anthropic API) | Remote, cheap; Ollama migration path deferred |
| LLM Orchestration | Direct HTTP / thin wrapper | Evaluate Langchainrb after Phase 1 |
| OCR | pdftotext → Tesseract fallback | pdftotext for digital PDFs; Tesseract only for true image/scan docs |
| PII Redaction | Rule-based regex | Strip known PII patterns before any LLM call |
| Blob Storage | MinIO (S3-compatible, local Docker) | Via Active Storage; blobs are write-once/immutable |
| Markdown Store | Git-tracked folder on disk | Rails auto-commits on every record write |
| Frontend | Bootstrap 5 (Bootswatch Yeti theme) + Hotwire (Turbo/Stimulus) | Rails scaffold views for POC; Yeti chosen for clean readable UI with minimal custom CSS |
| Auth | Rails 8 built-in (has_secure_password) | Single user; session-based |
| Remote Access | Tailscale | Network-layer security; no open ports |
| Deployment | Docker Compose (dev) → Kamal (when pipeline is proven on real docs) | |

---

## The 6-Stage ETL Pipeline

### Stage 1 — Acquisition
- **Adapters (POC scope):** File upload (web UI), folder watcher (polling-based Solid Queue job), API webhook endpoint
- **Output:** Raw blob stored in MinIO + `Document` record created with stage = `acquired`

### Stage 2 — Categorization
- **Process:** PII regex redaction → Claude Haiku call → concern + document_type extracted
- **Concern taxonomy:** LLM-derived; new concern types surface for user confirmation before being committed
- **Output:** `concern`, `document_type`, `confidence_score` set on the Document

### Stage 3 — Identification
- **Process:** SHA-256 hash computed on raw blob
- **Dedup logic:** Hash match = duplicate (human decides via review queue); hash mismatch on same entity/type = new version (human confirms)
- **Output:** `content_hash`, dedup decision

### Stage 4 — Normalization
- **Process:** pdftotext (digital PDFs) → Tesseract OCR (image/scan fallback) → PII regex redaction → Claude Haiku structured extraction → Markdown+YAML file generated
- **Output:** `.md` file with YAML front matter committed to git-tracked library folder

### Stage 5 — Storage
- **Blob:** Immutable write-once in MinIO (never changes after initial write)
- **Markdown:** Written to disk and auto-committed by Rails to the git-tracked library repo
- **Postgres:** Indexed record with full-text search vector updated

### Stage 6 — Enrichment
- **Manual annotations:** Tags, corrections, notes added via diff-view review UI
- **Per-field provenance:** Every field records `source` (llm / ocr / human) and `updated_at`
- **Output:** Enriched record, updated git commit

---

## Stage-Specific Fallbacks

| Stage | Failure | Fallback |
|---|---|---|
| Normalization | pdftotext produces no text | Fall through to Tesseract |
| Normalization | Tesseract confidence too low | Document surfaces in review queue with raw OCR text for manual correction |
| Categorization | LLM returns malformed output | Document surfaces in review queue for manual schema fill |
| Categorization | LLM confidence below threshold | Document surfaces in review queue for human confirmation |
| Identification | Hash conflict detected | Document surfaces in review queue for version-vs-duplicate decision |

---

## Data Model

### Document
```
id, owner_id (FK → users, for future multi-user)
stage (enum: acquired → categorized → identified → normalized → stored → enriched)
review_required (boolean)
content_hash (SHA-256)
concern_id (FK → concerns, primary)
concern_tags (array, secondary concerns)
document_type (string)
confidence_score (float)
minio_blob_key (string, immutable after write)
markdown_path (string, path in git-tracked library folder)
embedding (vector, pgvector — column present, queries deferred to v2)
```

### DocumentField (per-field provenance)
```
id, document_id (FK)
field_name (string)
value (text)
source (enum: llm / ocr / human)
updated_at
```

### Concern
```
id, owner_id (FK)
name (string)
llm_proposed (boolean)
confirmed_at (timestamp, null until user confirms)
```

### User
```
id, email, password_digest
(Rails 8 auth scaffold)
```

---

## Review Queue

**Trigger conditions:**
- LLM confidence below configurable threshold
- SHA-256 conflict detected (possible duplicate/version)
- OCR quality below threshold
- LLM returns malformed structured output

**Diff view behavior:**
- **New document:** LLM extraction vs. empty schema template
- **Re-ingested document:** new extracted version vs. previous stored version
- User can approve, edit individual fields, or reject

---

## Search (v1)

- **Mechanism:** PostgreSQL full-text search on Markdown content + YAML fields
- **UI:** Search bar as primary entry point; no browse/filter hierarchy in v1
- **v2 path:** pgvector column already present; semantic search can be layered in without schema migration

---

## Git-Tracked Library

- Rails auto-commits the Markdown library folder on every write (create, update, enrichment)
- Commit message includes: document ID, stage, source (llm/human), timestamp
- Binary blobs are **never** committed to git — MinIO only
- Library folder structure: `library/{concern}/{document_type}/{doc_id}.md`

---

## Schema Evolution Policy

- New fields are **forward-only**: existing records are not backfilled
- New fields default to `null` on old records
- Queries must handle null gracefully
- Backfill is possible via manual review queue trigger (not automatic)

---

## POC Success Criteria

- 10 real documents (mix of Government IDs and Medical Records) run through all 6 stages end-to-end
- Review queue correctly surfaces low-confidence documents
- Full-text search returns relevant documents
- Git commit history exists on the markdown library folder
- MinIO blobs are intact and immutable
- Success is **qualitative**: outputs feel useful and accurate

---

## Verification

- All ETL stages can be triggered via a Rake task for testing
- RSpec unit tests for: PII regex redaction, SHA-256 identification, Markdown serialization, per-field provenance
- Integration test: upload a PDF → verify it reaches `stored` stage with correct YAML fields
- System test: search for a known document by description and get a result
