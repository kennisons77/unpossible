# PRD: API Documentation & Request Testing

- **Status:** Draft
- **Created:** 2026-04-01
- **Last revised:** 2026-04-01

## Intent

Every API endpoint is documented and covered by request integration tests. Documentation
and tests are derived from the same source so they stay in sync by construction. The
docs surface is the discovery mechanism for developers, the loop agent, and future
external consumers.

## Personas

- **Developer (primary):** needs to know what endpoints exist, what they accept, and
  what they return — without reading controller code.
- **Loop agent:** reads `/api/docs` at runtime to discover endpoints before calling
  them. Accurate enough is sufficient; regeneration is not required per iteration.
- **External developer (future):** building projects with unpossible; needs a stable,
  readable API contract.

## User Scenarios

**Scenario 1 — Developer explores the API:**
A developer wants to know the request shape for posting a node to the ledger. They open
`/api/docs`, find the endpoint, read the parameters and response shape, and make the
call. No code reading required.

**Scenario 2 — Loop agent discovers endpoints:**
Before making an API call, the loop reads `/api/docs` to confirm the endpoint path,
required parameters, and expected response shape. It uses this to assemble the correct
request without hardcoding assumptions.

**Scenario 3 — Loop authors a new endpoint:**
The build loop implements a new controller. The definition of done requires a
corresponding `spec/requests/` file. When `rake rswag:specs:swaggerize` is run, it
fails if the spec is missing or the endpoint is undocumented — the beat cannot be
marked complete until it passes.

**Scenario 4 — Endpoint shape drifts:**
A controller changes its response shape but the request spec is not updated. The next
`rake rswag:specs:swaggerize` run fails. The loop cannot mark the beat complete until
the spec is updated and the command exits 0.

## User Stories

- As a developer, I want all endpoints listed at `/api/docs` so I can explore the API
  without reading code.
- As the loop agent, I want `/api/docs` to be accurate enough to discover endpoint
  paths and parameters at runtime.
- As the system, I want `rake rswag:specs:swaggerize` to fail if any endpoint lacks a
  request spec, so undocumented endpoints cannot ship.
- As a developer, I want every endpoint covered by a request spec so I can trust the
  documented behaviour matches the implementation.

## Success Metrics

| Goal | Metric |
|---|---|
| No undocumented endpoints | `rake rswag:specs:swaggerize` exits 0 on every green build |
| Discoverability | Developer can find any endpoint at `/api/docs` without reading code |
| Sync by construction | Docs and tests share the same source — no separate doc maintenance step |

## Functional Requirements

**MVP:**

- **OpenAPI documentation** — generated from rswag request specs. Served at `/api/docs`
  (Swagger UI), permanently unauthenticated. Raw spec at `swagger/v1/swagger.yaml`.
- **Request integration tests** — one `spec/requests/` file per controller. Every
  endpoint covers: happy path (200/201), auth failure (401, once auth exists),
  validation failure (422), not found (404 where applicable).
- **Backpressure gate** — `rake rswag:specs:swaggerize` is part of the build. Fails if
  any endpoint is undocumented or any request spec is missing. A beat is not complete
  until it exits 0.
- **Error shape** — follows Rails conventions. No custom error envelope.
- **Auth** — all endpoints are unauthenticated in Phase 0. Auth is added by the build
  loop when the auth module is implemented. The 401 test case is written speculatively
  and enabled when auth lands.
- **No versioning** — `v1` is a rswag convention, not a versioning commitment. No
  versioning strategy until official release.

**Post-MVP:**

- CI enforcement — `rake rswag:specs:swaggerize` runs in CI on every push.
- Versioning strategy — defined at first official release.

## Features Out

- Custom error envelope
- API versioning (Phase 0)
- CI integration (later discussion)
- Authentication (added by build loop when auth module lands)

## Specs

| Spec file | Description |
|---|---|
| [`spec.md`](spec.md) | Documentation tooling, request test requirements, definition of done, acceptance criteria |

## Open Questions

| Question | Answer | Date |
|---|---|---|
| Should `rake rswag:specs:swaggerize` run automatically as part of `bundle exec rspec` or as a separate step? | Separate step for now — explicit gate, not implicit | 2026-04-01 |
| When auth lands, should the 401 specs be retroactively required for all existing endpoints? | Yes — auth module beat should include updating all existing request specs | 2026-04-01 |
