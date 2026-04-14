# Practices LOOKUP

Quick reference for recurring patterns in this codebase.

## Security

| Pattern | Location | Notes |
|---|---|---|
| `Secret` value object | `web/app/lib/secret.rb` | Wraps sensitive strings; `.expose` returns raw value; inspect/to_s/as_json → `[REDACTED]` |
| `filter_parameters` | `config/application.rb` | Filters `:api_key, :token, :password, :secret` from logs |
| `rack-attack` | `config/initializers/rack_attack.rb` | IP throttle → 429; safelist localhost in test |
| Audit on destructive | `Analytics::AuditLogService` | Call before any delete/update of sensitive data |
| STRIDE checklist | `specs/practices/threat-modeling.md` | Run per trust-boundary task during planning |
| Edge case prompts | `specs/practices/threat-modeling.md` | Targeted prompts to surface domain-specific threats |

## Auth

| Pattern | Location | Notes |
|---|---|---|
| JWT encode/decode | `web/app/lib/auth_token.rb` | `org_id`, `user_id`, `exp`; `AUTH_SECRET` env var |
| `authenticate!` | `ApplicationController` | Sets `current_org_id` / `current_user_id` |
| Sidecar token | `X-Sidecar-Token` header | From `SIDECAR_TOKEN` env var |

## Configuration

| Pattern | Location | Notes |
|---|---|---|
| `ENV.fetch` | everywhere | Fail fast on missing env vars — never `ENV[]` |
| `RALPH_COMPLETE` | loop output | Output when task committed and done |
| `RALPH_WAITING` | loop output | Output when human input needed |

## Module Boundaries

| Pattern | Notes |
|---|---|
| No cross-module model access | Call public service interface only |
| Shared lib | `web/lib/` — not inside any module |

## LLM / Agent

| Pattern | Notes |
|---|---|
| `Ultrathink` | Prefix for deep reasoning prompts — triggers extended thinking |
| Effort parameter | `low` / `medium` / `high` — controls token budget for LLM calls |
| Prompt dedup | `Agents::RunStorageService` — SHA256 of normalized prompt |
| Prompt sanitization | `Security::PromptSanitizer.sanitize(text)` — call before every LLM call |

## Structural Vocabulary

| Term | Location | Notes |
|---|---|---|
| Structural vocabulary | `specs/practices/structural-vocabulary.md` | Named abstractions for plan/review shorthand |
| Pattern lifecycle | `specs/practices/structural-vocabulary.md` | proposed → adopted → merged/split/retired |
| Anti-patterns | `specs/practices/structural-vocabulary.md` | Structural smells section |
| Retry strategy | `specs/practices/retry.md` | Exponential backoff, jitter, retryable error classification |

## Testing

| Pattern | Notes |
|---|---|
| `cache_control` | Use `travel_to` for time-dependent tests |
| Shared service pattern | Stub external services in unit tests; real calls in integration only |
| SimpleCov | 90% line coverage enforced; guard at top of `spec_helper.rb` |
