# Practices

## What This Spec Covers

The practices files loaded by ralph loops. Each file is a standing set of rules the agent applies without being asked. They are the **Determinism** principle made concrete — the system controls how code is written, not the LLM's defaults.

Practices files live in `practices/` and are loaded selectively per loop iteration based on the task type. Not every file is loaded every iteration — that wastes context budget.

## File Map

| File | Loaded when |
|---|---|
| `practices/general/coding.md` | Every build iteration |
| `practices/general/planning.md` | Every plan iteration |
| `practices/general/verification.md` | Before running tests |
| `practices/general/cost.md` | Every iteration (model selection, subagent caps) |
| `practices/general/prompting.md` | When editing PROMPT_*.md files |
| `practices/general/security.md` | Every build iteration |
| `practices/general/reflect.md` | Every reflect iteration |
| `practices/lang/ruby.md` | When language is Ruby |
| `practices/lang/go.md` | When language is Go |
| `practices/framework/rails.md` | When framework is Rails |

---

## practices/general/coding.md

Carry forward from unpossible1 unchanged. Rules: explain why not what in comments, self-documenting names, single responsibility functions, one concept per file, explicit error handling, no dead code, prefer stdlib, no magic numbers, fail fast at boundaries.

---

## practices/general/planning.md

Carry forward from unpossible1 unchanged. Rules: activity-not-capability spec granularity, SLC release scoping, acceptance-driven task definition, gap analysis discipline, phase-gated infrastructure, IMPLEMENTATION_PLAN.md hygiene.

---

## practices/general/verification.md

Carry forward from unpossible1 unchanged. Rules: backpressure as the control mechanism, LLM-as-judge for subjective criteria, rebuild Docker image when deps change, test behavior not implementation, fix root causes not symptoms.

---

## practices/general/cost.md

Carry forward from unpossible1 unchanged. Note: in unpossible2, prompt caching and effort parameters are applied automatically by the provider adapter (`Agents::ProviderAdapter`) — prompt authors do not need to add `cache_control` annotations manually. The cost practices file remains relevant for understanding *why* the adapter makes the choices it does, and for cases where prompts are assembled outside the adapter (e.g. one-off research queries).

---

## practices/general/prompting.md

Carry forward from unpossible1 unchanged. Load-bearing word choices: `study` vs `read`, `don't assume not implemented`, `Ultrathink`, `capture the why`, subagent ceiling patterns. Prompt tuning discipline: one targeted line per repeatable failure, never rewrite the whole prompt.

---

## practices/general/security.md

New file. Derived from the pitch, RESEARCH.md, and Loom's `loom-secret` / `loom-redact` patterns adapted for Ruby.

### Secret Value Object
- All API keys, tokens, and passwords are wrapped in `Secret` — never raw strings
- `Secret#inspect` and `Secret#to_s` return `"[REDACTED]"` — accidental logging is structurally impossible
- `Secret#expose` is the only way to access the raw value — explicit and grep-able
- Never pass a `Secret` to an LLM prompt — call `.expose` only at the system boundary that needs it, and only if the LLM genuinely requires it (it almost never does)

### Logging
- `filter_parameters` includes `:api_key`, `:token`, `:password`, `:secret`, `:authorization`
- Lograge structured logging — never `puts` or `p` in production code
- Audit log entries: filter metadata through Secret redaction before storage
- Never log request bodies that may contain credentials

### Input Handling
- Validate and sanitize at the boundary — trust nothing from outside the process
- Shell commands: always pass as argument arrays, never interpolate user input into a shell string
- SQL: always use parameterized queries — never string interpolation in ActiveRecord conditions

### Secrets in Infrastructure
- Secrets via ENV vars only — never committed to source
- `ENV.fetch('KEY')` not `ENV['KEY']` — fail fast on missing secrets at startup
- Docker Compose: secrets via environment block, never baked into image layers
- `.env` files in `.gitignore` — always

### Access Control
- `rack-attack` on any app with public endpoints — rate limiting from day one
- `brakeman` on every build — high-severity findings are blockers
- Unauthenticated endpoints are the exception, not the default — require explicit opt-out

---

## practices/general/reflect.md

New file. Protocol for the Reflect loop.

### What Reflect Does
Reads accumulated AgentRun records, identifies patterns in costs/errors/review feedback, and proposes one concrete improvement. The proposal goes through plan/build/review before being applied — the system never self-modifies without backpressure.

### Reflect Targets
1. **How the system runs** — prompt templates, tool selection rules, cost efficiency, task schema
2. **What the system produces** — patterns in what works, fed back into future planning

### Rules
- One proposal per reflect iteration — not a list
- Every proposal must state: (a) what will improve and (b) which metric will verify it
- No change for change's sake — if there is no measurable hypothesis, do not propose
- Reflect output is a proposed change to `practices/`, `PROMPT_*.md`, or config — not to application code (that goes through a normal build loop)
- If reflect finds a pattern worth preserving immediately (a gotcha, a hard-won lesson), append it to the relevant practices file directly — this is the one exception to the "propose, don't apply" rule

---

## practices/lang/ruby.md

Carry forward from unpossible1. Add the following from Loom analysis:

### Shared Service Pattern (from Loom AGENTS.md)
When multiple code paths do similar things with slight variations, create a shared service with a request struct (plain Ruby object) that captures the variations. Do not have each caller implement its own logic. This is the Rails equivalent of Loom's shared service pattern.

```ruby
# Instead of three callers each building their own embed call:
result = Knowledge::EmbedderService.call(
  Knowledge::EmbedRequest.new(text: chunk, model: :small, org_id: org_id)
)
```

### Module Boundaries
- Cross-module calls go through the module's public service interface only
- No direct ActiveRecord queries across module boundaries — call the owning module's service
- Each module's public interface lives in `app/modules/{name}/services/{name}_service.rb`

---

## practices/lang/go.md

Carry forward from unpossible1. Add the following from Loom analysis:

### HTTP Clients
Never construct an HTTP client directly in a handler or service. Use a shared client constructor that sets consistent User-Agent, timeouts, and retry logic. Pass it as a dependency.

### Instrumentation
Wrap significant functions with structured logging context. Log entry and exit for long-running operations. Never log secrets — pass them as typed wrappers that redact on format.

### Sidecar Discipline
The Go runner is a sidecar — it does not own business logic. If a decision requires understanding the application domain, it belongs in Rails. The Go binary's job is: execute a process, report what happened, expose metrics.

---

## practices/framework/rails.md

Carry forward from unpossible1. Add the following from Loom analysis:

### Specs as Source of Truth (from Loom AGENTS.md)
Before implementing any feature, read the relevant spec. Assume NOT implemented — many specs describe planned features. Check the codebase first before concluding something is or isn't there. Specs describe intent; code describes reality.

### Route Authorization
Every route is either explicitly public or explicitly authenticated — no implicit defaults. When adding a route, decide at the same time: public or authed. Update auth tests when routes change. This mirrors Loom's `PublicRouter` / `AuthedRouter` pattern.

### Audit on Destructive Actions
Any action that deletes, promotes, or modifies security-relevant state must call `Analytics::AuditLogger.log(...)`. This is not optional. Add it at the same time as the action, not later.

### Migration Discipline (from Loom AGENTS.md)
- All migrations in `db/migrate/` — never inline SQL elsewhere
- No data changes in migrations — use seeds or Rake tasks
- After adding a migration, verify it runs cleanly in the Docker test container before committing
- Reversible by default — use `change`, not `up`/`down`, unless the operation is genuinely irreversible

### Lookup Table Maintenance
When adding a new class, module, or spec, update the relevant lookup table in the same commit. See `specs/lookup-tables.md`. A thing that isn't in a lookup table effectively doesn't exist to the agent.

---

## Acceptance Criteria

- All practices files listed in the file map exist
- `practices/general/security.md` references the `Secret` class and `filter_parameters`
- `practices/general/reflect.md` contains the one-proposal-per-iteration rule and the measurable hypothesis requirement
- `practices/lang/ruby.md` contains the module boundary rule
- `practices/framework/rails.md` contains the route authorization rule and audit-on-destructive-actions rule
