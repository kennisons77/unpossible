# Kubernetes Practices — Minimal / Single-Dev Focus

Loaded when writing or modifying Kubernetes manifests or deployment scripts for single-developer projects.
This file is intentionally pragmatic: favor simplicity, reproducibility, and low operational overhead.
It assumes no production-scale database replication is required — keep the platform simple and predictable.

## Goals for a single-developer setup
- Make it easy to iterate locally and in a staging-like environment.
- Keep manifests small, readable, and declarative.
- Ensure CI builds, pushes, and deploys are repeatable and safe.
- Minimize cluster-level complexity (no automatic cross-node replication, minimal RBAC).
- Ensure all LLM/agent or build activity that must be sandboxed can run inside a throwaway environment.

---

## When to use Kubernetes here
- Use k8s when you need a realistic environment that mirrors cloud networking/service discovery, or when your deployment target is a k8s cluster.
- For simple local development prefer docker-compose unless you need k8s primitives (Ingress, Service meshes, etc.).
- For single devs, prefer a lightweight local cluster (kind, minikube) or a remote dev cluster with strict isolation.

---

## Repository & manifest layout (recommended)
Keep things obvious and small:

```
infra/
  k8s/
    base/                   # service manifests (Deployment, Service)
      app-deployment.yml
      app-service.yml
      configmap.yml
      secret-template.yml   # do not commit secrets
    overlays/
      staging/
        kustomization.yml
      prd/
        kustomization.yml
scripts/
  deploy-k8s.sh
  build-and-push.sh
README.md                  # how to deploy locally / staging
```

- Use one clear place for k8s manifests. `base/` holds the canonical YAML; `overlays/` hold environment overrides (or use small Helm charts if you prefer).
- Keep secrets out of version control. Commit only templates, not values.

---

## Manifest style & tooling
- Prefer plain YAML + kustomize overlays for single-dev simplicity.
- Keep each manifest focused: one Deployment, one Service per file.
- Avoid templating complexity in manifests unless you need it. Kustomize + simple `sed`/`envsubst` in the deploy script is enough.
- Validate YAML with `kubectl apply --dry-run=client -f` or `kubeval` in CI.

---

## Deploy script pattern (deploy-k8s.sh)
Always wrap `kubectl apply` in a script so you have consistent behavior in CI and locally. The script should:
1. Build and push image (or assume image already pushed).
2. Update the image tag in the manifest (or pass image via kustomize/args).
3. Apply manifests to the target namespace.
4. Wait for rollout to complete and exit non-zero on failure.

Minimal example (adjust for your registry and kustomize layout):
```bash
#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io/you/your-repo}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"
NAMESPACE="${NAMESPACE:-staging}"
KUSTOMIZE_DIR="infra/k8s/overlays/${NAMESPACE}"

# 1. Build & push (optional: skip if CI already pushed)
./scripts/build-and-push.sh "${REGISTRY}:${IMAGE_TAG}"

# 2. Update kustomize image tag and apply
kubectl --namespace "${NAMESPACE}" apply -k "${KUSTOMIZE_DIR}"

# 3. Wait for rollout of the deployment(s)
kubectl --namespace "${NAMESPACE}" rollout status deployment/app --timeout=120s
```

Notes:
- Keep the script idempotent and predictable.
- CI should call the script after successful tests and a pushed image.

---

## Environment mapping (branch -> environment)
Keep it simple:
- `main` → `staging` (or personal dev cluster)
- `prd`  → `production`
- Feature branches → test locally or on ephemeral namespaces if needed

CI only deploys on merge to `main`/`prd`. Do not auto-deploy from feature branches.

---

## Image registry & tagging
- Always tag images with a content-unique tag (git SHA, e.g., `$(git rev-parse --short HEAD)`).
- Do not rely on `latest` in manifests—use explicit tags in kustomize overlays or `image` specifications.
- Use a private registry (GHCR, ECR, GCR) — configure credentials in CI or the sandbox.
- Do not build on the cluster; CI should build and push.

---

## Resource requests & limits (start conservative)
For single-developer clusters keep limits modest so the node can host other workloads:
```yaml
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```
- Always set both `requests` and `limits` to avoid noisy-neighbor issues.
- Tune later if you collect metrics showing under/over-provisioning.

---

## Health checks (required)
Use both readiness and liveness probes:
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 3000
  initialDelaySeconds: 15
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```
- Readiness should be lighter and return quickly if the app can handle traffic; keep liveness as a strict “is it alive?” check.

---

## Services & Ingress
- For internal services use `ClusterIP`.
- For cloud/deploy scenarios that require external access use `LoadBalancer` or a managed Ingress.
- For local dev with kind/minikube use NodePort or an ingress controller; keep CORS/TLS simple (self-signed mkcert or local proxy).
- Keep DNS simple: use host entries or local dev domain mapping if needed.

---

## Config & Secrets
- Non-sensitive configuration → `ConfigMap`.
- Sensitive data → Kubernetes `Secret` or an external secret manager (recommended for production).
- Do not commit secrets to the repo. Use templates for secrets and inject actual values in CI or via secret manager.
- Example: create a secret in CI and `kubectl apply -f` before deploy, or use sealed-secrets/ExternalSecrets if you want GitOps.

---

## Minimal RBAC & Security
- Default to least privilege:
  - The deploy script should operate with a CI service account that has only `apply` rights to the target namespace.
  - Avoid cluster-admin for CI or agents.
- Pod security:
  - Run non-root where possible.
  - Set read-only root filesystem if feasible.
- Network policy: optional for single-dev; document if you add it.

---

## Autoscaling
- For simplicity, do not enable HPA by default for single devs.
- Add HPA later if load requires it; start with fixed replica counts and sensible resource requests.

---

## CI/CD order (simple and practical)
1. Lint: YAML + k8s best-practices (optional tools: kube-linter, kubeval)
2. Unit tests
3. Build image
4. Push image to registry (tagged by SHA)
5. Deploy: run `scripts/deploy-k8s.sh` to staging
6. Smoke tests / rollout verification
7. Optional: Promote to production via manual approval on `prd` branch

Keep CI pipelines small and fast; E2E tests run on staging only.

---

## Local development guidance
- Prefer `docker-compose` for quick iterations unless you specifically need k8s features.
- If using k8s locally:
  - Use `kind` or `minikube`.
  - Set `imagePullPolicy: Never` for local image builds or load images into kind with `kind load docker-image`.
  - Keep a `README.md` with commands to start the local cluster and load images.

---

## Observability (lightweight)
- Logs: rely on pod logs (`kubectl logs`) and a simple local aggregator if needed (EFK/Promtail+Loki optional).
- Metrics: expose Prometheus-friendly metrics endpoint when easy to add; otherwise use request-level logs.
- Alerting: not required for single-dev; add later when you have production SLOs.

---

## Cleanup & housekeeping
- Keep old images pruned in registry (CI can run a cleanup job).
- Namespace lifecycle: for ephemeral test namespaces, ensure CI or scripts remove them to avoid cluster clutter.
- Periodically test rollback: `kubectl rollout undo deployment/<name>` and document the procedure.

---

## Common gotchas (quick checklist)
- Don’t commit secrets.
- Don’t leave `imagePullPolicy: Never` in `prd`.
- Pin base images; avoid `:latest`.
- Ensure CI has credentials to the image registry and (optionally) to the cluster.
- Keep manifest diffs minimal — small changes are easier to roll back.

---

## Example minimal `kustomization.yml` (base)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - app-deployment.yml
  - app-service.yml
images:
  - name: ghcr.io/you/your-repo
    newTag: "REPLACE_WITH_SHA"
```

## Final notes
- Start small and iterate. For a single developer, the biggest wins are: clear docs, a reliable `deploy-k8s.sh` script, and images tagged by SHA.
- Prefer local reproducibility: you should be able to run the same deploy script locally (against kind/minikube) as CI runs in staging.
- If you want, I can add a small `sb-inspect` or `sb-sync` helper into the repository to make sandbox-based development and pushing into a sandbox easier.

If you want, I can also produce a short `deploy-k8s.sh` and `build-and-push.sh` pair tailored to your registry and current CI setup — tell me your registry and credential method and I’ll generate them.