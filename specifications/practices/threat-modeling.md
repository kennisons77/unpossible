---
name: threat-modeling
kind: practice
domain: Threat modeling
description: STRIDE analysis at trust boundaries before implementation
loaded_by: [build]
---

# Threat Modeling Practices

Retrieved on demand when a task touches a trust boundary.

## When to Apply

Every feature that crosses a trust boundary needs threat analysis before implementation.
Trust boundaries: user input, network edges, storage, auth decisions, external APIs,
inter-service communication. If a task touches none of these, skip threat analysis for it.

## Threats by Phase

Analyze only threats relevant to the current phase (see `planning.md` § Development Phases).

| Phase | Threat Surface | Key Concerns |
|---|---|---|
| 0 Local | App boundary | Input validation, injection, data integrity, error leakage, race conditions |
| 1 CI | Build pipeline | Dependency supply chain, secrets in CI config, image provenance |
| 2 Staging | Network | Transport security, auth/authz, API abuse, CORS, session handling |
| 3 Production | Full stack | Secrets rotation, rate limiting, audit trails, monitoring for anomalies |

Do not plan mitigations for Phase N+1 threats — they belong in a future planning pass.

## STRIDE Checklist

For each task that touches a trust boundary, run through STRIDE to surface edge cases
that functional specs miss:

- **Spoofing** — Can an actor impersonate another? (auth, tokens, headers)
- **Tampering** — Can data be modified in transit or at rest? (signatures, checksums, input mutation)
- **Repudiation** — Can actions be denied without evidence? (audit logs, timestamps)
- **Information Disclosure** — Can sensitive data leak? (error messages, logs, responses, timing)
- **Denial of Service** — Can the feature be abused to exhaust resources? (unbounded input, missing limits)
- **Elevation of Privilege** — Can a lower-privilege actor gain higher access? (authz checks, role boundaries)

Skip categories that don't apply — don't force-fit.

## Edge Case Discovery Prompts

When the agent encounters a feature at a trust boundary, use targeted prompts to surface
domain-specific edge cases before writing the implementation plan:

> I am building [feature] for a high-scale Rails app. Generate a list of three potential
> edge cases involving data integrity or race conditions for this specific domain.

Adapt the prompt to the threat category:

| Threat category | Prompt variant |
|---|---|
| Data integrity / races | "…edge cases involving data integrity or race conditions…" |
| Input boundary | "…edge cases involving malformed, oversized, or adversarial input…" |
| Auth/authz | "…edge cases where authorization checks could be bypassed or confused…" |
| Resource exhaustion | "…edge cases where unbounded input or repeated requests exhaust resources…" |

Record discovered edge cases as threat tests in the task definition. They are required
tests — they must pass before the task is marked complete.

## Threat-Driven Task Definition

When writing tasks in `IMPLEMENTATION_PLAN.md`, append threat-informed test scenarios
after the functional required tests:

```
- [ ] Accept file upload (app/upload.py)
  Required tests: accepts valid PNG, rejects >10MB, returns URL on success
  Threat tests: rejects path traversal in filename (Tampering), returns generic error not stack trace (Info Disclosure), rate-limits per user (DoS)
```

## Test Scenario Selection

When a task touches a trust boundary, required tests must include:

- **Input handling** — injection (SQL, command, path traversal), boundary values, malformed encoding
- **Output handling** — no sensitive data in error responses, no internal state leakage in logs
- **Resource limits** — bounded allocations, timeouts, max sizes
- **Auth context** — correct principal, correct permissions, no confused-deputy paths
- **Concurrency** — race conditions on shared state, double-submit, stale reads

These supplement, not replace, the functional tests derived from acceptance criteria.
