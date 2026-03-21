# Activity Log

The agent must append to this log after every iteration.

## Log

- [DATE] [Context ID]: Started loop.
- [2026-03-18] Phase 0 + Phase 1.1 complete: Infrastructure (Dockerfile, docker-compose with pgvector/pg16, MinIO, proxy support) and Rails 8.1 app init (PostgreSQL, Solid Queue/Cache, RSpec/FactoryBot/Shoulda, Propshaft, Tailwind). Tests pass: 0 examples, 0 failures. Solid Queue and Solid Cache confirmed database-backed (no Redis needed).
- [2026-03-18] Phase 1.2 complete: Auth scaffold. User model (has_secure_password, email normalization), Session model, Authentication concern, SessionsController (login/logout), dashboard landing page, single-user seed. Added bcrypt gem. Fixed layout to remove missing tailwind.css asset reference. Disabled forgery protection in test env. Tests pass: 12 examples, 0 failures.
- [2026-03-19] Phase 1.3 complete: Core models. Document (6-stage enum, review_required, content_hash, confidence_score, concern_tags array, embedding vector, Active Storage attachment), Concern (name, owner FK, llm_proposed, confirmed/unconfirmed scopes, confirm!), DocumentField (field_name, value, source enum llm/ocr/human). Added Active Storage migration. Fixed docker-compose volume mounts (src/ not app/), disabled schema dump (pgvector incompatible), added TimeHelpers to RSpec. Tests pass: 41 examples, 0 failures.
- [2026-03-21] Phase 1.4a complete: Active Storage + MinIO config. Switched development env to :minio service; added auto-bucket-creation initializer; docker-compose now forwards proxy build args (HTTP_PROXY, HTTPS_PROXY, PROXY_CA_CERT_B64) to fix sandbox builds. 5 new specs for storage config verification. Tests pass: 46 examples, 0 failures.
- [2026-03-21] Phase 1.5 complete: Frontend base. Replaced Tailwind with Bootstrap 5 + Bootswatch Yeti theme. Added cssbundling-rails + importmap-rails gems; npm-based sass build for CSS; Turbo + Stimulus via importmap; Bootstrap navbar with login/logout, search placeholder, and flash partials. Updated all views (layout, login, dashboard) from Tailwind to Bootstrap classes. Fixed IMPLEMENTATION_PLAN.md inconsistency (said Tailwind, PRD says Bootstrap). Dockerfile updated with npm install + asset build steps. Tests pass: 55 examples, 0 failures.
