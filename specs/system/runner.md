# Runner Sidecar

## What It Does

Executes the agent loop on instruction from the application server. It is a process executor, not an agent manager — all decisions about what to run, when, and with what context belong to the application server.

## Responsibilities

- Receive a run instruction with prompt and config
- Execute `loop.sh` with the given mode and arguments
- Prevent concurrent runs — one loop at a time
- Parse token counts from agent stdout
- Report results back to the application server when the loop exits
- Expose health, readiness, and metrics endpoints

## What It Does NOT Own

- Deciding what to run and when — application server
- Prompt assembly — application server
- Deduplication checks — application server
- Agent run records — application server
- Task management — application server

## Deployment

Separate process in the same network namespace as the application server. Receives calls from the app at localhost, calls back to the app at localhost.

## Observability

Exposes Prometheus-compatible metrics:
- Run counter (total, failed)
- Run duration histogram
- Current active runs gauge

## Acceptance Criteria

- Unauthenticated run request → 401
- Concurrent run request while a run is active → 409
- After loop exits, reports `{exit_code, duration_ms, input_tokens, output_tokens, response_truncated}` to application server
- `/healthz` returns 200
- `/metrics` returns valid Prometheus text
