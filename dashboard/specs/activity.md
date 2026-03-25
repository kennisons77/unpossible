# Activity Log — dashboard

## 2026-03-25T16:59:00-05:00 — Scaffold Go module and health endpoints

**Task:** Scaffold Go module with cmd/server/main.go and implement /healthz and /ready endpoints

**Changes:**
- Created `src/go.mod` with Go 1.22 module
- Created `src/cmd/server/main.go` with HTTP server and health endpoints
- Created `src/cmd/server/main_test.go` with tests for both endpoints
- Fixed docker-compose.yml dockerfile paths (context mismatch)
- Fixed Dockerfile COPY path to match context
- Created AGENTS.md with build/run/test commands

**Tests:** All pass (go test ./...)

**Commit:** Scaffold Go module with health endpoints

## 2026-03-25T17:01:00-05:00 — Parse IMPLEMENTATION_PLAN.md and expose via API

**Task:** Parse IMPLEMENTATION_PLAN.md → GET /api/plan (JSON: tasks with done/pending status)

**Changes:**
- Created `src/parser/plan.go` with ParseImplementationPlan function
- Created `src/parser/plan_test.go` with table-driven tests
- Updated `src/cmd/server/main.go` to add /api/plan endpoint
- Added test for /api/plan endpoint in main_test.go
- Reads WORKSPACE_DIR from env (defaults to /workspace)

**Tests:** All pass (go test ./...)

**Commit:** Add /api/plan endpoint with IMPLEMENTATION_PLAN.md parser

## 2026-03-25T17:02:00-05:00 — Parse WORKLOG.md and expose via API

**Task:** Parse WORKLOG.md → GET /api/worklog (JSON: entries)

**Changes:**
- Created `src/parser/worklog.go` with ParseWorklog function
- Parses markdown headers with timestamp — title format
- Extracts multi-line descriptions
- Created `src/parser/worklog_test.go` with table-driven tests
- Updated `src/cmd/server/main.go` to add /api/worklog endpoint
- Added test for /api/worklog endpoint in main_test.go

**Tests:** All pass (go test ./...)

**Commit:** Add /api/worklog endpoint with WORKLOG.md parser

## 2026-03-25T17:03:00-05:00 — List and serve specs via API

**Task:** List and serve specs/*.md → GET /api/specs, GET /api/specs/{name}

**Changes:**
- Created `src/parser/specs.go` with ListSpecs and ReadSpec functions
- ListSpecs walks specs directory and returns all .md files
- ReadSpec reads individual spec with path traversal protection
- Created `src/parser/specs_test.go` with tests including security checks
- Updated `src/cmd/server/main.go` to add /api/specs and /api/specs/{name} endpoints
- Added tests for both endpoints in main_test.go

**Tests:** All pass (go test ./...)

**Commit:** Add /api/specs endpoints with specs directory parser

## 2026-03-25T17:05:00-05:00 — Serve static HTML frontend

**Task:** Serve static HTML frontend (embedded via embed.FS) showing plan + worklog

**Changes:**
- Created `src/web/index.html` with minimal UI
- Fetches /api/plan and /api/worklog via JavaScript
- Displays tasks with done/pending status and visual indicators
- Displays worklog entries with timestamps
- Created `src/web/embed.go` package to embed static files
- Updated `src/cmd/server/main.go` to serve embedded files at root path

**Tests:** All pass (go test ./...)

**Commit:** Add static HTML frontend with embedded files

## 2026-03-25T17:07:00-05:00 — Add /run endpoint with Basic Auth

**Task:** POST /run endpoint — executes loop.sh via exec.CommandContext, protected by Basic Auth

**Changes:**
- Created `src/runner/runner.go` with Runner type
- Mutex-protected concurrent execution prevention
- Executes loop.sh via exec.CommandContext with optional iterations parameter
- Created `src/runner/runner_test.go` with concurrency and execution tests
- Updated `src/cmd/server/main.go` to add /run endpoint
- Basic Auth protection using RUN_AUTH_USER and RUN_AUTH_PASS env vars
- Runs loop asynchronously, returns 202 Accepted immediately
- Added tests for auth, method validation, and endpoint behavior

**Tests:** All pass (go test ./...)

**Commit:** Add /run endpoint with Basic Auth and loop execution

## 2026-03-25T17:09:00-05:00 — Add Prometheus metrics

**Task:** Prometheus metrics: runs_total, runs_failed_total, run_duration_seconds

**Changes:**
- Created `src/metrics/metrics.go` with Metrics type
- Tracks runs_total, runs_failed_total, current_runs, last_run_success_timestamp
- Records run_duration_seconds for each execution
- Exports Prometheus text format via Export() method
- Created `src/metrics/metrics_test.go` with tests for all metrics
- Updated `src/cmd/server/main.go` to integrate metrics with /run endpoint
- Added /metrics endpoint exposing Prometheus format
- Metrics updated on each loop execution (success/failure/duration)

**Tests:** All pass (go test ./...)

**Commit:** Add Prometheus metrics with /metrics endpoint

## 2026-03-25T17:09:00-05:00 — Add structured JSON logging

**Task:** Structured JSON logging (stdlib log/slog)

**Changes:**
- Updated `src/cmd/server/main.go` to use slog.NewJSONHandler
- Set slog as default logger for entire application
- Structured logging for server startup with addr field
- Structured logging for loop execution with error and duration fields
- Replaced all log.Printf calls with slog.Info/Error

**Tests:** All pass (go test ./...)

**Commit:** Add structured JSON logging with slog
