# Sandbox Module

## What It Does

Manages the lifecycle of agent execution containers. Phase 0: a thin Docker dispatcher that runs a command in a container and returns the result. Phase 2: a K8s job dispatcher that creates/destroys pods per agent run.

## Why It Exists

Agent loops need an isolated execution environment — not the full Rails app stack. The sandbox provides a thin execution image with only the tools the agent needs. This separates "the app that manages loops" from "the environment loops run in."

## Phase 0 Scope

Docker Compose for local development. The `DockerDispatcher` shells out to `docker run --rm` with a given image and command. No K8s, no pod provisioning, no WireGuard tunnels — those are Phase 2.

The research doc is explicit: "Build the agent first. Full Weaver requires K8s pod provisioning API, WireGuard tunnel, SPIFFE-style secret injection — that's significant infrastructure before there's anything to run in it."

## Container Run Record

Tracks each dispatched container:
- `image`, `command`, `status` (pending/running/complete/failed)
- `exit_code`, `started_at`, `finished_at`
- `agent_run_id` (FK, nullable)

## Security

- Env vars containing Secret values are filtered before logging
- Commands are passed as argument lists — no shell interpolation of user input
- Containers run with least privileges

## Acceptance Criteria

- `Sandbox::DockerDispatcher#dispatch(image:, command:, env: {})` returns `{exit_code:, stdout:, stderr:, duration_ms:}`
- Successful command returns exit_code 0 and stdout
- Failed command returns non-zero exit_code without raising
- Env vars containing Secret values are not logged
- Dispatch times out after a configurable number of seconds
- ContainerRun record is created and updated with final status on completion
