# Activity: Review Extraction

## User Story

As a user, I want to review and correct low-confidence or problematic document extractions so my library remains accurate.

## Capability Depth (POC)

**Basic** — Manual fill, diff view, confidence gating, duplicate decision

## What the User Does

1. **Review Queue:** Views a list of documents flagged for review with reason and confidence score
2. **Diff View:** Sees LLM-extracted fields side-by-side with editable form
3. **Approve:** Confirms extraction is correct and continues pipeline
4. **Edit:** Corrects individual fields and saves with human provenance
5. **Reject:** Marks document as rejected (stops pipeline)
6. **Duplicate Decision:** When hash conflict detected, chooses "mark as duplicate" or "new version"
7. **OCR Fallback:** When OCR quality is low, edits raw text directly
8. **Manual Fill:** When LLM returns malformed output, fills schema manually

## Why

LLMs are probabilistic and make mistakes. Human review on low-confidence extractions ensures data quality without requiring manual processing of every document. The diff view makes corrections fast — users only fix what's wrong.

## Acceptance Criteria

- Review queue lists all documents with `review_required: true`
- Each queue entry shows: filename, document type, concern, confidence score, review reason, stage
- Clicking a queue entry navigates to diff view
- Diff view renders LLM-extracted fields on left, editable form on right
- Empty schema template shown when no fields extracted yet
- Approve action clears `review_required` flag and enqueues pipeline job to continue from current stage
- Edit action saves changed fields as DocumentField records with `source: :human`
- Reject action sets document stage to `rejected` and does not continue pipeline
- Duplicate decision UI appears when review reason contains "Duplicate detected"
- Duplicate decision shows both documents (existing and new) side-by-side
- "Mark as duplicate" button sets new document stage to `rejected`
- "New version" button links documents via `previous_version_id`, clears review flag, continues pipeline
- OCR fallback UI shows editable textarea with raw OCR text when stage is early and review required
- Manual fill UI shows form with common fields when LLM returns malformed output
- All review actions redirect back to review queue
- Unauthenticated requests redirected to login

## Out of Scope (POC)

- Bulk approve/reject
- Review assignment (multi-user)
- Review history / audit log UI
- Keyboard shortcuts for review actions
- Field-level confidence scores (document-level only in POC)
- Suggested corrections from LLM
- Review queue filtering or sorting options
