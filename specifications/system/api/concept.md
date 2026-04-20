---
name: api
kind: concept
status: active
description: Every endpoint documented and covered by request integration tests
modules: []
---

# API Documentation & Request Testing

## What It Does

Every API endpoint is documented and covered by request integration tests. Documentation and tests are derived from the same source — they stay in sync by construction.

## Documentation

All endpoints expose machine-readable API documentation. Documentation must:
- Describe every endpoint: method, path, parameters, request body, response shape, error codes
- Be generated from code or annotations — not maintained by hand
- Be accessible at a well-known path (e.g. `/api/docs`)
- Stay current automatically as endpoints change

## Request Integration Tests

Every endpoint has at least one request integration test. Tests must cover:
- Happy path — valid request returns expected status and response shape
- Auth failure — missing or invalid token returns 401
- Validation failure — malformed input returns 422 with an error body
- Not found — missing resource returns 404 where applicable

Tests run in the standard test suite — no separate test command.

## Principles

- Documentation and tests are not optional additions — they are part of the definition of done for any API endpoint
- A new endpoint is not complete until it has documentation and request tests
- Tests verify behaviour, not implementation — assert on response status and body shape, not internal state

## Acceptance Criteria

- All endpoints are listed in the generated documentation
- Documentation is accessible without authentication
- Every endpoint has a request integration test covering happy path and auth failure
- Adding a new endpoint without documentation and request tests fails the build
