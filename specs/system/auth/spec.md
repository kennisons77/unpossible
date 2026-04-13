# Authentication

## What It Does

Protects all resources behind verifiable identity. Two independent mechanisms cover the two trust domains in the system:

1. **User auth** — issued tokens with expiry and claims. Used by all user-facing API endpoints.
2. **Internal service auth** — shared secret between trusted internal processes. Not user-facing.

## Core Concepts

### Token-based user auth
- Tokens carry claims: `org_id`, `user_id`, `exp` (expiry)
- Tokens are stateless and verifiable without a database lookup
- Expired or tampered tokens are rejected at the boundary — no request reaches application logic

### Internal service auth
- Trusted internal processes (e.g. sidecars) use a shared secret, not user tokens
- The two mechanisms are independent — a valid user token does not grant sidecar access and vice versa

### Secret value object
All credentials and tokens in the system are wrapped in a `Secret` value object:
- Redacts itself in all serialization paths (`inspect`, `to_s`, `as_json` → `"[REDACTED]"`)
- `.expose` is the only way to access the raw value — explicit and intentional
- Makes it structurally impossible to accidentally log a credential

## Multi-tenancy
- Every authenticated request carries an `org_id` claim
- All data access is scoped to that org — cross-org access is not possible
- Phase 0: single org. Migration to multi-tenancy is additive.

## Phase 0 Scope
- No OAuth, no magic links, no SAML — add when the spec requires it
- Token issuance via shared secret for local development
- No user registration UI

## Acceptance Criteria

- `Secret.new("key").inspect` → `"[REDACTED]"`
- `Secret.new("key").to_s` → `"[REDACTED]"`
- `Secret.new("key").as_json` → `"[REDACTED]"`
- `Secret.new("key").expose` → `"key"`
- Valid token authenticates user-facing endpoints
- Expired token → 401
- Tampered token → 401
- Missing token → 401
- Valid internal service credential authenticates internal endpoints independently
- Wrong internal service credential → 401
- Every route is explicitly public or authenticated — no route is accidentally unprotected
