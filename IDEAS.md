# IDEAS.md — unpossible

Parking lot for ideas not yet ready for implementation. See `specs/features/idea-parking-lot.md` for schema.

---

## [1] Project Dashboard

- **Status:** promoted
- **Created:** 2026-03-25T01:17:30Z
- **Promoted:** 2026-03-25T03:48:06Z

### Description

A local web UI and API that parses unpossible's generated markdown (IMPLEMENTATION_PLAN.md, WORKLOG.md, specs/) and exposes project data as browsable collections: goals, UAT/acceptance criteria, and work done. No external services — all data comes from files already on disk. Frontend style similar to GeneAIe. Human-queryable only at first.

**Language decision: Go.** Produces small static binaries, fast startup, strong stdlib for HTTP and exec. Build with `CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags '-s -w'`. Multi-stage Docker image with binary + loop.sh present or mounted.

**Architecture:**
- `cmd/server/main.go` — HTTP server, Prometheus metrics, structured JSON logging, worker that runs `./loop.sh` via `exec.CommandContext`, mutex/lock-file to prevent concurrent runs
- Endpoints: `/healthz`, `/ready`, `/metrics` (Prometheus), `/run` (POST, optional), `/status` (optional)
- Metrics: `runs_total`, `runs_failed_total`, `run_duration_seconds`, `current_runs`, `last_run_success_timestamp`
- Logging: structured JSON to stdout — fields: `run_id`, `iteration`, `command`, `exit_code`, `duration`, `error`
- Config via env vars: path to `loop.sh`, sandbox flags, max concurrency, timeouts, working directory override
- Security: invoke shell scripts via direct `exec` with argument list — no shell interpolation of user input; run with least privileges; containerized for LLM tool calls

### Open Questions

~~- Should the API be read-only or also allow status updates (e.g. marking tasks done via UI)?~~
**Resolved:** Read-only for now; status updates deferred to a later enhancement.

~~- How does the UI handle multiple projects under `projects/`?~~
**Resolved:** Single-project view only for now; multi-project navigation deferred.

~~- Does `/run` need auth (even a simple shared secret) given it executes shell scripts?~~
**Resolved:** Yes — `/run` protected by HTTP Basic Auth; credentials via env vars.

---

## [2] Metrics System

- **Status:** parked
- **Created:** 2026-03-25T01:17:30Z
- **Promoted:**

### Description

Local-first, Prometheus-shaped metrics instrumentation. unpossible itself is the proving ground. Tracks: loop iteration count, LLM call count, estimated token spend, context window size per iteration, lines changed per commit. Once the pattern is proven, `new-project.sh` scaffolds the same instrumentation into new projects automatically — covering app-level metrics (query latency, business logic counters) and system metrics (CPU, memory). Error tracking is a stretch goal.

### Open Questions

- Flat file (append-only JSONL) vs local Prometheus + Grafana vs embedded SQLite?
- How does the agent estimate token spend without direct API access (parse stream-json output)?
- At what project maturity does the agent add metrics scaffolding — on first build or when the project reaches interactivity?
- Error tracking scope: just log to file, or integrate with a local error aggregator?

---

## [3] Improvement Mode

- **Status:** parked
- **Created:** 2026-03-25T01:17:30Z
- **Promoted:**

### Description

A `./loop.sh improve` mode where the agent reviews unpossible's own prompts and practices files, identifies weaknesses, and proposes changes as a PR — same flow as project builds. Every proposed change must include: (a) an improvement hypothesis stating what will get better and by how much, and (b) a metric from the metrics system that will verify the outcome. No change for change's sake. The mode can also research ways to reduce LLM calls entirely — e.g. caching, context compression, or pre-computed context stores.

### Open Questions

- How does the agent measure "before" state if metrics aren't yet instrumented? Does improvement mode bootstrap metrics first?
- What's the PR target — a branch on the same repo, or a separate review artifact?
- Should the agent be allowed to modify PROMPT_build.md / PROMPT_plan.md directly, or only propose diffs for human approval?
- Scope of self-improvement: prompts and practices only, or also loop.sh shell logic?

---

## [5] Failure Analysis & Prompt Learning

- **Status:** parked
- **Created:** 2026-03-25T01:33:00Z
- **Promoted:**

### Description

When a bug surfaces in production or a test failure/deficiency is identified, the system traces it back to the planning or build phase that introduced it and uses that signal to improve unpossible's own markdown files (prompts, practices, rules). First step is structured LLM interaction logging: capture the prompt sent, agent + model used, and response (truncated at a reasonable size). Logs are linked to the git commit produced in that iteration where possible. Post-mortem mode then correlates a reported failure to a logged interaction, identifies which prompt or practice was weak, and proposes a targeted refinement as a PR — same hypothesis-plus-metric requirement as improvement mode.

### Open Questions

- What's the truncation threshold for response logging — first N tokens, or a structured summary?
- Storage: append to the metrics JSONL, a separate `LLM_LOG.jsonl`, or structured entries in WORKLOG.md?
- How does the agent correlate a production bug to a specific logged interaction — by commit SHA, by task ID, or manual triage?
- Should log entries be written by loop.sh (wrapping the agent call) or by the agent itself at end of iteration?
- Git/PR linkage: is commit SHA in the log entry sufficient for v1, or do we need branch/PR metadata?

---

## [4] External Benchmarking

- **Status:** parked
- **Created:** 2026-03-25T01:17:30Z
- **Promoted:**

### Description

An extension of improvement mode that ingests external sources — OSS agentic frameworks (Devon, SWE-agent, OpenHands, etc.) and published best-practice articles — and compares their approaches to unpossible's model. The agent surfaces only changes that (a) fit unpossible's constraints (local-first, shell-based, markdown-driven) and (b) have a verifiable improvement hypothesis. Findings are written to a BENCHMARKS.md doc; promoted ideas flow into IDEAS.md for normal research/promote lifecycle. Principle: no change for change's sake.

### Open Questions

- How does the agent fetch external repos/articles — clone locally, use a search tool, or rely on training knowledge?
- What's the comparison rubric (iteration count, cost per task, test pass rate)?
- How do we prevent benchmark findings from inflating IDEAS.md with noise — curator review step?
