---
name: log-tail-relay
kind: concept
status: proposed
description: Stream host Docker logs into the agent sandbox for debugging
modules: []
---

# Log Tail Relay

## Problem

The agent runs in a sandbox and cannot see host Docker logs. Debugging boot failures,
migration errors, and seed output requires the developer to manually copy-paste log
output into the conversation. This is slow and error-prone.

## Goal

Provide a mechanism for the agent to request and receive the tail of host-side container
logs without requiring direct Docker daemon access from the sandbox.

## Constraints

- Must not expose the Docker socket to the sandbox
- Must work with the existing Docker Compose stack
- Should be opt-in (developer initiates or approves the relay)
- Tail length should be bounded (e.g. last 100 lines) to avoid flooding context

## Possible Approaches

1. **File relay** — `make logs-snapshot` writes the last N lines to a mounted volume the agent can read
2. **HTTP endpoint** — a lightweight sidecar on the host that serves `/logs?service=rails&lines=100`
3. **Clipboard/pipe integration** — CLI tooling that pipes `docker compose logs --tail=100` into the agent's stdin

## Open Questions

- Which approach best fits the single-user local-only constraint?
- Should the agent be able to request logs proactively, or only when the developer triggers it?
- Should this cover all services (postgres, sidecars) or just rails?
