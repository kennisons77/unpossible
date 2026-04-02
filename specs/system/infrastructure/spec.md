# Infrastructure

## Phase Model

Infrastructure advances with the project phase. Nothing is added before it's needed.

| Phase | Environment | Infrastructure |
|---|---|---|
| 0 | Local | Docker Compose only |
| 1 | CI | GitHub Actions — test on every push |
| 2 | Staging | k3s on a single NixOS node, push-to-deploy |
| 3 | Production | Multi-node k3s or managed K8s, secrets management, monitoring |

Current phase: **0**. Only Phase 0 infrastructure is planned. Future phases are documented here as reference — they are not implemented until the plan explicitly includes an "Advance to Phase N" task.

---

## Phase 0 — Local (Docker Compose)

Two compose files:

**`infra/docker-compose.yml`** — full local dev stack:
```
rails          ruby:3.3-slim, port 3000
go_runner      Go sidecar, port 8080
analytics      Go analytics sidecar, port 9100
postgres       pgvector/pgvector:pg16, port 5432 (internal only)
redis          redis:7-alpine, port 6379 (internal only)
```

**`infra/docker-compose.test.yml`** — CI/test stack (ephemeral volumes, no ports exposed):
```
test           runs bundle exec rspec
postgres       same image, tmpfs volume
redis          same image, tmpfs volume
```

All services on a single `unpossible2` bridge network. Postgres and Redis are never bound to `0.0.0.0` — internal network only.

Image tags: always git SHA (`$(git rev-parse --short HEAD)`), never `latest`.

---

## Phase 2 — Staging (NixOS + k3s)

### Why NixOS

Loom's deployment model is the reference: `git push` → NixOS auto-update service detects new commit → rebuilds configuration → activates. Reproducible, declarative, no configuration drift. The server state is fully described in the repo.

NixOS gives:
- Reproducible builds — same config always produces the same system
- Atomic upgrades and rollbacks — `nixos-rebuild switch` is transactional
- Push-to-deploy without a CI deploy step — the server pulls and rebuilds itself

### k3s on NixOS

k3s is the Kubernetes distribution for single-node and small clusters. It runs as a systemd service on NixOS. Unpossible2 runs as a Kubernetes workload on k3s — not as a bare systemd service — so the same manifests work locally (kind/minikube) and on the staging server.

### Pod layout

One pod per project. Each pod contains:
```
rails container        port 3000
go_runner sidecar      port 8080  (shares network namespace with rails)
analytics sidecar      port 9100  (shares network namespace with rails)
```

Postgres and Redis run as separate deployments with persistent volumes. They are not in the application pod.

### Agent sandbox pods

Each agent loop run gets a dedicated K8s pod, provisioned on dispatch and torn down on
completion. The pod authenticates to the platform API via a short-lived WireGuard tunnel
identity — no long-lived API keys are distributed to agent pods. Tunnel provisioning is
handled at pod startup; the identity expires when the pod terminates.

### NixOS module structure

```
infra/nixos/
  configuration.nix       # imports all modules
  k3s.nix                 # k3s service, kubeconfig
  auto-update.nix         # watches git, runs nixos-rebuild on new commits
  secrets.nix             # SOPS-encrypted secrets (API keys, DB passwords)
  postgres.nix            # Postgres service + pgvector extension
  redis.nix               # Redis service
```

### Push-to-deploy flow

```
git push origin main
    ↓
NixOS auto-update service (polls every 30s)
    ↓
Detects new commit at /var/lib/unpossible2
    ↓
nixos-rebuild switch
    ↓
kubectl apply -f infra/k8s/
    ↓
kubectl rollout status deployment/unpossible2
    ↓
Health check: curl http://localhost:3000/up
```

Rollback: `nixos-rebuild switch --rollback` or `kubectl rollout undo`.

### Kubernetes manifest layout

```
infra/k8s/
  base/
    deployment.yaml       # rails + sidecar containers
    service.yaml          # ClusterIP for rails (port 3000)
    configmap.yaml        # non-secret env vars
    secret-template.yaml  # shape only — values injected by SOPS/secrets.nix
  overlays/
    staging/
      kustomization.yaml
    production/
      kustomization.yaml
```

### Secrets management

SOPS-encrypted secrets committed to the repo. Decrypted at deploy time by the NixOS secrets module. API keys, DB passwords, and JWT secrets are never in plaintext in the repo.

For Phase 2: SOPS with age encryption. For Phase 3: consider Vault or AWS Secrets Manager if multi-node.

---

## Phase 3 — Production

Not planned yet. Reference points when the time comes:

- Multi-node k3s or managed K8s (EKS, GKE) depending on scale
- Apache AGE graph extension for Postgres (if traversal queries justify it — see `prd.md`)
- Horizontal pod autoscaling for Rails
- Separate Postgres instance with read replica
- SPIFFE-style secret injection replacing SOPS

---

## Infra File Ownership

The build loop maintains infra files within the current phase only. It never adds Phase N+1 infrastructure until the plan explicitly includes an "Advance to Phase N" task.

| File | Owner | Phase |
|---|---|---|
| `infra/docker-compose.yml` | Build loop | 0 |
| `infra/docker-compose.test.yml` | Build loop | 0 |
| `infra/Dockerfile` (Rails) | Build loop | 0 |
| `infra/Dockerfile.runner` (Go) | Build loop | 0 |
| `infra/Dockerfile.analytics` (Go) | Build loop | 0 |
| `.github/workflows/ci.yml` | Build loop | 1 |
| `infra/nixos/` | Build loop | 2 |
| `infra/k8s/` | Build loop | 2 |

---

## Acceptance Criteria

- `docker compose -f infra/docker-compose.yml up` starts all services and rails responds on port 3000
- `docker compose -f infra/docker-compose.test.yml run --rm test` runs the full RSpec suite
- Postgres and Redis ports are not bound to 0.0.0.0 in any compose file
- Image tags in compose files use git SHA, not `latest`
- `infra/k8s/` and `infra/nixos/` do not exist until Phase 2 is explicitly planned
