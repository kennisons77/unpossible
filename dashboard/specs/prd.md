# Product Requirements Document — dashboard

## Overview

A local web UI and API that reads unpossible's generated markdown files
(`IMPLEMENTATION_PLAN.md`, `WORKLOG.md`, `specs/`) and exposes project data
as a browsable interface. No external services — all data comes from files on disk.

## Goals

1. Serve a read-only web UI showing specs, implementation plan, and worklog
2. Expose a JSON API for the same data
3. Optionally trigger `loop.sh` via a protected `/run` endpoint
4. Deploy as a single container alongside the unpossible project

## Non-Goals

- Writing back to spec files (deferred)
- Multi-project navigation (deferred)
- Authentication beyond Basic Auth on `/run`

## Technical Constraints

- Language: Go 1.22
- Base image: golang:1.22-alpine (build stage), alpine:3.19 (runtime)
- Test command (in container): go test ./...
- Port: 8080

## Data Sources (read-only volume mount)

The container mounts the unpossible repo root at `/workspace`:

| File | Purpose |
|------|---------|
| `/workspace/IMPLEMENTATION_PLAN.md` | Task list with completion status |
| `/workspace/WORKLOG.md` | Iteration history |
| `/workspace/specs/*.md` | Spec files |
| `/workspace/specs/features/*.md` | Feature specs |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Liveness probe |
| GET | `/ready` | Readiness probe |
| GET | `/api/plan` | IMPLEMENTATION_PLAN.md as JSON |
| GET | `/api/worklog` | WORKLOG.md as JSON |
| GET | `/api/specs` | List of spec files |
| GET | `/api/specs/{name}` | Single spec file content |
| POST | `/run` | Trigger loop.sh (Basic Auth required) |

## Phase

Phase 1
