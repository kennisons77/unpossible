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
