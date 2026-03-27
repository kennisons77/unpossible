# Go Runner Sidecar

## What It Does

Executes `loop.sh` on instruction from Rails. That's it. It is a process executor, not an agent manager.

## Responsibilities

- Receive `POST /run` from Rails with prompt and config
- Execute `loop.sh` via `exec.CommandContext` with the given mode and arguments
- Prevent concurrent runs (mutex — one loop at a time)
- Parse token counts from Claude's `--output-format=stream-json` stdout
- Call `POST /api/agent_runs/:id/complete` on Rails with results when done
- Expose `/healthz`, `/ready`, `/metrics` (Prometheus), `/run` (Basic Auth)

## What It Does NOT Own

Everything else is Rails:
- Deciding what to run and when — Rails
- Prompt assembly — Rails
- Deduplication checks — Rails
- Agent run records — Rails / Postgres
- Task management — Rails
- Authentication beyond Basic Auth on `/run` — Rails

## Deployment

Separate container in the same Kubernetes pod as Rails (or Docker Compose service locally). Shares network namespace — receives calls from Rails at `localhost:{sidecar_port}`, calls back to Rails at `localhost:3000`.

## Prometheus Metrics

Uses `prometheus/client_golang`:
- `runs_total` (counter)
- `runs_failed_total` (counter)
- `run_duration_seconds` (histogram)
- `current_runs` (gauge)

## Acceptance Criteria

- `POST /run` without valid Basic Auth returns 401
- Concurrent `POST /run` while a run is active returns 409
- After loop exits, calls `POST /api/agent_runs/:id/complete` with `{exit_code, duration_ms, input_tokens, output_tokens, response_truncated}`
- Token counts parsed from stream-json stdout
- `/healthz` returns 200
- `/metrics` returns valid Prometheus text
- `go test ./...` passes
