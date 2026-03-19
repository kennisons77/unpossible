# Testing Strategy

## Stack-Specific Commands

- Run tests: `bundle exec rspec`
- Run a single test: `bundle exec rspec spec/path/to/file_spec.rb`
- Lint: `bundle exec rubocop`

## Core Principles

- **Test behavior, not implementation.** Tests should verify what the code does, not how it does it.
- **One assertion per test** where possible. Multiple assertions signal multiple behaviors that should be split.
- **Test all cases.** For each unit of behavior, cover: happy path, edge cases, and error/invalid input.
- **Prefer real dependencies over mocks** for integration tests. Mock only at system boundaries (external APIs, file system, clock).
- **Keep tests fast.** Isolate slow tests (DB, network) so unit tests can run quickly.
- **Tests are documentation.** A failing test should tell you exactly what broke and why.

## Test Categories

### Unit Tests

Fast, no I/O, no external dependencies.

| Subject | What to test |
|---|---|
| PII redaction | Each regex pattern masks correctly: SSN (`\d{3}-\d{2}-\d{4}`), DOB patterns, passport numbers, account numbers |
| SHA-256 identification | Duplicate detection (same hash), version detection (different hash, same entity), conflict queue entry created |
| Markdown serializer | YAML front matter fields match expected schema; file written to correct library path |
| Per-field provenance | `DocumentField` records created with correct `source` enum (`:llm`, `:ocr`, `:human`) on each pipeline stage |
| Concern taxonomy | LLM-proposed concerns are not auto-committed; they surface for confirmation |
| Confidence gating | Documents below threshold set `review_required: true` |

### Integration Tests

May use real database. Stub only external API calls and blob storage.

| Scenario | Pass condition |
|---|---|
| Upload PDF → stored | File uploaded → blob in MinIO → markdown file committed to git → Document at stage `stored` with YAML fields populated |
| OCR fallback | Digital PDF with no extractable text → Tesseract invoked → text returned |
| PII redaction in pipeline | Document with SSN-pattern text → LLM call payload does not contain unmasked SSN |
| Hash conflict | Re-upload same file → duplicate review queue entry created |
| Stage fallback | LLM returns malformed JSON → document flagged `review_required`, stage does not advance |

### End-to-End / System Tests (Capybara)

| Scenario | Pass condition |
|---|---|
| Search returns result | Ingest document with known content → search for keyword → result card appears |
| Review queue diff view | Low-confidence document → navigate to review queue → diff view renders LLM fields vs. schema template |

## Test Fixtures

- `spec/fixtures/files/sample_utility_bill.pdf` — clean digital PDF, no PII
- `spec/fixtures/files/sample_scan.png` — low-resolution scan for Tesseract testing
- `spec/fixtures/files/sample_with_pii.txt` — synthetic text with SSN and DOB patterns for redaction tests

## What NOT to Test

- Actual Claude Haiku API responses — stub the HTTP call; test the wrapper's parsing logic
- MinIO blob storage — use Active Storage `:test` adapter
- Git commit side effects — stub `LibraryGitService` in unit/integration tests; test it directly in its own spec
- OCR accuracy — Tesseract quality is an external dependency, not unit-testable
- Third-party library internals
- Trivial getters/setters with no logic

## POC Acceptance Criteria

The POC is verified when:
1. All RSpec tests pass (`bundle exec rspec`)
2. 10 real documents complete the full pipeline end-to-end
3. Full-text search returns the correct document for at least one query per document type
4. Review queue correctly surfaces at least one low-confidence extraction
5. `git log` on the library folder shows per-document commit history
