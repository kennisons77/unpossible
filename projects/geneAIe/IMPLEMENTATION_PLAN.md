# Implementation Plan — The Sovereign Library (POC)

Scoped to the **POC release** defined in `specs/audience.md`: full 6-stage ETL pipeline working end-to-end on 10 real documents (Government IDs + Medical Records), searchable via full-text, with human review queue operational.

**Current state:** Zero application code exists. `app/` contains only `.gitkeep`. No `spec/`, `config/`, `db/`, or `library/` directories exist. Infrastructure files are placeholders. The build loop has never run.

---

## Missing Specs

Per-activity spec files do not yet exist for the four POC activities defined in `specs/audience.md`. These must be authored **before implementation begins** to provide acceptance criteria from which tests are derived.

| Activity | Expected spec file | Status |
|---|---|---|
| Ingest a document | `specs/ingest-document.md` | **Missing** |
| Review / correct extraction | `specs/review-extraction.md` | **Missing** |
| Search for a document | `specs/search-document.md` | **Missing** |
| Browse concern / type | `specs/browse-library.md` | **Missing** |

- [ ] **Author `specs/ingest-document.md`** — acceptance criteria for upload, folder watch, and API webhook ingestion at POC depth (files: `specs/ingest-document.md`)
  Required tests: derived from this spec once written
- [ ] **Author `specs/review-extraction.md`** — acceptance criteria for manual fill, diff view, confidence gating at POC depth (files: `specs/review-extraction.md`)
  Required tests: derived from this spec once written
- [ ] **Author `specs/search-document.md`** — acceptance criteria for keyword FTS search at POC depth (files: `specs/search-document.md`)
  Required tests: derived from this spec once written
- [ ] **Author `specs/browse-library.md`** — acceptance criteria for scaffold browse by concern/type at POC depth (files: `specs/browse-library.md`)
  Required tests: derived from this spec once written

**Missing practices file:** No `practices/framework/rails.md` exists. Rails-specific conventions (directory layout, generator usage, service object patterns, ActiveRecord conventions) should be documented before implementation begins.

- [ ] **Author `practices/framework/rails.md`** — Rails 8 conventions: service objects in `app/services/`, job naming, migration style, RSpec directory structure, factory patterns (files: `practices/framework/rails.md`)
  Required tests: N/A (reference document)

---

## Phase 0.5: Standards Baseline (from anados analysis)

These tasks harden the project against quality drift before the pipeline phases begin. Derived from production patterns in `anados/`.

- [ ] **RuboCop full config** — Extend `.rubocop.yml` with metrics from `practices/lang/ruby.md`: line 120, method 15, block 25, cyclomatic 6, params 5; enable `rubocop-performance`; CI must exit non-zero on violations (files: `.rubocop.yml`, `Gemfile`)
  Required tests: `bundle exec rubocop` passes on current codebase with zero offenses

- [ ] **SimpleCov 90% enforcement** — Add `simplecov` gem; configure in `spec/rails_helper.rb` with `minimum_coverage 90`; CI test run fails below threshold (files: `Gemfile`, `spec/rails_helper.rb`)
  Required tests: SimpleCov report generated on `bundle exec rspec`; threshold enforced

- [ ] **Brakeman security gate** — Add `brakeman` gem; add to test container run: `bundle exec brakeman --no-pager -q`; treat high-severity findings as CI blockers (files: `Gemfile`, `infra/docker-compose.yml` test command)
  Required tests: `bundle exec brakeman` exits 0 on current codebase

- [ ] **startup.sh** — Create `utilities/startup.sh` per `practices/infra/docker.md`: cleanup volumes, build images, migrate + seed, start services, print URLs; single command from zero to running (files: `utilities/startup.sh`)
  Required tests: script runs end-to-end without error in clean environment

- [ ] **Mailpit for local email** — Add `mailpit` service to `infra/docker-compose.yml`; configure Rails SMTP to point to Mailpit in development; web UI accessible at `localhost:8025` (files: `infra/docker-compose.yml`, `config/environments/development.rb`)
  Required tests: Rails boots without SMTP error in development environment

- [ ] **Tini as PID 1** — Add `tini` to `infra/Dockerfile`; set as `ENTRYPOINT`; ensures graceful shutdown signal handling in containers (files: `infra/Dockerfile`)
  Required tests: container starts and stops cleanly; `docker stop` does not require SIGKILL

- [ ] **deploy-k8s.sh wrapper** — Create `infra/deploy-k8s.sh` per `practices/infra/kubernetes.md`: tag image with git SHA, push to registry, apply manifests, wait for rollout; parameterised for staging vs. production (files: `infra/deploy-k8s.sh`, `infra/k8s/deployment.yaml`)
  Required tests: script validates required env vars and exits non-zero if missing

---

## Phase 0: Infrastructure (High Priority)

The `infra/Dockerfile` and `infra/docker-compose.yml` contain placeholder values that must be resolved before any containerized development or testing.

- [x] **Fix Dockerfile placeholders** — `FROM ruby:3.3-slim`, apt-get installs build-essential/libpq-dev/libyaml-dev/tesseract/poppler/git/nodejs, bundle install, CMD rails server. Includes proxy CA cert support for sandboxed builds.
- [x] **Fix docker-compose.yml placeholders** — Ports 3000:3000, test command `bundle exec rspec`, `depends_on` with health checks, `DATABASE_URL` env vars for app and test services.
- [x] **Add PostgreSQL service to docker-compose** — `pgvector/pgvector:pg16` with tmpfs (bind mounts caused initdb corruption in sandbox), health check via pg_isready.
- [x] **Add MinIO service to docker-compose** — `minio/minio` with console port 9001, API port 9000, health check, app service gets AWS env vars.
- [x] **Confirm Solid Queue/Cache backing** — Rails 8.1 Solid Queue and Solid Cache are database-backed by default. No Redis service needed. Confirmed: no Redis service in docker-compose.

---

## Phase 1: Rails Foundation

### 1.1 App Initialization

- [x] **Rails 8 app init** — Hand-crafted Rails 8.1 app (no network for `rails new`): PostgreSQL adapter, skipped Mailer/Mailbox/Cable, Solid Queue + Solid Cache configured, pgvector gem, Propshaft asset pipeline. `bundle exec rspec` exits 0, `bin/rails db:create` succeeds.
- [x] **RSpec and testing gems** — rspec-rails 7.0, factory_bot_rails 6.4, shoulda-matchers 6.0, capybara, selenium-webdriver. Configured in spec/rails_helper.rb with support files for FactoryBot and Shoulda.
- [ ] **RuboCop setup** — Add `rubocop`, `rubocop-rails`, `rubocop-rspec` gems; create `.rubocop.yml` with project-appropriate config (files: `Gemfile`, `.rubocop.yml`)
  Required tests: `bundle exec rubocop` runs without crash (warnings acceptable at this stage)

### 1.2 Authentication

- [x] **Auth scaffold** — Hand-crafted Rails 8 authentication: User model with `has_secure_password`, Session model, Authentication concern in ApplicationController, SessionsController with login/logout, single-user seed (`admin@sovereign.local`), dashboard landing page. 12 tests passing (model validations, associations, normalization, session CRUD, auth gating).

### 1.3 Core Models

- [x] **Document model** — stage enum (6 stages), review_required, content_hash, confidence_score, minio_blob_key, markdown_path, owner_id FK, concern_id FK, concern_tags array, document_type, embedding vector(1536), Active Storage attachment. 11 tests passing.
- [x] **Concern model** — name, owner_id FK, llm_proposed default true, confirmed_at nullable, confirmed/unconfirmed scopes, confirm! method. 9 tests passing.
- [x] **DocumentField model** — document_id FK, field_name, value, source enum (llm/ocr/human), composite index. 8 tests passing.
- [x] **Active Storage migration** — Added `create_active_storage_tables` migration for blobs/attachments/variant_records.
- [x] **Infra fixes** — docker-compose volume mounts corrected (`src/` not `app/`), disabled schema dump after migration (pgvector vector type not supported by Ruby schema dumper), `check_all_pending!` in rails_helper, `TimeHelpers` included in RSpec config.

### 1.4 Storage Configuration

- [ ] **Active Storage + MinIO config** — Configure Active Storage S3 service pointing to local MinIO in `config/storage.yml`; set as default in development; test env uses `:test` adapter; add `aws-sdk-s3` gem (files: `Gemfile`, `config/storage.yml`, `config/environments/development.rb`, `config/environments/test.rb`)
  Required tests: Active Storage configured without error on boot, test env uses test adapter
- [ ] **Git library service** — `LibraryGitService` class: initializes/opens git repo at configurable library path (env var `LIBRARY_PATH`, default `library/`); writes `.md` file to `{concern}/{document_type}/{doc_id}.md`; auto-commits with structured message including document ID, stage, source, timestamp; handles first-commit edge case; app repo `.gitignore` excludes `library/` (files: `app/services/library_git_service.rb`, `spec/services/library_git_service_spec.rb`, `.gitignore`)
  Required tests: creates file at correct nested path, commits with expected message format, creates missing subdirectories, handles first commit in empty repo, updates existing file and creates new commit

### 1.5 Frontend Base

- [ ] **Tailwind CSS + Hotwire setup** — `tailwindcss-rails` gem; `turbo-rails` and `stimulus-rails`; base application layout with navigation skeleton (login/logout, search bar placeholder, nav links) (files: `Gemfile`, `app/views/layouts/application.html.erb`, `app/assets/stylesheets/application.tailwind.css`, `config/tailwind.config.js`, `app/javascript/controllers/index.js`)
  Required tests: application layout renders without error, Tailwind classes present in rendered HTML

### 1.6 Scaffold Views

- [ ] **Document scaffold views** — Index (table listing with stage, type, concern, confidence), show (detail with fields, blob download link, markdown preview), basic controller with index/show actions (files: `app/controllers/documents_controller.rb`, `app/views/documents/index.html.erb`, `app/views/documents/show.html.erb`, `app/views/documents/_document.html.erb`, `config/routes.rb`, `spec/requests/documents_spec.rb`)
  Required tests: index returns 200 with documents listed, show returns 200 with document details, unauthenticated access redirected
- [ ] **Concern scaffold views** — Index, show (with associated documents), confirm action (files: `app/controllers/concerns_controller.rb`, `app/views/concerns/index.html.erb`, `app/views/concerns/show.html.erb`, `config/routes.rb`, `spec/requests/concerns_spec.rb`)
  Required tests: index lists concerns, show displays concern with documents, confirm action sets `confirmed_at`, unauthenticated access redirected

---

## Phase 2: Acquisition Adapters

- [ ] **Pipeline orchestrator job** — `PipelineOrchestratorJob` receives document ID; runs stages sequentially: categorization -> identification -> normalization -> storage -> enrichment; each stage is a separate service object; stops on failure and sets `review_required: true` with reason in `review_reason`; updates `document.stage` after each successful stage (files: `app/jobs/pipeline_orchestrator_job.rb`, `spec/jobs/pipeline_orchestrator_job_spec.rb`)
  Required tests: runs all stages in order on happy path (with stubs), stops at failing stage, sets `review_required` on failure with reason, updates stage after each success
- [ ] **File upload adapter** — Upload form on documents#new (drag-and-drop area + file picker via Stimulus controller); accepts PDF, PNG, JPG, TXT; stores blob via Active Storage to MinIO; creates Document at stage `acquired`; enqueues `PipelineOrchestratorJob` (files: `app/controllers/documents_controller.rb`, `app/views/documents/new.html.erb`, `app/javascript/controllers/upload_controller.js`, `spec/requests/documents_upload_spec.rb`)
  Required tests: uploading PDF creates Document at stage `acquired`, blob is attached, pipeline job enqueued; rejects unsupported file types; unauthenticated upload rejected
- [ ] **Folder watcher job** — `FolderWatcherJob` (Solid Queue recurring job) polls a configured directory path (env var `WATCH_DIR`); ingests new files not already tracked (by filename + mtime); moves processed files to `processed/` subdirectory; creates Document at stage `acquired` for each (files: `app/jobs/folder_watcher_job.rb`, `config/recurring.yml`, `spec/jobs/folder_watcher_job_spec.rb`)
  Required tests: new file in watched dir creates Document at `acquired`, file moved to `processed/`; already-processed file skipped; empty directory is no-op; missing directory raises descriptive error
- [ ] **API webhook endpoint** — `POST /api/v1/documents` accepting multipart file upload + optional JSON metadata (`document_type`, `concern`); bearer token auth from env var `API_TOKEN`; returns JSON with document ID and status; creates Document at stage `acquired` (files: `app/controllers/api/v1/documents_controller.rb`, `config/routes.rb`, `spec/requests/api/v1/documents_spec.rb`)
  Required tests: valid token + file creates Document at `acquired` and returns 201 with document ID; missing token returns 401; missing file returns 422; optional metadata persisted when provided

---

## Phase 3: Pipeline Stages

### 3.1 Text Extraction

- [ ] **Create test fixture files** — Add synthetic test fixtures for the spec suite: a small valid PDF, a scan image, and a text file containing PII patterns (files: `spec/fixtures/files/sample_utility_bill.pdf`, `spec/fixtures/files/sample_scan.png`, `spec/fixtures/files/sample_with_pii.txt`)
  Required tests: fixtures are loadable in specs, PII fixture contains expected SSN and DOB patterns
- [ ] **PDF text extraction service** — `TextExtractionService` wraps `pdftotext` CLI; accepts blob reference; returns extracted text or empty string if pdftotext produces nothing (signals OCR fallback needed) (files: `app/services/text_extraction_service.rb`, `spec/services/text_extraction_service_spec.rb`)
  Required tests: extracts text from digital PDF, returns empty string for image-only PDF, handles missing pdftotext binary gracefully
- [ ] **Tesseract OCR fallback service** — `OcrService` wraps `tesseract` CLI; accepts image blob (PNG, JPG) or PDF page image; returns extracted text + confidence score; flags low-confidence results for review (files: `app/services/ocr_service.rb`, `spec/services/ocr_service_spec.rb`)
  Required tests: extracts text from PNG scan, returns confidence score, low-confidence result flagged, handles corrupt image gracefully

### 3.2 PII Redaction

- [ ] **PII redaction service** — `PiiRedactionService` applies regex patterns: SSN (`\d{3}-\d{2}-\d{4}` -> `[SSN REDACTED]`), DOB patterns (various date formats), passport numbers, account numbers; returns redacted text as new string; never mutates original (files: `app/services/pii_redaction_service.rb`, `spec/services/pii_redaction_service_spec.rb`)
  Required tests: masks SSN pattern, masks DOB patterns, masks passport numbers, masks account numbers, leaves non-PII text unchanged, handles text with multiple PII types, returns new string (does not mutate input)

### 3.3 Categorization (Stage 2)

- [ ] **Anthropic API client wrapper** — `AnthropicClient` thin wrapper around HTTP calls to Claude Haiku; handles request formatting, response parsing, error handling, rate limiting; reads API key from env var `ANTHROPIC_API_KEY` (files: `app/services/anthropic_client.rb`, `spec/services/anthropic_client_spec.rb`)
  Required tests: formats request correctly, parses successful response, handles API error (4xx/5xx) gracefully, handles malformed JSON response, reads API key from environment
- [ ] **Categorization service** — `CategorizationService` takes document, runs PII redaction on extracted text, calls Claude Haiku to extract `concern`, `document_type`, `confidence_score`; creates or finds Concern record (LLM-proposed if new); updates Document; flags for review if confidence below threshold or LLM returns malformed output (files: `app/services/categorization_service.rb`, `spec/services/categorization_service_spec.rb`)
  Required tests: sets concern and document_type from LLM response, creates new LLM-proposed Concern if not found, reuses existing Concern if found, PII redacted before LLM call, low confidence flags `review_required`, malformed LLM output flags `review_required`, updates stage to `categorized`

### 3.4 Identification (Stage 3)

- [ ] **Identification service** — `IdentificationService` computes SHA-256 hash on raw blob bytes; checks for existing documents with same hash; hash match = potential duplicate (flags for review with both document IDs in `review_reason`); updates Document `content_hash` and stage to `identified` (files: `app/services/identification_service.rb`, `spec/services/identification_service_spec.rb`)
  Required tests: computes correct SHA-256 hash, stores hash on document, detects duplicate (same hash exists) and flags `review_required`, new unique hash proceeds without review, updates stage to `identified`

### 3.5 Normalization (Stage 4)

- [ ] **Markdown serializer** — `MarkdownSerializer` takes structured data hash and produces Markdown string with YAML front matter; validates required fields present; body section contains extracted text (files: `app/services/markdown_serializer.rb`, `spec/services/markdown_serializer_spec.rb`)
  Required tests: YAML front matter includes doc_id/concern/document_type/extracted fields, body section contains extracted text, handles missing optional fields gracefully, output is valid YAML parseable by `YAML.safe_load`
- [ ] **Normalization service** — `NormalizationService` orchestrates: text extraction (pdftotext -> OCR fallback) -> PII redaction -> Claude Haiku structured extraction (YAML front matter fields) -> `MarkdownSerializer` -> `LibraryGitService` write + commit; updates `document.markdown_path` and stage to `normalized` (files: `app/services/normalization_service.rb`, `spec/services/normalization_service_spec.rb`)
  Required tests: produces Markdown with valid YAML front matter, falls back to OCR when pdftotext returns empty, PII redacted before LLM call, malformed LLM extraction flags `review_required`, file written to correct library path, updates stage to `normalized`

### 3.6 Storage (Stage 5)

- [ ] **Storage confirmation service** — `StorageService` verifies: blob exists in Active Storage, Markdown file committed to git library (file exists at `markdown_path`), Postgres record fully populated; updates FTS tsvector column on document; sets stage to `stored` (files: `app/services/storage_service.rb`, `spec/services/storage_service_spec.rb`)
  Required tests: confirms blob attachment exists, confirms markdown file exists at path, updates tsvector column, sets stage to `stored`, fails if blob missing, fails if markdown missing

### 3.7 Enrichment (Stage 6)

- [ ] **Enrichment service** — `EnrichmentService` creates `DocumentField` records for each extracted field with `source: :llm` (or `:ocr` if OCR-sourced); updates stage to `enriched`; commits updated Markdown via `LibraryGitService` (files: `app/services/enrichment_service.rb`, `spec/services/enrichment_service_spec.rb`)
  Required tests: creates DocumentField for each extracted field, sets correct source enum, updates stage to `enriched`, git commit created for enrichment, handles document with no extracted fields gracefully

---

## Phase 4: Review Queue

- [ ] **Confidence gating logic** — Configurable threshold via env var `CONFIDENCE_THRESHOLD` (default 0.7); applied in `CategorizationService` and `OcrService`; documents below threshold set `review_required: true` with descriptive `review_reason`; initializer reads threshold from env (files: `config/initializers/pipeline.rb`, `spec/models/document_spec.rb`)
  Required tests: document with confidence 0.6 and threshold 0.7 flagged, document with confidence 0.8 not flagged, threshold configurable via environment
- [ ] **Review queue index** — `ReviewsController#index` lists all documents where `review_required: true`, ordered by creation date; shows review_reason, document_type, confidence_score (files: `app/controllers/reviews_controller.rb`, `app/views/reviews/index.html.erb`, `config/routes.rb`, `spec/requests/reviews_spec.rb`)
  Required tests: lists only review_required documents, empty queue shows appropriate message, unauthenticated access redirected
- [ ] **Diff view: new document** — `ReviewsController#show` renders side-by-side: LLM extraction fields (left) vs. empty schema template (right); user can approve all, edit individual fields, or reject; approve clears `review_required` and creates DocumentField records with `source: :human` for edits, then advances pipeline (files: `app/controllers/reviews_controller.rb`, `app/views/reviews/show.html.erb`, `app/views/reviews/_diff_view.html.erb`, `app/javascript/controllers/diff_controller.js`, `spec/requests/reviews_spec.rb`)
  Required tests: renders LLM fields alongside schema template, approve action clears `review_required` and advances stage, edited fields saved with `source: :human`, reject marks document rejected
- [ ] **Diff view: re-ingested document** — When a document re-processes (hash match to existing), show field-level diff between new extraction and previously stored version; highlight changed fields (files: `app/views/reviews/_version_diff.html.erb`, `app/services/field_diff_service.rb`, `spec/services/field_diff_service_spec.rb`)
  Required tests: identifies changed fields between versions, identifies new fields, identifies removed fields, unchanged fields shown without highlight
- [ ] **Stage-specific fallback UI** — OCR failure: editable raw text area pre-filled with OCR output; LLM failure: manual schema fill form with all expected fields blank; submitting either creates DocumentField records with `source: :human` (files: `app/views/reviews/_ocr_fallback.html.erb`, `app/views/reviews/_manual_fill.html.erb`, `spec/requests/reviews_spec.rb`)
  Required tests: OCR fallback shows raw text in editable field, manual fill form shows all schema fields, submitting manual fill creates DocumentField records with `source: :human`
- [ ] **Version-vs-duplicate decision UI** — Hash conflict review: show both documents side by side; user chooses "duplicate" (discard new, mark rejected) or "new version" (link as version, keep both) (files: `app/views/reviews/_duplicate_decision.html.erb`, `spec/requests/reviews_spec.rb`)
  Required tests: shows both documents, duplicate action marks new document rejected, version action links documents and keeps both

---

## Phase 5: Search

- [ ] **Full-text search index** — Add `tsv` tsvector column to documents table; ActiveRecord callback to update tsvector on save (covers Markdown content + document_type + concern name); GIN index on tsvector column (files: `db/migrate/*_add_tsv_to_documents.rb`, `app/models/document.rb`, `spec/models/document_spec.rb`)
  Required tests: tsvector populated on document save, tsvector updated on document update, GIN index exists on column
- [ ] **Search endpoint** — `SearchController#index` with `GET /search?q=`; uses PostgreSQL `@@` operator with `plainto_tsquery`; returns ranked results by `ts_rank`; handles empty query gracefully (files: `app/controllers/search_controller.rb`, `config/routes.rb`, `spec/requests/search_spec.rb`)
  Required tests: query matching document content returns that document, no matches returns empty result set, empty query returns all documents or appropriate message, results ordered by relevance rank
- [ ] **Search UI** — Search bar in main application layout (always visible); results page with document cards showing title/filename, document_type, concern, confidence_score, text snippet; card links to document show (files: `app/views/layouts/application.html.erb`, `app/views/search/index.html.erb`, `app/views/search/_result_card.html.erb`)
  Required tests: search bar present on all pages, results render document cards with expected fields, card links to document show page

---

## Phase 6: Verification

- [ ] **Rake task: full pipeline** — `rake pipeline:run[path/to/file]` triggers all 6 stages on a single file; outputs stage progression to stdout; useful for testing outside the web UI (files: `lib/tasks/pipeline.rake`, `spec/tasks/pipeline_rake_spec.rb`)
  Required tests: rake task creates Document at `acquired` and progresses through all stages, outputs status for each stage, handles nonexistent file path with clear error
- [ ] **Integration test: upload to stored** — Upload `sample_utility_bill.pdf` via controller; assert Document reaches stage `stored` with blob in Active Storage, markdown file at expected path, YAML fields populated, tsvector populated (files: `spec/integration/upload_to_stored_spec.rb`)
  Required tests: document reaches `stored` stage, blob attached, markdown path set and file exists, YAML front matter has required fields, tsvector is non-null
- [ ] **Integration test: OCR fallback** — Upload `sample_scan.png`; assert pdftotext produces empty -> Tesseract invoked -> text returned and used for categorization (files: `spec/integration/ocr_fallback_spec.rb`)
  Required tests: Tesseract invoked when pdftotext returns empty, extracted text is non-empty, document proceeds through pipeline
- [ ] **Integration test: PII in pipeline** — Upload `sample_with_pii.txt`; assert LLM call payload does not contain unmasked SSN (files: `spec/integration/pii_pipeline_spec.rb`)
  Required tests: LLM request body does not contain original SSN pattern, redacted placeholder present in LLM input
- [ ] **Integration test: hash conflict** — Upload same file twice; assert second upload triggers duplicate review queue entry (files: `spec/integration/hash_conflict_spec.rb`)
  Required tests: second document flagged `review_required`, review_reason indicates duplicate/hash conflict
- [ ] **Integration test: stage fallback** — Stub LLM to return malformed JSON; assert document flagged `review_required` and stage does not advance past categorization (files: `spec/integration/stage_fallback_spec.rb`)
  Required tests: document has `review_required: true`, stage remains at `acquired` or `categorized`, review_reason indicates LLM failure
- [ ] **System test: search returns result** — Capybara: ingest document with known content, navigate to search, enter keyword, assert result card appears (files: `spec/system/search_spec.rb`)
  Required tests: search for known keyword shows matching document card, card contains expected document_type and concern
- [ ] **System test: review queue diff view** — Capybara: create low-confidence document, navigate to review queue, assert diff view renders with LLM fields vs. schema template (files: `spec/system/review_queue_spec.rb`)
  Required tests: review queue lists the low-confidence document, clicking shows diff view, LLM-extracted fields visible, approve button functional
- [ ] **Manual POC run** — Process 10 real documents (mix of Government IDs and Medical Records) through full pipeline via upload UI and/or rake task; verify `git log` on library folder shows per-document commit history; verify MinIO blobs intact; verify FTS returns results (files: no code changes; results documented in `specs/activity.md`)
  Required tests: (manual) 10 documents reach `stored` or `enriched` stage, FTS returns results for each, review queue surfaces at least one low-confidence doc, `git log library/` shows commits

---

## Ambiguities and Open Questions

These items surfaced during planning. They do not block early phases but should be resolved before reaching the relevant task.

1. **Solid Queue / Solid Cache backing store** — Rails 8 ships these with database-backed adapters by default. Confirm no Redis service is needed for POC. This likely eliminates a dependency. *(Phase 0 task will resolve this.)*
2. **Library git repo isolation** — The `library/` folder needs its own git repo (separate from the application repo) to track document commits independently. The app repo `.gitignore` should exclude `library/`. `LibraryGitService` must `git init` if repo does not exist.
3. **Folder watcher path configuration** — The watched directory path needs to be configurable via env var `WATCH_DIR`. Whether it lives inside or outside the Docker container affects volume mount configuration in `docker-compose.yml`.
4. **API auth mechanism** — Plan uses a simple bearer token from env var `API_TOKEN`. The PRD does not specify API auth. This is a reasonable POC default but should be confirmed.
5. **pgvector dimensions** — Plan uses 1536 (common embedding size). Column present but unused in POC. Adjust if Claude embeddings use a different dimensionality.
6. **Concern tags storage** — PRD specifies `concern_tags (array)`. Plan uses PostgreSQL array column. A join table would be more normalized but adds complexity. Array column is acceptable for POC.
7. **Document rejection flow** — Review queue allows "reject" but PRD does not define what happens to rejected documents. Plan assumes: rejected documents remain in DB with a `rejected` stage or flag, do not proceed through pipeline. Needs confirmation.
8. **FTS tsvector source content** — `StorageService` updates tsvector, but the source content needs clarification: is it the raw extracted text, the Markdown body, the YAML field values, or a combination? Plan assumes Markdown content + document_type + concern name.
