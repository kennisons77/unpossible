# Security & PII

## Principles

1. **Minimum attack surface** — expose nothing that doesn't need to be exposed. Every public endpoint, open port, and readable file is a potential attack vector.
2. **Secrets never travel** — API keys, tokens, and passwords never appear in logs, LLM prompts, error messages, or HTTP responses. Structurally impossible, not just policy.
3. **PII is masked before it leaves the process** — any user-identifiable data is scrubbed before being sent to an LLM, written to a log, or stored in an analytics record.
4. **Defence in depth** — multiple independent layers. If one layer fails, the next catches it.

---

## Secrets

### Secret value object

Every API key, token, password, and credential in the system is wrapped in `Secret`:

```ruby
class Secret
  def initialize(value) = @value = value
  def expose = @value                        # explicit, grep-able
  def inspect = "[REDACTED]"
  def to_s    = "[REDACTED]"
  def as_json(*) = "[REDACTED]"
end
```

`Secret` is the first line of defence. Accidental logging, serialisation, or interpolation into a string produces `[REDACTED]` — not the raw value. `.expose` is the only way out and is intentionally verbose so it shows up in code review.

### Rails filter_parameters

Second line of defence — catches anything that bypassed `Secret`:

```ruby
config.filter_parameters += [
  :api_key, :token, :password, :secret, :authorization,
  :access_token, :refresh_token, :private_key, :credential
]
```

Lograge inherits this list. Any parameter matching these keys is replaced with `[FILTERED]` in request logs.

### Pattern-based log scanning (gitleaks)

Third line of defence — scans log output for patterns that look like secrets regardless of parameter name. Adapted from Loom's `loom-redact` crate (which uses gitleaks patterns).

In unpossible2: a `Security::LogRedactor` middleware wraps the Lograge output stream. It applies a set of regex patterns (API key formats, JWT patterns, private key headers) and replaces matches with `[REDACTED:<type>]` before the log line is written.

Patterns to detect:
- Generic high-entropy strings (>20 chars, mixed case + digits + symbols)
- `sk-...` (OpenAI), `claude-...` keys, `Bearer ...` tokens
- PEM headers (`-----BEGIN ... KEY-----`)
- AWS key patterns (`AKIA...`)
- JWT format (`eyJ...`)

This is a safety net, not the primary mechanism. If `Security::LogRedactor` is catching something, it means `Secret` or `filter_parameters` missed it — treat it as a bug to fix upstream.

### Environment variables

- All secrets via `ENV.fetch('KEY')` — fails fast at startup if missing, never silently nil
- `.env` files are gitignored always — committed `.env` is a build failure
- Docker Compose: secrets in `environment:` block, never baked into image layers
- No secrets in `database.yml`, `credentials.yml.enc` is acceptable for Rails master key pattern but the master key itself is never committed

### LLM prompt boundary

Before any content is sent to an LLM provider, it passes through `Security::PromptSanitizer`:

```ruby
Security::PromptSanitizer.sanitize(text)
```

This applies the same gitleaks patterns as `LogRedactor` plus PII patterns (see below). If a match is found, the content is redacted and the sanitizer logs a warning to the audit log — something upstream assembled a prompt with sensitive data in it.

The sanitizer is called by the provider adapter (`Agents::ProviderAdapter`) before `build_prompt` sends anything to the LLM. It is not optional and cannot be bypassed.

---

## PII

### What counts as PII

For unpossible2's purposes:
- Names, email addresses, phone numbers
- IP addresses (in logs and analytics)
- User IDs that map to real people (use opaque `org_id`/`user_id` UUIDs, never email as identifier)
- Free-text content submitted by users that may contain any of the above

### PII never goes to LLMs

The system does not send user-generated free text to LLMs without explicit sanitisation. Specs, practices files, and research docs are system-authored — they are safe. User-submitted content (task descriptions, notes, comments) must pass through `Security::PromptSanitizer` before inclusion in any prompt.

### PII in logs

Lograge `filter_parameters` covers structured fields. For free-text log messages, `Security::LogRedactor` applies PII patterns:

- Email addresses → `[EMAIL]`
- Phone numbers (E.164 and common formats) → `[PHONE]`
- IP addresses → `[IP]` (in analytics/audit records, not in operational logs where IPs are needed for debugging)

### PII in analytics

The analytics module stores `actor_id` and `user_id` as opaque UUIDs — never email addresses or names. If a user's identity needs to be resolved for support purposes, that lookup happens in the Rails app against the users table, not in the analytics records themselves.

`AuditEvent.metadata` is filtered through `Secret` redaction before storage (already specified in `analytics.md`). It is also filtered through `Security::PromptSanitizer` patterns for PII before storage.

### PII in agent I/O records

`AgentRun.response_truncated` stores a boolean, not the response content. Full response content is not stored — only token counts, cost, and exit code. If a response needs to be inspected for debugging, it is read from the agent's stdout at the time of the run, not retrieved from the DB later.

Prompt content is stored only as `prompt_sha256` (a hash) — not the raw prompt text. This enables deduplication without storing potentially sensitive prompt content.

---

## Attack Surface

### Exposed ports

| Port | Service | Exposed to |
|---|---|---|
| 3000 | Rails | Internal network only (behind reverse proxy) |
| 8080 | Go sidecar metrics/run | Internal network only |
| 5432 | Postgres | Internal network only — never public |
| 6379 | Redis | Internal network only — never public |

In production: only the reverse proxy port (443) is public. Everything else is cluster-internal.

### API surface

- Every endpoint is either explicitly public or explicitly authenticated — no implicit defaults (see `server-operations.md` and `auth.md`)
- `POST /run` (Go sidecar) is Basic Auth protected — not public
- `POST /api/agent_runs` (sidecar → Rails) is shared-secret protected — not public
- Rate limiting via `rack-attack` on all public endpoints from day one

### Dependency surface

- Pin all gem versions in `Gemfile.lock` — committed, never `.gitignore`d
- Run `brakeman` on every build — high-severity findings block the build
- Run `bundler-audit` on every build — known CVEs in dependencies block the build
- No gem added without checking maintenance status and last release date

### Container surface

- Containers run as non-root user
- No `--privileged` flag
- Read-only root filesystem where possible
- No unnecessary capabilities

### Agent tool surface

Kiro agent configs define explicit tool allowlists per loop type (see `agents.md`). The agent cannot use tools outside its allowlist — this limits what a compromised or misbehaving agent can do.

---

## Incident Response

If a secret is suspected to have been logged or transmitted:

1. Rotate the secret immediately — do not wait to confirm
2. Check audit log for any requests made with the compromised credential
3. Check `AgentRun` records for the time window — was it included in a prompt?
4. File an `AuditEvent` with `severity: :critical` documenting the incident
5. Add the pattern that allowed the leak to `Security::LogRedactor` if it wasn't already caught

---

## Acceptance Criteria

- `Secret#inspect`, `#to_s`, `#as_json` all return `"[REDACTED]"` — never the raw value
- `filter_parameters` includes all credential-related keys
- `Security::LogRedactor` strips JWT, OpenAI key, and PEM patterns from log output
- `Security::PromptSanitizer.sanitize` redacts secrets and PII patterns before LLM submission
- `PromptSanitizer` is called by every provider adapter — cannot be bypassed
- `AgentRun` stores `prompt_sha256` not raw prompt text
- `AgentRun` stores token counts not response content
- `AuditEvent` metadata is filtered through `Secret` redaction and PII patterns before storage
- Postgres, Redis ports are not exposed outside the internal network
- `brakeman` and `bundler-audit` run on every build and block on findings
- `.env` committed to git is a CI failure
