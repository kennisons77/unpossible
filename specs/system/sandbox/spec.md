# Sandbox Module

## What It Does

Manages the lifecycle of agent execution containers. Provides an isolated execution environment — separate from the application stack — with only the tools the agent needs.

## Why It Exists

Agent loops need isolation. Separating "the app that manages loops" from "the environment loops run in" keeps the execution surface minimal and auditable.

## Phase 0 Scope

Local Docker execution. A dispatcher shells out to `docker run --rm` with a given image and command. No Kubernetes, no pod provisioning — those are Phase 2.

## Container Run Record

Tracks each dispatched container:
- `image`, `command`, `status` (pending/running/complete/failed)
- `exit_code`, `started_at`, `finished_at`
- `agent_run_id` (nullable — not all container runs are agent-initiated)

## Security

- Env vars containing secrets are filtered before logging
- Commands are passed as argument lists — no shell interpolation of user input
- Containers run with least privileges, non-root, no `--privileged`

## Acceptance Criteria

- `DockerDispatcher#dispatch(image:, command:, env: {})` returns `{exit_code:, stdout:, stderr:, duration_ms:}`
- Successful command returns exit_code 0 and stdout
- Failed command returns non-zero exit_code without raising
- Env vars containing secret values are not logged
- Dispatch times out after a configurable number of seconds
- Container run record is created and updated with final status on completion
