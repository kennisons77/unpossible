# Activity: Ingest Document

## User Story

As a user, I want to add documents to my library so they can be processed and made searchable.

## Capability Depth (POC)

**Basic** — Upload via web UI, folder watch, API webhook

## What the User Does

1. **Web Upload:** Drags a file onto the upload form or clicks to browse and select
2. **Folder Watch:** Drops a file into a watched directory on disk
3. **API Webhook:** POSTs a file to the API endpoint with a bearer token

## Why

Documents exist in fragmented locations (email attachments, downloads folder, physical scans). Ingestion adapters meet users where their documents already are, reducing friction to get data into the system.

## Acceptance Criteria

- File accepted: PDF, PNG, JPG, TXT formats supported
- Document record created at `acquired` stage
- Original blob stored in MinIO via Active Storage
- PipelineOrchestratorJob enqueued to begin processing
- Unauthenticated requests rejected (web UI redirects to login, API returns 401)
- Unsupported file types rejected with clear error message (web: flash error, API: 422 with JSON error)
- Folder watcher processes new files automatically within 30 seconds
- Folder watcher moves processed files to `processed/` subdirectory
- API webhook accepts optional metadata (e.g., source, tags) and stores in document attributes
- API webhook returns JSON with document ID and current stage

## Out of Scope (POC)

- Email ingestion adapter
- Batch upload (multiple files at once)
- Progress indicators during upload
- File size limits or validation beyond format
- Virus scanning
- Automatic retry on failed upload
