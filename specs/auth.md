# Authentication

## What It Does

Two independent auth mechanisms:

1. **JWT** — user-facing API. Issued by `POST /api/auth/token`. Claims: `org_id`, `user_id`, `exp`.
2. **Shared secret** — Go sidecar → Rails internal calls. `X-Sidecar-Token` header. Not user-facing.

## Why Two Mechanisms

The Go sidecar is a trusted internal process, not a user. It doesn't need JWT — a shared secret in an env var is simpler and correct for an internal sidecar. User-facing endpoints need JWT for expiry and claim-based access control.

## Secret Value Object

All API keys and tokens in the system are wrapped in a `Secret` value object:
- `Secret#inspect` → `"[REDACTED]"`
- `Secret#to_s` → `"[REDACTED]"`
- `Secret#as_json` → `"[REDACTED]"`
- `Secret#expose` → the raw value (explicit, intentional)

This makes it structurally impossible to accidentally log a secret.

## Phase 0 Scope

- Single org (org_id = 1 hardcoded or from env)
- No user registration UI — token issued via shared secret for dev
- No OAuth, no SAML — add when the spec requires it

## Acceptance Criteria

- `Secret.new("key").inspect` returns `"[REDACTED]"`
- `Secret.new("key").to_s` returns `"[REDACTED]"`
- `Secret.new("key").as_json` returns `"[REDACTED]"`
- `Secret.new("key").expose` returns `"key"`
- Valid JWT authenticates user-facing endpoints
- Expired JWT returns 401
- Tampered JWT returns 401
- Missing token returns 401
- Valid `X-Sidecar-Token` authenticates sidecar endpoints independently of JWT
- Wrong sidecar token returns 401
