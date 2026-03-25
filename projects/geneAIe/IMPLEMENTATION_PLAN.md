# Implementation Plan — The Sovereign Library (POC)

Scoped to the **POC release**: full 6-stage ETL pipeline working end-to-end on 10 real documents (Government IDs + Medical Records), searchable via full-text, with human review queue operational.

**Current state:** Phase 1.5 complete. 55 tests passing. Rails 8.1 app with auth, core models, Active Storage + MinIO, Bootstrap 5 + Hotwire, LibraryGitService all working.

**Current Phase:** Phase 0 (Local — app runs and tests pass on dev machine)

---

## Blocking: PRD Missing Required Sections

The PRD lacks the standard Technical Constraints and Phase declaration sections expected by the planning system.

- [x] **Add Technical Constraints section to `specs/prd.md`** — Add section with: Language (Ruby 3.3), Framework (Rails 8), Base image (ruby:3.3-slim), Test command (bundle exec rspec), Port (3000) (files: `specs/prd.md`)
- [x] **Add Phase declaration to `specs/prd.md`** — Add `## Phase` section declaring current phase as Phase 0 (Local) (files: `specs/prd.md`)

---

## Blocking: Missing Activity Specs

Activity spec files must exist before implementation of their phases. Acceptance criteria drive required tests.

- [ ] **Author `specs/ingest-document.md`** — upload (web UI), folder watch, API webhook at POC depth; acceptance criteria: file accepted (PDF/PNG/JPG/TXT), Document created at `acquired` stage, blob stored in MinIO via Active Storage, PipelineOrchestratorJob enqueued, unauthenticated requests rejected (files: `specs/ingest-document.md`)
- [ ] **Author `specs/review-extraction.md`** — manual fill, diff view, confidence gating at POC depth; acceptance criteria: review queue lists all `review_required: true` documents with reason/confidence, diff view renders LLM-extracted fields vs. empty schema template side-by-side, approve action clears flag and advances pipeline, edit action saves fields with `source: :human`, reject action marks document rejected, duplicate decision UI shows both documents for version-vs-duplicate choice (files: `specs/review-extraction.md`)
- [ ] **Author `specs/search-document.md`** — keyword FTS at POC depth; acceptance criteria: search bar present on all authenticated pages, query returns matching documents ranked by relevance, results show document type/concern/confidence/snippet, empty query handled gracefully, no matches returns empty state message (files: `specs/search-document.md`)
- [ ] **Author `specs/browse-library.md`** — scaffold browse by concern/type at POC depth; acceptance criteria: documents index lists all documents with type/concern/stage/confidence, show page displays document metadata and all extracted fields with provenance (llm/ocr/human), concerns index lists all concerns with confirmed status, concern show page lists documents in that concern (files: `specs/browse-library.md`)

---

## Blocking: Missing Practices

- [ ] **Author `practices/framework/rails.md`** — Rails 8 conventions: service objects in `app/services/` (plain Ruby classes, single public method, return value or raise), job naming (`*Job` suffix, queue names), migration style (reversible, no data changes), RSpec directory structure (models/requests/services/integration/system), factory patterns (FactoryBot traits, associations), request vs. system specs (request for API/controller logic, system for full browser flows with Capybara), controller concerns in `app/controllers/concerns/`, model concerns in `app/models/concerns/` (files: `practices/framework/rails.md`)

---

## Phase 0.1: Fix Test Infrastructure

The test service command runs `npm install && npm run build` unnecessarily (already done in image build) and uses `db:drop` which fails on first run if DB doesn't exist.

- [ ] **Fix docker-compose.yml test command** — Replace test service `command` with: `bash -c "bin/rails db:prepare && bundle exec rspec"` (db:prepare creates DB if missing, loads schema, runs pending migrations) (files: `infra/docker-compose.yml`)
  Required tests: `docker compose -f infra/docker-compose.yml run --rm test` exits 0 with 55 tests passing

---

## Phase 0.2: Standards Setup

- [ ] **RuboCop configuration** — Create `.rubocop.yml` with AllCops: NewCops: enable, TargetRubyVersion: 3.3, line length 120, method length 15, block length 25, cyclomatic complexity 6; enable rubocop-rails and rubocop-rspec; run passes with warnings acceptable — do NOT fail CI on violations yet (files: `src/.rubocop.yml`)
  Required tests: `cd src && bundle exec rubocop` runs without crash (warnings OK)

---

## Phase 0.3: Test Fixtures

- [ ] **Create test fixture files** — Synthetic fixtures for specs: `sample_utility_bill.pdf` (digital PDF with text), `sample_scan.png` (image requiring OCR), `sample_with_pii.txt` (plain text containing SSN pattern 123-45-6789 and DOB pattern 01/15/1980) (files: `src/spec/fixtures/files/sample_utility_bill.pdf`, `src/spec/fixtures/files/sample_scan.png`, `src/spec/fixtures/files/sample_with_pii.txt`)
  Required tests: fixtures loadable via `Rails.root.join('spec/fixtures/files/...')`, PII fixture contains SSN and DOB patterns

---

## Phase 1: Scaffold Views (Browse Library Activity)

- [ ] **DocumentsController + views** — index (lists all documents with type/concern/stage/confidence in Bootstrap table), show (displays document metadata, attached blob link, all document_fields with source badges), routes (files: `src/app/controllers/documents_controller.rb`, `src/app/views/documents/index.html.erb`, `src/app/views/documents/show.html.erb`, `src/config/routes.rb`, `src/spec/requests/documents_spec.rb`)
  Required tests: GET /documents returns 200 with documents listed, GET /documents/:id returns 200 with metadata and fields, unauthenticated redirected to login

- [ ] **ConcernsController + views** — index (lists all concerns with confirmed status badge), show (lists documents in that concern), confirm action (POST /concerns/:id/confirm calls concern.confirm!), routes (files: `src/app/controllers/concerns_controller.rb`, `src/app/views/concerns/index.html.erb`, `src/app/views/concerns/show.html.erb`, `src/config/routes.rb`, `src/spec/requests/concerns_spec.rb`)
  Required tests: GET /concerns returns 200 with concerns listed, GET /concerns/:id returns 200 with documents, POST /concerns/:id/confirm sets confirmed_at and redirects, unauthenticated redirected

- [ ] **Add navigation links to layout** — Add Documents and Concerns links to navbar (files: `src/app/views/layouts/application.html.erb`)
  Required tests: (visual verification) navbar shows Documents and Concerns links when authenticated

---

## Phase 2: Pipeline Orchestrator

- [ ] **PipelineOrchestratorJob** — Runs stages sequentially: categorization → identification → normalization → storage → enrichment; stops on failure, sets `review_required: true` with reason in `review_reason`; updates `document.stage` after each success; each stage is a separate service call (files: `src/app/jobs/pipeline_orchestrator_job.rb`, `src/spec/jobs/pipeline_orchestrator_job_spec.rb`)
  Required tests: all stages run in order on happy path (stubbed services), stops at failing stage, sets `review_required` with reason, updates stage after each success, handles missing blob gracefully

---

## Phase 3: Acquisition Adapters (Ingest Document Activity)

- [ ] **File upload form + controller action** — `DocumentsController#new` (upload form with drag-and-drop via Stimulus), `#create` (accepts PDF/PNG/JPG/TXT, attaches via Active Storage, creates Document at `acquired`, enqueues PipelineOrchestratorJob, redirects to document show); reject unsupported file types (files: `src/app/controllers/documents_controller.rb`, `src/app/views/documents/new.html.erb`, `src/app/javascript/controllers/upload_controller.js`, `src/config/routes.rb`, `src/spec/requests/documents_upload_spec.rb`)
  Required tests: uploading PDF creates Document at `acquired` with blob attached and job enqueued, unsupported type rejected with 422, unauthenticated rejected

- [ ] **Folder watcher job** — `FolderWatcherJob` (Solid Queue recurring); polls `WATCH_DIR` env var (default: `Rails.root/watch`); ingests new files not already tracked by filename; attaches via Active Storage, creates Document at `acquired`, enqueues PipelineOrchestratorJob; moves processed files to `WATCH_DIR/processed/` subdir; configure in `config/recurring.yml` to run every 30 seconds (files: `src/app/jobs/folder_watcher_job.rb`, `src/config/recurring.yml`, `src/spec/jobs/folder_watcher_job_spec.rb`)
  Required tests: new file creates Document at `acquired` and moves to `processed/`, already-processed file skipped, empty dir is no-op, missing WATCH_DIR handled gracefully

- [ ] **API webhook endpoint** — `Api::V1::DocumentsController#create` (POST /api/v1/documents); multipart file + optional JSON metadata; bearer token auth from `API_TOKEN` env var; returns JSON with document ID and stage; creates Document at `acquired`, enqueues PipelineOrchestratorJob; namespace routes under `/api/v1` (files: `src/app/controllers/api/v1/documents_controller.rb`, `src/config/routes.rb`, `src/spec/requests/api/v1/documents_spec.rb`)
  Required tests: valid token + file → 201 with document ID, missing token → 401, invalid token → 401, missing file → 422, unsupported file type → 422

---

## Phase 4: Pipeline Services — PII & LLM Client

- [ ] **PiiRedactionService** — Regex masks SSN (###-##-####), DOB (MM/DD/YYYY and YYYY-MM-DD), passport (e.g. US passport format), account numbers (8+ consecutive digits); returns new string, never mutates input; class method `redact(text)` (files: `src/app/services/pii_redaction_service.rb`, `src/spec/services/pii_redaction_service_spec.rb`)
  Required tests: masks SSN (123-45-6789 → XXX-XX-XXXX), masks DOB (01/15/1980 → XX/XX/XXXX), masks passport, masks account numbers, leaves non-PII unchanged, handles multiple PII types in one string, does not mutate input, handles nil input gracefully

- [ ] **AnthropicClient** — Thin HTTP wrapper for Claude Haiku; reads `ANTHROPIC_API_KEY` from env; class method `call(prompt:, system: nil, max_tokens: 1024)`; returns parsed JSON from response content; handles 4xx/5xx with clear error messages; handles malformed JSON response; uses `net/http` (no gem dependency) (files: `src/app/services/anthropic_client.rb`, `src/spec/services/anthropic_client_spec.rb`)
  Required tests: formats request correctly (model: claude-3-haiku-20240307, messages array), parses JSON response from content[0].text, handles 401 (missing/invalid key), handles 429 (rate limit), handles 500, handles malformed JSON, raises clear error with status code

- [ ] **Pipeline configuration initializer** — Define `CONFIDENCE_THRESHOLD` (default 0.7), `WATCH_DIR` (default `Rails.root/watch`), `LIBRARY_PATH` (default `Rails.root/library`), `API_TOKEN` (required in production, optional in dev/test) as Rails.application.config values (files: `src/config/initializers/pipeline.rb`)
  Required tests: (none — config only)

---

## Phase 5: Pipeline Services — Text Extraction & OCR

- [ ] **TextExtractionService** — Wraps `pdftotext` CLI; class method `extract(file_path)`; returns extracted text or empty string if no text found; handles non-PDF gracefully (returns empty); uses `Open3.capture3` (files: `src/app/services/text_extraction_service.rb`, `src/spec/services/text_extraction_service_spec.rb`)
  Required tests: extracts text from digital PDF (use sample_utility_bill.pdf fixture), returns empty for image-only PDF, returns empty for non-PDF, handles missing file with clear error

- [ ] **OcrService** — Wraps `tesseract` CLI; class method `extract(image_path)`; returns hash `{ text: String, confidence: Float }`; confidence is mean of per-word confidence from `tesseract --psm 3 tsv` output; handles non-image gracefully (files: `src/app/services/ocr_service.rb`, `src/spec/services/ocr_service_spec.rb`)
  Required tests: extracts text from PNG (use sample_scan.png fixture), returns confidence score 0.0–1.0, handles non-image with clear error, handles missing file

---

## Phase 6: Pipeline Services — Categorization (Stage 2)

- [ ] **CategorizationService** — Class method `call(document)`; extracts text from blob (TextExtractionService → OcrService fallback if empty); PII redact via PiiRedactionService; Claude Haiku prompt: "Classify this document. Return JSON: {concern: string, document_type: string, confidence: float}"; parse response; find_or_create Concern (set llm_proposed: true if new); update document with concern_id, document_type, confidence_score; flag `review_required: true` if confidence < CONFIDENCE_THRESHOLD or malformed JSON; update stage to `categorized`; return document (files: `src/app/services/categorization_service.rb`, `src/spec/services/categorization_service_spec.rb`)
  Required tests: sets concern/document_type from LLM response, creates LLM-proposed Concern if new (llm_proposed: true), reuses existing Concern by name, PII redacted before LLM call (stub AnthropicClient, verify prompt has no SSN), low confidence flags `review_required`, malformed JSON flags `review_required`, stage → `categorized`, OCR fallback invoked when pdftotext returns empty

---

## Phase 7: Pipeline Services — Identification (Stage 3)

- [ ] **IdentificationService** — Class method `call(document)`; compute SHA-256 hash on `document.original_blob.download`; check for existing Document with same `content_hash`; if match found, set `review_required: true` with `review_reason: "Duplicate detected: doc #{existing.id}"` and do not advance stage; if unique, update `content_hash` and stage to `identified`; return document (files: `src/app/services/identification_service.rb`, `src/spec/services/identification_service_spec.rb`)
  Required tests: computes correct SHA-256 hash, stores hash in content_hash column, duplicate detected and flags `review_required` with reason including existing doc ID, unique hash proceeds and stage → `identified`, handles missing blob gracefully

---

## Phase 8: Pipeline Services — Normalization (Stage 4)

- [ ] **MarkdownSerializer** — Class method `serialize(document, extracted_fields: {})`; generates Markdown with YAML front matter; front matter includes: doc_id, concern, document_type, confidence_score, content_hash, stage, extracted_fields hash; body includes "# Extracted Content" heading followed by extracted text or "[No text extracted]"; returns string (files: `src/app/services/markdown_serializer.rb`, `src/spec/services/markdown_serializer_spec.rb`)
  Required tests: produces valid YAML front matter, includes all document metadata, handles nil concern (outputs "uncategorized"), handles empty extracted_fields, handles nil extracted text, YAML is parseable via `YAML.safe_load`

- [ ] **NormalizationService** — Class method `call(document)`; extract text (TextExtractionService → OcrService fallback); PII redact; Claude Haiku structured extraction prompt: "Extract key fields from this {document_type}. Return JSON: {field_name: value, ...}"; parse response; if malformed, flag `review_required` and stop; serialize via MarkdownSerializer; write via LibraryGitService; update `markdown_path`; stage → `normalized`; return document (files: `src/app/services/normalization_service.rb`, `src/spec/services/normalization_service_spec.rb`)
  Required tests: produces Markdown with valid YAML, OCR fallback when pdftotext empty, PII redacted before LLM, malformed LLM flags `review_required` and does not advance stage, file written to correct library path (concern/document_type/id.md), markdown_path updated, stage → `normalized`, handles missing concern gracefully (uses "uncategorized")

---

## Phase 9: Pipeline Services — Storage & Enrichment (Stages 5–6)

- [ ] **StorageService** — Class method `call(document)`; verify blob exists via `document.original_blob.attached?`; verify markdown file exists at `document.markdown_path`; verify Postgres record saved; if any missing, raise error with details; update stage to `stored`; return document (files: `src/app/services/storage_service.rb`, `src/spec/services/storage_service_spec.rb`)
  Required tests: confirms blob attached, confirms markdown file exists on disk, stage → `stored`, raises clear error if blob missing, raises clear error if markdown missing

- [ ] **EnrichmentService** — Class method `call(document)`; read markdown file from `document.markdown_path`; parse YAML front matter; for each field in `extracted_fields`, create DocumentField with field_name, value, source: :llm; commit updated markdown via LibraryGitService with source: 'enrichment'; stage → `enriched`; return document (files: `src/app/services/enrichment_service.rb`, `src/spec/services/enrichment_service_spec.rb`)
  Required tests: creates DocumentField per extracted field, correct source enum (:llm), stage → `enriched`, git commit created with source: 'enrichment', handles no extracted fields gracefully (no DocumentFields created, stage still advances), handles missing markdown file with clear error

---

## Phase 10: Review Queue (Review/Correct Extraction Activity)

- [ ] **ReviewsController + index view** — `ReviewsController#index` lists `Document.needing_review` ordered by created_at; shows filename (from blob), document_type, concern, confidence_score, review_reason, stage; links to show; Bootstrap table (files: `src/app/controllers/reviews_controller.rb`, `src/app/views/reviews/index.html.erb`, `src/config/routes.rb`, `src/spec/requests/reviews_spec.rb`)
  Required tests: GET /reviews returns 200 with review_required docs listed, empty queue shows "No documents need review" message, unauthenticated redirected

- [ ] **ReviewsController#show + diff view** — Show page with document metadata at top; diff view partial renders side-by-side: left = LLM-extracted fields (from markdown YAML or empty if none), right = editable form with same fields; approve button (POST /reviews/:id/approve), edit+save button (PATCH /reviews/:id), reject button (POST /reviews/:id/reject) (files: `src/app/controllers/reviews_controller.rb`, `src/app/views/reviews/show.html.erb`, `src/app/views/reviews/_diff_view.html.erb`, `src/config/routes.rb`, `src/spec/requests/reviews_spec.rb`)
  Required tests: GET /reviews/:id returns 200 with diff view, approve clears `review_required` and enqueues PipelineOrchestratorJob to continue from current stage, edited fields saved as DocumentField with `source: :human`, reject sets stage to `rejected` (add to Document::STAGES enum), unauthenticated redirected

- [ ] **Duplicate decision UI** — When `review_reason` contains "Duplicate detected", render special partial showing both documents side-by-side; "Mark as duplicate" button (discards new, sets stage to `rejected`), "New version" button (links both via `previous_version_id` FK on Document, clears review flag, continues pipeline) (files: `src/app/views/reviews/_duplicate_decision.html.erb`, `src/db/migrate/*_add_previous_version_to_documents.rb`, `src/app/models/document.rb`, `src/spec/requests/reviews_duplicate_spec.rb`)
  Required tests: duplicate decision view renders when reason contains "Duplicate detected", "Mark as duplicate" sets stage to `rejected`, "New version" sets previous_version_id and clears review_required, both actions redirect to review queue

- [ ] **OCR fallback UI** — When stage is `acquired` or `categorized` and review_required, show editable textarea with raw OCR text; submit creates DocumentField records with `source: :human` and advances pipeline (files: `src/app/views/reviews/_ocr_fallback.html.erb`, `src/spec/requests/reviews_ocr_spec.rb`)
  Required tests: OCR fallback renders editable textarea, submit creates DocumentField with `source: :human`, submit clears review_required and enqueues pipeline job

- [ ] **Manual schema fill UI** — When stage is `categorized` and review_required due to malformed LLM, show form with common fields for the document_type (or generic fields if type unknown); submit creates DocumentField records with `source: :human` and advances pipeline (files: `src/app/views/reviews/_manual_fill.html.erb`, `src/spec/requests/reviews_manual_spec.rb`)
  Required tests: manual fill form renders with fields, submit creates DocumentField with `source: :human`, submit clears review_required and advances pipeline

---

## Phase 11: Search (Search Document Activity)

- [ ] **Add tsvector column + FTS index** — Migration adds `tsv` tsvector column to documents; GIN index on tsv; ActiveRecord callback `before_save :update_tsv` concatenates markdown content (if file exists) + document_type + concern.name into tsvector using `to_tsvector('english', ...)` (files: `src/db/migrate/*_add_tsv_to_documents.rb`, `src/app/models/document.rb`, `src/spec/models/document_fts_spec.rb`)
  Required tests: tsvector populated on save, GIN index exists (check via raw SQL), updating document updates tsv, handles missing markdown file (uses document_type + concern only), handles nil concern

- [ ] **SearchController + results view** — `SearchController#index` (GET /search?q=); uses `plainto_tsquery` + `ts_rank` to order results; returns documents with text snippet (via `ts_headline`); empty query returns empty set; results rendered as Bootstrap cards with document_type, concern, confidence, snippet, link to show (files: `src/app/controllers/search_controller.rb`, `src/app/views/search/index.html.erb`, `src/app/views/search/_result_card.html.erb`, `src/config/routes.rb`, `src/spec/requests/search_spec.rb`)
  Required tests: query returns matching document ordered by rank, no matches returns empty set with message, empty query handled (returns empty or all docs — decide in implementation), results include snippet via ts_headline, unauthenticated redirected

- [ ] **Wire search form in navbar** — Update layout search form to submit to `/search` with `q` param (files: `src/app/views/layouts/application.html.erb`)
  Required tests: (visual verification) search form submits to /search

---

## Phase 12: Integration Tests

- [ ] **Upload-to-stored integration test** — Upload a PDF via controller, stub all LLM calls, verify document reaches `stored` stage with blob attached, markdown file written, content_hash set, tsvector populated (files: `src/spec/integration/upload_to_stored_spec.rb`)
  Required tests: document progresses through all stages, blob exists in Active Storage, markdown file exists on disk, content_hash set, stage = `stored`

- [ ] **OCR fallback integration test** — Upload an image-only PDF (or PNG), stub pdftotext to return empty, verify OcrService invoked, document reaches `normalized` with OCR-extracted text in markdown (files: `src/spec/integration/ocr_fallback_spec.rb`)
  Required tests: pdftotext returns empty, OcrService called, markdown contains OCR text, stage = `normalized`

- [ ] **PII pipeline integration test** — Upload document with PII in fixture, stub AnthropicClient to capture prompt, verify prompt has no unmasked SSN or DOB (files: `src/spec/integration/pii_pipeline_spec.rb`)
  Required tests: LLM prompt contains XXX-XX-XXXX instead of 123-45-6789, LLM prompt contains XX/XX/XXXX instead of 01/15/1980

- [ ] **Hash conflict integration test** — Upload same file twice, verify second upload flags `review_required` with reason containing first document ID (files: `src/spec/integration/hash_conflict_spec.rb`)
  Required tests: first upload reaches `identified`, second upload stops at `identified` with `review_required: true` and reason mentioning first doc ID

- [ ] **Stage fallback integration test** — Stub AnthropicClient to return malformed JSON during categorization, verify document flags `review_required` and does not advance past `acquired` (files: `src/spec/integration/stage_fallback_spec.rb`)
  Required tests: malformed LLM response flags `review_required`, stage remains `acquired`, review_reason mentions malformed JSON

---

## Phase 13: System Tests (E2E with Capybara)

- [ ] **Search system test** — Log in, upload document with known keyword, wait for pipeline to complete (poll document.stage), search for keyword, verify result card appears with document (files: `src/spec/system/search_spec.rb`)
  Required tests: search for known keyword shows matching card, clicking card navigates to document show page

- [ ] **Review queue system test** — Log in, upload document that will trigger low confidence (stub LLM to return confidence 0.5), verify document appears in review queue, click to diff view, verify approve button present (files: `src/spec/system/review_queue_spec.rb`)
  Required tests: low-confidence doc appears in /reviews, clicking row navigates to /reviews/:id, diff view renders with approve button

---

## Phase 14: Verification & POC Completion

- [ ] **Rake task: pipeline runner** — `rake pipeline:run[path/to/file]` triggers full pipeline on a single file; creates Document at `acquired`, enqueues PipelineOrchestratorJob, outputs stage progression to stdout; handles nonexistent file with clear error (files: `src/lib/tasks/pipeline.rake`, `src/spec/tasks/pipeline_rake_spec.rb`)
  Required tests: creates Document at `acquired` and progresses through stages (stubbed services), outputs stage to stdout, handles nonexistent file with error message

- [ ] **Manual POC run** — Process 10 real documents (Government IDs + Medical Records) via upload UI and/or rake task; verify: git log shows commits in `library/` folder, MinIO blobs exist (check via MinIO console at localhost:9001), FTS returns results for known keywords, review queue surfaces at least one low-confidence doc; document results in `specs/activity.md` (files: no code changes; results documented in `specs/activity.md`)
  Required tests: (manual verification) 10 docs reach `stored` or `enriched`, FTS returns results, review queue has entries, `git log library/` shows commits, MinIO console shows blobs

---

## Deferred (post-POC)

These are explicitly out of scope for POC and should not be implemented until the pipeline is proven on real documents:

- SimpleCov 90% enforcement
- Brakeman security gate
- RuboCop as CI blocker (setup only, non-blocking in Phase 0)
- startup.sh utility script
- Mailpit for local email
- Tini as PID 1
- deploy-k8s.sh / Kamal deployment config
- pgvector semantic search queries (column exists, queries deferred)
- LLM wrapper evaluation (Langchainrb)
- Email ingestion adapter
- Concern taxonomy seed file
- Multi-user auth flows
- Phase 1 (CI), Phase 2 (Staging), Phase 3 (Production) infrastructure

---

## Open Questions (resolve before relevant phase)

1. **Document rejection flow** — PRD does not define what happens to rejected documents. Assumption: add `rejected` to Document::STAGES enum, document stays in DB, does not proceed. Confirm before Phase 10.
2. **FTS tsvector source content** — Assumption: Markdown body + document_type + concern.name concatenated. Confirm before Phase 11.
3. **Folder watcher volume mount** — `WATCH_DIR` inside or outside container affects docker-compose volume config. Assumption: `WATCH_DIR` defaults to `Rails.root/watch` inside container; mount `../watch:/app/watch` in docker-compose.yml. Confirm before Phase 3 folder watcher task.
4. **API auth mechanism** — Bearer token from `API_TOKEN` env var assumed. Confirm before Phase 3 API task.
5. **Empty search query behavior** — Should empty query return all documents or empty set? Assumption: empty set. Confirm before Phase 11.
6. **Concern name sanitization** — LibraryGitService already sanitizes concern names for filesystem paths. Confirm this is sufficient or if additional validation needed on Concern model.
7. **LLM prompt engineering** — Categorization and normalization prompts are minimal in this plan. Refine prompts based on real document results during POC run.
8. **OCR confidence threshold** — What confidence score triggers review? Assumption: same as LLM confidence (0.7). Confirm before Phase 5.
