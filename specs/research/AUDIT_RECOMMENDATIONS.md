# Unpossible 1 → Unpossible: Audit & Recommendations

> Produced 2026-03-27. Sources audited: `loop.sh`, `PROMPT_*.md`, `dashboard/src/`,
> `practices/general/`, `practices/lang/ruby.md`, `IDEAS.md`, `specs/project-dashboard.md`.
> Reference: `specs/PITCH.md`, `specs/research/RESEARCH.md`, `specs/research/loom/LOOM_ANALYSIS.md`.

---

## Core Principles Alignment Check

RESEARCH.md defines seven principles. Every recommendation below is tested against them.

| Principle | Short form used below |
|---|---|
| Reliability — failures caught, logged, recoverable | **Reliability** |
| Flexibility — components replaceable | **Flexibility** |
| Simplicity — build the simplest thing that works | **Simplicity** |
| Adaptability — system improves from evidence | **Adaptability** |
| Determinism over magic — explicit structure over LLM autonomy | **Determinism** |
| MD files as source of truth — DB is query layer only | **MD-first** |
| Security by default — no secrets or PII to LLMs | **Security** |

---

## What to Keep

### loop.sh — the outer runner

The multi-mode dispatch (`plan`, `build`, `review`, `research`, `promote`), RALPH signal
detection (`RALPH_COMPLETE` / `RALPH_WAITING`), consecutive-failure guard, and branch-per-run
git strategy are all sound. The `AGENT` env var abstraction already supports kiro alongside
claude — this is the **Flexibility** principle in practice.

**Keep verbatim. Add one mode: `reflect`** — maps to the Reflect loop type defined in
RESEARCH.md. The shell stays thin; the Rails app owns state.

### RALPH signal protocol

Simple, grep-able, works across any agent or model. Aligns with **Determinism** — the runner
doesn't need to parse agent output, just scan for a known string. Keep it.

### Practices files

`coding.md`, `planning.md`, `verification.md`, `cost.md`, `prompting.md` encode hard-won
lessons: model selection by task, subagent caps, `study` vs `read`, `Ultrathink`, activity log
hygiene. These are the **Determinism** principle made concrete. Carry them forward unchanged.

Add two new files:
- `practices/general/security.md` — codify the PII/secrets rules from the pitch and the
  Loom `Secret<T>` / `#[instrument(skip(secrets))]` pattern adapted for Ruby
- `practices/general/reflect.md` — Reflect loop protocol once designed

### Go dashboard binary (parser + runner + metrics)

The markdown parsers (`parser/plan.go`, `parser/worklog.go`, `parser/specs.go`) are clean,
tested, and implement **MD-first** correctly — they expose MD files as structured data without
replacing them. The runner mutex (prevent concurrent loop runs) is correct. The Basic Auth on
`/run` is correct (**Security**).

**Keep the Go binary as a sidecar — it does not become part of the Rails app.** Its
responsibilities stay narrow: execute `loop.sh` via `exec.CommandContext`, expose `/healthz`,
`/ready`, `/metrics` (Prometheus), and `/run`. Everything else — UI, API, analytics, task
management — is Rails.

The two services run as separate containers in the same Kubernetes pod (or Docker Compose
services locally). The Go sidecar POSTs agent run records to the Rails API; Rails owns the DB.
This is a clean separation: Go for process execution and ops metrics, Rails for all application
logic. Don't rewrite the runner in Ruby — `exec.CommandContext`, the mutex, and a static binary
are the right tool for this job and would be worse in Ruby.

### Phase-gated infrastructure (planning.md)

The Phase 0→3 ladder (local → CI → staging → production) is a concrete implementation of
**Simplicity**. Keep it as the planning discipline for all unpossible projects.

### Git-per-iteration commit discipline

One commit per passing task, tagged on green, pushed immediately. This is the audit trail the
pitch calls for and the rollback foundation. Keep it.

---

## What to Adapt

### Agent I/O is currently ephemeral

`loop.sh` streams agent output to a temp file and discards it. RESEARCH.md §2 (Agent I/O
Storage) requires storing every interaction: prompt, response, model, tokens, cost, task
reference. This enables resumption, cost analysis, and "don't ask what we already know."

**Adaptation:** The Go runner captures stdout per iteration (already done via `tee`) and POSTs
a structured record to `POST /api/agent_runs` on the Rails app before discarding the temp file.
Parse token counts from Claude's existing `--output-format=stream-json` output — no extra API
call needed. Schema: `run_id`, `iteration`, `mode`, `model`, `prompt_sha256`,
`response_truncated`, `exit_code`, `duration_ms`, `input_tokens`, `output_tokens`,
`cost_estimate`, `task_id`, `timestamp`.

The `prompt_sha256` enables the "don't ask what we already know" check: before running, hash
the assembled prompt and query the DB — if an identical prompt produced a successful result
recently, return the cached output. This is **Determinism** and cost discipline combined.

### Metrics are in-memory only

The Go metrics module resets on restart. The pitch requires persistent analytics covering LLM,
product, server, and development metrics. Loom's analytics architecture (LOOM_ANALYSIS.md §6)
is the reference: separate concerns between operational metrics (Prometheus), product analytics
(event-based, person-linked), and audit logging (compliance, security).

**Adaptation — two complementary layers, not one:**

- **Go sidecar** exports Prometheus-format `/metrics` for operational visibility
  (`runs_total`, `runs_failed_total`, `run_duration_seconds`, `current_runs`). This is
  ephemeral, ops-only, scraped by Prometheus/Grafana. Replace the hand-rolled text exporter
  with `prometheus/client_golang`. The Go sidecar also POSTs a structured record to the Rails
  API after each iteration — it does not write to Postgres directly.
- **Rails `analytics` module** owns all durable analytics in Postgres: per-run agent I/O
  records, token counts, cost estimates, task references. This is the data the Reflect loop
  reads. Rails also owns the audit log (`audit_events` table) as a separate concern from
  application logging (Lograge).

Both containers run in the same Kubernetes pod, sharing a network namespace. The Go sidecar
calls `http://localhost:3000/api/agent_runs` — no external routing needed. Locally, Docker
Compose puts them on the same network. This is the deployment model: **one pod, two
containers, clean interface between them.**

### No task schema — tasks live only in markdown

`IMPLEMENTATION_PLAN.md` is the agent's only memory. RESEARCH.md §2 specifies that the task
record — not the LLM — should determine which tools are in scope, which model to use, and which
prompt template to apply. This is the **Determinism** principle's most important implication.

**Adaptation:** Rails `tasks` module owns the task schema. The plan loop continues to write
`IMPLEMENTATION_PLAN.md` (MD stays source of truth — **MD-first**). A background job (Active
Job) parses it into the DB after each plan loop completes, using the same git-change-detection
pattern proposed for the knowledge base indexer. The build loop reads from MD (unchanged for
now); the UI reads from DB. Task record drives: allowed tool set, LLM provider + model,
prompt template, reviewer LLM.

### No knowledge base / context retrieval

Specs and practices are loaded by filename in every prompt. At scale this is expensive and
imprecise. RESEARCH.md §1 specifies: Postgres + pgvector, paragraph-level chunking,
`text-embedding-3-small`, git-change-detection for re-indexing.

**Adaptation:** Rails `knowledge` module as specified in RESEARCH.md. The plan loop gains a
context-retrieval step: before writing `IMPLEMENTATION_PLAN.md`, query the knowledge base for
relevant prior research, pinned patterns, and related specs. This replaces "load all specs
files" with targeted retrieval — directly reducing per-iteration token cost (**Simplicity**,
cost discipline).

The embedder is a service behind an interface (a Ruby module with a single `embed(text)` method)
so Ollama can replace OpenAI as a config change, not a rewrite (**Flexibility**). This mirrors
Loom's `LlmClient` trait pattern.

### PROMPT_build.md / PROMPT_plan.md are monolithic

They load all practices files unconditionally. As the project grows this burns context budget
and violates **Simplicity**.

**Adaptation:** Keep the prompt files as templates with `{practices}` and `{context}` slots.
The task schema declares which practices files are required for each task type. The plan loop
assembles the prompt dynamically from: task type + knowledge base retrieval + declared practices.
The current prompts become the default templates for build and plan task types.

### No rollback on iteration failure

A failed loop leaves uncommitted changes. The pitch calls for automatic recovery. Loom uses
Spool's `unpick` (jj undo) for per-tool-execution rollback; we can achieve the same with git.

**Adaptation:** Wrap each iteration in a git stash guard in `loop.sh`:
```bash
git stash push -m "ralph-pre-iteration-$ITERATION"
# run agent
# on success: git stash drop
# on failure: git stash pop
```
Log the rollback event to the analytics module. This is a ~10-line addition to `loop.sh`.

### LLM provider is hardcoded to Claude

`loop.sh` supports `AGENT=kiro` but the prompt templates assume Claude's model names and
`--output-format=stream-json`. RESEARCH.md §4 and the pitch both require multi-provider support
with provider-tailored prompts.

**Adaptation:** The task schema stores `provider` and `model` per task type. Prompt templates
are provider-aware — the same task may be asked differently to Claude vs GPT vs a local model.
The Go runner passes `AGENT` and `MODEL` env vars; the Rails app sets them per task. This is
**Flexibility** and **Determinism** together — the system, not the LLM, decides which model runs.

Loom's server-side LLM proxy pattern (LOOM_ANALYSIS.md §7) is the long-term target: API keys
never leave the server, the CLI talks to a proxy endpoint. For unpossible Phase 0 this is
overkill — env vars are fine. Add it as a Phase 3 task.

### IDEAS.md promote flow is manual CLI only

The `./loop.sh promote <id>` command is good but has no API or UI. The pitch calls for a task
management and tracking UI.

**Adaptation:** Expose promote as `POST /api/ideas/:id/promote` in the Rails API. Port the
shell promote logic to a Rails service. The UI gets a promote button. Keep the shell command as
a thin wrapper calling the same endpoint — consistent with the pattern of shell as CLI alias for
the API.

---

## What to Leave Behind

### CLAUDE.md (legacy loop prompt)

Superseded by `PROMPT_build.md`. References `specs/plan.md` directly instead of
`IMPLEMENTATION_PLAN.md`, has no subagent or cost discipline. Do not carry forward.

### Hand-rolled Prometheus text exporter

`metrics/metrics.go` manually formats Prometheus text. It will break on histogram buckets and
label cardinality. Replace with `prometheus/client_golang`.

### Single-project assumption in dashboard

The dashboard hardcodes `WORKSPACE_DIR` as the project root. The pitch and RESEARCH.md both
require multi-project support. The Rails app must be multi-project aware from day one — the
RESEARCH.md schema already includes `org_id`/`tenant_id` for this reason.

### Unconditional full-spec loading in prompts

Loading every file in `specs/` every iteration is the current approach. Once the knowledge base
exists, this is replaced by targeted retrieval. Don't carry the unconditional load pattern into
unpossible's prompt templates.

---

## Loom Patterns Worth Adopting

These come from LOOM_ANALYSIS.md and align directly with RESEARCH.md goals.

**Secret type wrapper.** Loom's `Secret<T>` auto-redacts in Debug/Display/Serialize/tracing.
In Rails: a `Secret` value object that overrides `inspect` and `to_s` to return `[REDACTED]`.
Never pass raw API keys to LLMs or log them. This is **Security** made structural.

**Specs README as lookup table.** Loom's `specs/README.md` maps each spec to its implementing
code. Adopt this for unpossible: a `specs/README.md` table mapping each spec file to the Rails
module and the loop type that implements it. Keeps the agent oriented without loading every spec.

**Core/implementation split.** Loom separates `loom-analytics-core` (types) from
`loom-analytics` (SDK) from `loom-server-analytics` (HTTP + storage). In Rails modules: define
types and interfaces in `app/modules/{name}/` with a clear public service interface. Cross-module
calls go through the service interface only — no direct model access across module boundaries.
This is the **Flexibility** principle made structural.

**Audit log as a separate concern from application logging.** Loom separates `tracing` (ops
logging) from the audit system (compliance/security). In unpossible: Rails structured logging
(Lograge) for ops; a dedicated `audit_events` table for security-relevant actions (who ran what
loop, what was promoted, what was deleted). Never mix them.

**Feature flags for hypothesis testing.** The pitch calls for testing hypotheses through feature
flags and analytics. Loom's flag system (per-environment, kill switches, exposure tracking) is
the reference. For unpossible Phase 0: a simple `feature_flags` table with key/enabled/variant
columns is sufficient. Design the schema so the Loom-style evaluation engine can be added later
without a migration (**Simplicity** now, **Adaptability** later).

---

## Disposition Summary

| Unpossible 1 feature | Disposition | Notes |
|---|---|---|
| `loop.sh` multi-mode runner | Keep, add `reflect` mode | Shell stays thin |
| RALPH signal protocol | Keep | Language-agnostic, grep-able |
| Practices files | Keep, add `security.md` + `reflect.md` | High value, low token cost |
| Go dashboard binary | Keep as runner/sidecar (separate container, same pod) | Rails owns all app logic + UI + API |
| Markdown as source of truth | Keep | DB is query layer on top |
| Phase-gated infra | Keep | Maps to Simplicity principle |
| Basic Auth on `/run` | Keep | Extend to JWT for Rails API |
| Git-per-iteration commits | Keep | Audit trail + rollback foundation |
| In-memory metrics | Adapt | Persist to Postgres; replace hand-rolled exporter |
| Ephemeral agent I/O | Adapt | Store per-run records; enable prompt dedup |
| Monolithic prompts | Adapt | Task-schema-driven dynamic assembly |
| Single LLM provider | Adapt | Provider + model driven by task schema |
| Manual promote flow | Adapt | Rails API + UI; shell as CLI alias |
| No rollback | Adapt | Git stash guard in loop.sh (~10 lines) |
| CLAUDE.md | Drop | Superseded by PROMPT_build.md |
| Hand-rolled Prometheus exporter | Drop | Use prometheus/client_golang |
| Single-project dashboard | Drop | Multi-project from day one |
| Unconditional full-spec loading | Drop | Replace with knowledge base retrieval |
