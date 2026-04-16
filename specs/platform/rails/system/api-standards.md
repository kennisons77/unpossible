# API Documentation & Request Testing — Rails Platform Override

Extends `specs/system/api-standards.md`. Rails-specific implementation only.

## Documentation
- Gem: `rswag` (`rswag-api` + `rswag-ui` + `rswag-specs`)
- Swagger UI served at `/api/docs`, unauthenticated
- OpenAPI spec generated at `swagger/v1/swagger.yaml` via `rake rswag:specs:swaggerize`
- Spec file per controller under `spec/requests/`

## Request Tests
- RSpec request specs (`spec/requests/**/*_spec.rb`)
- Written using `rswag` DSL — each example both tests the endpoint and contributes to the generated spec
- Every controller spec covers: 200/201 happy path, 401 unauthenticated, 422 invalid input, 404 where applicable

## Definition of Done
A controller is not complete until:
1. Its request spec exists and passes
2. `rake rswag:specs:swaggerize` exits 0 and updates `swagger/v1/swagger.yaml`

## Spec-as-Documentation Generation

The pattern: request specs are the single source of truth for both test coverage
and API documentation. A rake task (`rake rswag:specs:swaggerize` in Rails, or
equivalent in other platforms) reads the specs and generates the OpenAPI YAML.

This is a repeatable pattern across platforms — whatever task runner the platform
uses (rake, make, go generate), there should be a single command that:
1. Runs the request specs
2. Generates the API documentation artifact
3. Fails if the specs and the documentation are out of sync

The generated artifact is committed to the repo. A stale artifact is a build failure.

## Shared Request Examples

Common response patterns are captured as shared examples to reduce duplication
across controller specs:

- **Create/update endpoint** — asserts Location header, empty body, valid response
- **Delete endpoint** — asserts empty body, resource destroyed
- **Validation error** — asserts 422 with errors in response body
- **Paginated endpoint** — asserts meta object with total_pages, current_page,
  previous_page

These shared examples are defined once and included in every controller spec that
matches the pattern. New shared examples are added when a pattern appears in three
or more specs.

## Files
- `web/spec/requests/**/*_spec.rb`
- `web/swagger/v1/swagger.yaml`
- `web/spec/swagger_helper.rb`
- `web/config/initializers/rswag.rb`

## Rails-specific Acceptance Criteria
- `GET /api/docs` returns 200 without authentication
- `rake rswag:specs:swaggerize` exits 0
- `swagger/v1/swagger.yaml` lists all API endpoints
- Every controller has a corresponding `spec/requests/` file
