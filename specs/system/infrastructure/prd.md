# PRD: Infrastructure

- **Status:** Draft
- **Created:** 2026-04-01
- **Last revised:** 2026-04-01

## Intent

Infrastructure advances with the project phase — nothing is added before it's needed.
The phase model constrains the build loop to work only within the current phase, and
gives the developer explicit control over when complexity is introduced. The goal is
deterministic, reproducible deployments at every phase: "it works on my machine" in
Phase 0, push-to-deploy in Phase 2.

## Personas

- **Developer:** shapes phase progression, reviews infra files, decides when to advance.
  Needs confidence that the deployment topology is reproducible and that the loop hasn't
  added infrastructure ahead of schedule.
- **Build loop:** writes and maintains infra files within the current phase only. Checks
  the current phase before writing any infra file — never adds Phase N+1 infrastructure.
- **Projects built with unpossible:** each project gets its own compose stack generated
  by the loop from `specs/project-prd.md`. Infrastructure is not shared between projects.

## User Scenarios

**Scenario 1 — Local development (Phase 0):**
A developer runs `docker compose up`. Rails starts on port 3000, the Go runner and
analytics sidecar start, Postgres and Redis are available on the internal network. The
developer runs the loop. Tests pass inside the container. Everything works without
installing Ruby, Go, or Postgres locally.

**Scenario 2 — New project bootstrapped:**
The loop reads `specs/project-prd.md` for a new project, finds the language and base image, and
writes `infra/Dockerfile` and `infra/docker-compose.yml`. The developer runs
`docker compose up` and the project stack starts. No manual Dockerfile authoring.

**Scenario 3 — Loop stays in phase:**
The build loop is implementing a beat. It checks the current phase (0) before writing
any infra files. It does not create `.github/workflows/`, `infra/nixos/`, or
`infra/k8s/` — those belong to Phase 1 and 2. The beat is scoped to Phase 0 infra only.

**Scenario 4 — Advancing to Phase 1:**
The developer explicitly adds an "Advance to Phase 1" task to the plan. The loop sees
this task, checks that Phase 0 acceptance criteria pass, and writes
`.github/workflows/ci.yml`. CI runs on every push from that point forward.

**Scenario 5 — Agent sandbox in Phase 2:**
The platform is running on k3s. The agent runner dispatches a loop run. Instead of
`docker run --rm`, it provisions a K8s pod for the run. The pod receives a short-lived
WireGuard tunnel identity — no long-lived API keys. When the run completes, the pod is
torn down. The tunnel identity expires.

## User Stories

- As a developer, I want `docker compose up` to start the full local stack so I can
  develop without installing platform dependencies locally.
- As the build loop, I want to know the current phase so I never add infrastructure
  ahead of schedule.
- As the build loop, I want to generate `infra/Dockerfile` and `infra/docker-compose.yml`
  for new projects from `specs/project-prd.md` so projects are runnable without manual setup.
- As a developer, I want phase advancement to be explicit so I control when complexity
  is introduced.
- As the platform, I want agent sandbox runs in Phase 2 to use short-lived WireGuard
  tunnel identities so no long-lived credentials are distributed to agent pods.

## Success Metrics

| Goal | Metric |
|---|---|
| Local stack works | `docker compose up` → rails responds on port 3000, tests pass |
| Loop stays in phase | No Phase N+1 infra files created until phase advancement is explicitly planned |
| Project bootstrap | New project stack starts from `docker compose up` without manual Dockerfile authoring |
| Reproducibility | Same commit always produces the same running stack |

## Functional Requirements

**Phase 0 (MVP):**

- **Docker Compose stack** — `infra/docker-compose.yml` runs rails, go_runner, analytics
  sidecar, Postgres (pgvector), Redis on a single bridge network. Postgres and Redis
  internal only — never bound to `0.0.0.0`.
- **Test stack** — `infra/docker-compose.test.yml` runs the full test suite with
  ephemeral volumes, no exposed ports.
- **Image tags** — always git SHA, never `latest`.
- **Project bootstrap** — loop generates `infra/Dockerfile` and `infra/docker-compose.yml`
  for each project from `specs/project-prd.md` (language, base image, test command, port).
- **Phase gate** — loop checks current phase before writing any infra file. Phase N+1
  files are never created until an explicit "Advance to Phase N" task is in the plan.

**Phase 1:**

- GitHub Actions CI — `bundle exec rspec` on every push.
- Test stack runs in CI using `docker-compose.test.yml`.

**Phase 2:**

- k3s on NixOS (preferred) or equivalent. Required properties: reproducible builds,
  atomic rollback, push-to-deploy without a manual CI deploy step.
- Push-to-deploy: `git push` → server detects new commit → rebuilds → applies K8s
  manifests → health check.
- Pod-per-agent-run for sandbox: each loop run gets a dedicated K8s pod, torn down on
  completion. Short-lived WireGuard tunnel identity for pod-to-platform auth — no
  long-lived API keys distributed to agent pods.
- Kustomize overlays for staging and production.
- SOPS-encrypted secrets committed to repo, decrypted at deploy time.

**Phase 3:**

- Multi-node k3s or managed K8s.
- Horizontal pod autoscaling for Rails.
- Separate Postgres with read replica.
- Consider Vault or AWS Secrets Manager for secrets if multi-node.

## Features Out

- NixOS locked as the only Phase 2 option — properties matter, implementation does not
- Shared infrastructure between projects
- Manual Dockerfile authoring for projects
- Any Phase N+1 infrastructure until explicitly planned

## Specs

| Spec file | Description |
|---|---|
| [`spec.md`](spec.md) | Phase model, compose file layout, pod layout, NixOS module structure, file ownership table, acceptance criteria |

## Open Questions

| Question | Answer | Date |
|---|---|---|
| NixOS vs alternative for Phase 2 | NixOS preferred — reproducible, atomic rollback, push-to-deploy. Not locked. If it doesn't work out, find an alternative satisfying the same properties. | 2026-04-01 |
| Phase 2 sandbox: persistent worker pod vs pod-per-run | Pod-per-run with WireGuard tunnel — more isolated, auth solved by short-lived tunnel identity. Complexity deferred to Phase 2 planning. | 2026-04-01 |
| WireGuard tunnel: provisioned by platform or by NixOS module? | Unresolved — Phase 2 concern | |
