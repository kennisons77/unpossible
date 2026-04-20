---
name: entrypoint-dispatch
kind: practice
domain: Containers
description: Single entrypoint script dispatches container role by first argument
loaded_by: [build]
---

# Entrypoint Dispatch

Loaded on demand during build when the work touches container images or service startup.

## Pattern

One container image serves multiple roles via a single entrypoint script that
dispatches based on its first argument. The entrypoint waits for dependencies
(database, search) before starting the main process.

```
ENTRYPOINT ["entrypoint"]
CMD ["app"]
```

The same image runs as `app`, `web`, `job`, `spec`, `lint`, or any other mode —
the argument selects the behavior.

## Why

- One image to build, tag, and promote through environments
- No drift between the image that runs tests and the image that runs in production
- Compose services differ only in their `command:` — not their `image:`

## Rules

- The entrypoint script is the only place that decides what process to run
- Each mode is a short function that calls `exec` — the entrypoint replaces itself
  with the target process (no wrapper PID)
- Dependency waits (DB ready, search ready) happen before `exec`, not inside the
  target process
- Unknown arguments fall through to `exec(*ARGV)` — the container can run arbitrary
  commands for debugging
- The entrypoint must be executable and located at a well-known path (`bin/entrypoint`)

## Modes

At minimum, support these modes:

| Mode | Process |
|---|---|
| `app` | Application server (e.g., puma) |
| `web` | Reverse proxy / static server (e.g., nginx) |
| `job` | Background job worker |
| `spec` | Test suite runner |
| `lint` | Linter / static analysis |

Add modes as needed. Each mode is a one-liner that `exec`s the right command.

## Dependency Waits

Before starting `app`, `job`, or `spec` modes, wait for required services:
- Database: TCP check on the DB host/port with a timeout
- Search: TCP check on the search host/port with a timeout

Waits have a hard timeout (e.g., 30s). If a dependency isn't ready, the container
exits non-zero — don't start the process in a broken state.
