---
name: auth
kind: platform
status: active
platform: rails
extends: system/auth/concept.md
description: JWT tokens, authenticate! before_action, internal shared secret — Rails
modules: []
---

# Authentication — Rails Platform Override

Extends `specifications/system/auth/concept.md`. Rails-specific implementation details only.

## Token Format
JWT. Claims: `org_id`, `user_id`, `exp`. Encoded/decoded via `web/app/lib/auth_token.rb`.

## User Auth Wiring
- `ApplicationController#authenticate!` — before_action on all protected controllers
- `POST /api/auth/token` — issues JWT. Phase 0: shared secret for dev, no registration UI.

## Internal Service Auth
- `X-Sidecar-Token` header — Go sidecar → Rails internal calls
- Verified independently of JWT in a separate before_action
- Secret loaded from `SIDECAR_TOKEN` env var via `ENV.fetch`

## Secret Value Object
`web/app/lib/secret.rb` — Ruby class. Overrides `inspect`, `to_s`, `as_json`. `.expose` returns raw value.

## Files
- `web/app/lib/auth_token.rb`
- `web/app/lib/secret.rb`
- `web/app/controllers/application_controller.rb`
- `web/app/controllers/api/auth_controller.rb`
- `web/config/routes.rb`

## Rails-specific Acceptance Criteria
- `AuthToken.encode(org_id:, user_id:)` returns a JWT string
- `AuthToken.decode(token)` returns claims hash or raises on invalid/expired
- `ApplicationController#authenticate!` sets `current_org_id` and `current_user_id` from token
- Sidecar endpoints use a separate `authenticate_sidecar!` before_action
- `POST /api/auth/token` with valid shared secret returns JWT
