# Implementation Plan

Check off tasks as they are completed. The agent should pick the next unchecked task.

---

## Phase 1: Foundation

- [x] **Rails 8 app init** — new Rails 8 app with PostgreSQL, Solid Queue, Solid Cache; remove unnecessary defaults
- [x] **Auth scaffold** — Rails 8 built-in authentication (has_secure_password); single user seed
- [x] **Core models** — `User`, `Document` (with stage enum, owner_id FK, content_hash, confidence_score, minio_blob_key, markdown_path, embedding vector column), `Concern`, `DocumentField` (per-field provenance)
- [x] **MinIO setup** — local Docker container + Active Storage configuration for S3-compatible storage
- [ ] **Git library service** — `LibraryGitService`: writes `.md` files to `library/` folder and auto-commits on every create/update with structured commit messages
- [ ] **Frontend base** — Tailwind CSS + shadcn-style component library + Hotwire (Turbo/Stimulus) wired up
- [ ] **Scaffold admin views** — Rails scaffold for Document, Concern, DocumentField (Tailwind-styled; POC UI)

---

## Phase 2: Acquisition Adapters

- [ ] **File upload adapter** — drag-and-drop / file picker in browser; creates Document at stage `acquired`, blob stored in MinIO
- [ ] **Folder watcher job** — Solid Queue polling job that watches a configured directory; ingests new files automatically
- [ ] **API webhook endpoint** — `POST /api/v1/documents` accepting file + optional metadata; same pipeline entry point

---

## Phase 3: Pipeline Stages

- [ ] **Stage 4a: PDF text extraction** — `pdftotext` integration; extracts raw text from digital PDFs; falls through to OCR if empty
- [ ] **Stage 4b: Tesseract OCR** — fallback OCR for image/scan documents; wraps `tesseract` CLI via Ruby
- [ ] **PII redaction layer** — regex-based scrubber that masks SSN, DOB, passport number, account number patterns before any LLM call
- [ ] **Stage 2: Categorization** — Claude Haiku API call (thin Ruby wrapper); extracts `concern`, `document_type`, `confidence_score`; LLM-proposed concerns surface for user confirmation
- [ ] **Stage 3: Identification** — SHA-256 hash on raw blob; conflict detection triggers review queue entry
- [ ] **Stage 4c: Normalization** — Claude Haiku structured extraction (YAML front matter fields); writes `.md` file via LibraryGitService
- [ ] **Stage 5: Storage** — confirms blob is in MinIO, Markdown committed, Postgres record updated to `stored`
- [ ] **Stage 6: Enrichment + provenance** — `DocumentField` records created for each extracted field with `source: :llm`; human edits write new `DocumentField` with `source: :human`

---

## Phase 4: Review Queue

- [ ] **Confidence gating** — configurable threshold; documents below threshold flagged as `review_required`
- [ ] **Review queue UI** — inbox view listing all `review_required` documents
- [ ] **Diff view: new document** — side-by-side LLM extraction vs. empty schema template; approve / edit / reject
- [ ] **Diff view: re-ingested document** — field-level diff between new extraction and previous stored version
- [ ] **Stage-specific fallback UI** — OCR failure → editable raw text field; LLM failure → manual schema fill form
- [ ] **Version-vs-duplicate decision UI** — hash conflict review: show both documents, let user mark as duplicate or new version

---

## Phase 5: Search

- [ ] **Full-text search index** — PostgreSQL `tsvector` column on `documents`; updated on every normalize/enrich
- [ ] **Search endpoint** — `GET /search?q=` with postgres FTS query
- [ ] **Search UI** — search bar on main layout; results page with document cards showing key fields

---

## Phase 6: Verification (POC)

- [ ] **Rake task: full pipeline** — `rake pipeline:run[path/to/file]` triggers all 6 stages on a single file for testing
- [ ] **RSpec: PII redaction** — unit tests for each regex pattern; verify SSN/DOB/account masking
- [ ] **RSpec: SHA-256 identification** — duplicate detection and version conflict detection
- [ ] **RSpec: Markdown serialization** — verify YAML front matter output format
- [ ] **RSpec: per-field provenance** — verify DocumentField records created with correct source enum
- [ ] **Integration test: upload → stored** — upload a PDF, assert it reaches `stored` stage with correct YAML fields
- [ ] **System test: search** — ingest a known document, search for it by description, assert result returned
- [ ] **Manual POC run** — 10 real documents (Government IDs + Medical Records) through full pipeline; qualitative review

---

## Phase 7: Cleanup & Future Prep

- [ ] **LLM wrapper evaluation** — assess Langchainrb vs. current thin wrapper; extract a clean `LlmService` interface
- [ ] **pgvector query stubs** — add placeholder `Document.semantic_search` method that raises `NotImplementedError`; marks v2 boundary
- [ ] **Kamal deployment config** — `config/deploy.yml` for eventual server migration; not deployed yet
- [ ] **Concern taxonomy documentation** — seed file documents default concerns (Financial, Legal, Health, Identity); notes LLM-extension model
- [ ] **CLAUDE.md update** — update project CLAUDE.md with setup instructions, test command, architecture overview
