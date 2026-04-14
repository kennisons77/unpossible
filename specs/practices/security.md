# Security & PII

## Principles

1. **Minimum attack surface** — expose nothing that doesn't need to be exposed.
2. **Secrets never travel** — API keys, tokens, and passwords never appear in logs, LLM prompts, error messages, or HTTP responses. Structurally impossible, not just policy.
3. **PII is masked before it leaves the process** — scrubbed before sent to an LLM, written to a log, or stored in analytics.
4. **Defence in depth** — multiple independent layers. If one layer fails, the next catches it.

## Secret Value Object

Every credential in the system is wrapped in a `Secret` value object:
- Redacts itself in all serialization paths (`inspect`, `to_s`, `as_json` → `"[REDACTED]"`)
- `.expose` is the only way to access the raw value — explicit and intentional
- Makes it structurally impossible to accidentally log a credential

## Secrets Never in Prompts

Before any content is sent to an LLM provider, it passes through a prompt sanitizer that applies gitleaks patterns plus PII patterns. If a match is found, the content is redacted and a warning is logged. The sanitizer is called by every provider adapter — it cannot be bypassed.

## PII

What counts as PII: names, email addresses, phone numbers, IP addresses (in logs/analytics), user IDs that map to real people.

- `distinct_id` in analytics is always an opaque UUID — never an email or name
- User-submitted free text must pass through the prompt sanitizer before inclusion in any prompt
- `AgentRun` stores `prompt_sha256` not raw prompt text
- `AgentRun` stores token counts not response content

## Environment Variables

- All secrets via `ENV.fetch('KEY')` — fails fast at startup if missing
- `.env` files are gitignored — committed `.env` is a build failure
- Secrets in environment config, never baked into image layers

### File-Based Secrets (Phase 2+)

When deploying to staging or production, prefer file-based secret loading over
environment variables. The `*_FILE` convention (used by Docker Secrets, Kubernetes
Secrets, Vault Agent):

- If `SECRET_KEY_FILE` is set → read the secret from that file path
- If `SECRET_KEY` is set → use the value directly
- `*_FILE` takes precedence when both are set

This avoids secrets appearing in `docker inspect`, process listings, or CI logs.
Not needed in Phase 0 (local dev), but design secret loading to support it from
the start — a single helper that checks `_FILE` first, then the direct env var.

## Incident Response

If a secret is suspected to have been logged or transmitted:
1. Rotate the secret immediately — do not wait to confirm
2. Check audit log for requests made with the compromised credential
3. Check AgentRun records for the time window
4. File an audit event with `severity: critical`
5. Add the pattern to the log redactor if it wasn't already caught

## Audit Logging and Error Propagation

Audit logging is observation, not error handling. The rule "don't log *and* return
an error" applies to application error paths — where logging the error and also
returning it creates duplicate noise and unclear ownership.

Audit sinks are a separate channel. An audit event records *that something happened*
for compliance and forensics. The error path records *that something failed* for the
caller to handle. Both can fire for the same operation without violating the rule:

- Error path: gateway returns a result branch with the failure → caller handles it
- Audit path: audit sink records the event asynchronously → no caller involvement

The audit sink must be non-blocking and fail-open. A slow or unavailable audit store
must never block the application. If the audit write fails, log a warning and continue
— the application's job is more important than the audit record.
