# Requirements: Sandbox

- **Status:** Draft
- **Created:** 2026-04-01
- **Last revised:** 2026-04-01

## Intent

The sandbox manages the lifecycle of containers that run the agent loop. It provides an
isolated execution environment — separate from the application stack — with only the
tools the agent needs. The threat model is preventing a malicious agent from escaping
the container.

## Personas

- **Agent runner:** needs to dispatch a container, get a result back (exit code, output),
  and record what happened — without managing Docker directly.
- **Developer:** needs to observe a running loop in real time to catch errors without
  waiting for timeout. The durable record lives in the agent runner; the
  container output is supplementary.

## User Scenarios

**Scenario 1 — Normal loop execution:**
The agent runner dispatches a container with the loop image and command. The container
runs, writes code to the bind-mounted `web/` directory, and exits 0. The `ContainerRun`
record is updated with the final status, exit code, and duration. The agent runner reads
the result.

**Scenario 2 — Loop failure:**
The container exits non-zero. The `ContainerRun` record is marked `failed` with the
exit code. Stdout and stderr are captured in full. The agent runner receives the non-zero
exit and handles it — re-opening the beat or escalating.

**Scenario 3 — Timeout:**
The container runs past the configured timeout. The dispatcher kills the container and
returns a non-zero exit code. The `ContainerRun` record is marked `failed`. The agent
runner treats this identically to any other failure.

**Scenario 4 — Developer watching a run:**
A developer wants to observe the loop as it runs. They tail the container output in real
time via a future streaming interface. In Phase 0 they wait for completion and read the
captured stdout.

**Scenario 5 — Secret in environment:**
The agent runner passes an API key as an env var. The dispatcher filters it before
logging. The key never appears in `ContainerRun` records or application logs.

## User Stories

- As the agent runner, I want to dispatch a container and receive exit code, stdout, and
  stderr so I can record the result and act on failures.
- As the agent runner, I want container runs to time out so a hung loop doesn't block
  the system indefinitely.
- As a developer, I want secrets filtered from container env vars before logging so
  credentials never appear in records or logs.
- As a developer, I want to observe container output in real time so I can catch errors
  without waiting for the run to complete. *(post-MVP)*

## Success Metrics

| Goal | Metric |
|---|---|
| Isolation | Agent loop cannot affect the host or application stack outside the bind mount |
| Auditability | Every container run has a record with image, command, exit code, and duration |
| Secret safety | No secret value appears in any log or database record |
| Failure visibility | Non-zero exit and timeout both produce a `failed` ContainerRun with captured output |

## Functional Requirements

**MVP:**

- **Docker dispatcher** — shells out to `docker run --rm` with image, command (as
  argument array — no shell interpolation), and env vars. Returns `{ exit_code:,
  stdout:, stderr:, duration_ms: }`.
- **ContainerRun record** — created before dispatch, updated with final status on
  completion. Fields: `image`, `command`, `status` (pending/running/complete/failed),
  `exit_code`, `stdout`, `stderr`, `started_at`, `finished_at`, `agent_run_id`.
- **Bind mount** — `app/` directory mounted into the container so the loop can write
  code to the host filesystem.
- **Timeout** — configurable per dispatch. On timeout: container killed, non-zero exit
  returned, record marked `failed`.
- **Secret filtering** — env vars containing secret values stripped before logging and
  before writing to `ContainerRun`. Secrets never written to the database.
- **Security baseline** — containers run non-root, no `--privileged`, command passed as
  argument array.
- **Output capture** — stdout and stderr captured in full after completion. No size cap
  in Phase 0.

**Post-MVP:**

- Streaming stdout — real-time output for developer observation.
- Network isolation — container restricted to platform API and analytics sidecar only.
- Resource caps — CPU and memory limits per container.
- Kubernetes / pod provisioning — Phase 2.

## Features Out

- Network isolation (Phase 0)
- Resource caps (Phase 0)
- Non-agent-initiated container runs
- Streaming output (Phase 0 — captured after completion only)
- Kubernetes (Phase 2)

## Specs

| Spec file | Description |
|---|---|
| [`concept.md`](concept.md) | DockerDispatcher interface, ContainerRun schema, security constraints, acceptance criteria |

## Open Questions

| Question | Answer | Date |
|---|---|---|
| Should stdout/stderr be stored in the ContainerRun record or written to disk? | In the record for Phase 0 — revisit if output size becomes a problem | 2026-04-01 |
| Streaming: ActionCable or SSE? | Unresolved — post-MVP concern | |
