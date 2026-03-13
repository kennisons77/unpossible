## Build & Run

- Build image:  `docker compose -f infra/docker-compose.yml build`
- Run app:      `docker compose -f infra/docker-compose.yml up app`
- Run tests:    `docker compose -f infra/docker-compose.yml run --rm test`

## Validation

Run after each implementation:

- Tests:    `docker compose -f infra/docker-compose.yml run --rm test`
- Lint/typecheck: `[add command here — can run inside the test container or as a separate target]`

## Infra Notes

- Application code lives in `app/` — the Dockerfile copies this directory into the container.
- `infra/Dockerfile` — update when the base image, dependencies, or start command changes.
- `infra/docker-compose.yml` — defines `app` (run) and `test` (run tests) service targets.
- `infra/k8s/` — Kubernetes manifests. `imagePullPolicy: Never` is set for local clusters (kind, minikube); remove this for registry-based deployments.

## Codebase Patterns

Key conventions the agent should follow:

- `[e.g., Entry point is app/main.py]`
- `[e.g., All routes are defined in app/routes/]`
- `[e.g., Use the shared logger, not print/console.log]`

## Gotchas

Things that wasted time and shouldn't happen again:

- `[e.g., Must rebuild the Docker image after changing dependencies]`
