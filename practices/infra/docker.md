# Docker Practices — Single-developer, pragmatic baseline

This document is a concise, opinionated set of Docker practices intended for a single developer or small project.
Focus: simplicity, reproducibility, fast iteration, and security. Avoid premature complexity; prefer clear defaults
that are easy to reason about and mirror CI behavior.

Table of contents
- Philosophy
- Dockerfile: multi-stage, reproducible builds
- Entrypoint, PID 1 and signals
- Image build hygiene & cache
- .dockerignore
- Compose patterns: local vs CI
- Local developer experience (startup)
- Local TLS & email testing
- Databases in Docker (dev & CI)
- Secrets and credentials
- CI/Registry integration
- Sandbox considerations
- Minimal examples

Philosophy
- Keep images minimal and focused: one service per image.
- Build once, run anywhere: tag images by content (git SHA) and use the same images in CI and in local/staging.
- Make local dev fast and easy — allow `docker compose` flows for iterative work, but keep deployable image build commands aligned with CI.
- Favor readability over cleverness; explicit is easier to debug than heavily templated magic.

Dockerfile: multi-stage, reproducible builds
- Use a multi-stage Dockerfile: one build stage and a final runtime stage.
- Pin base images (e.g. `python:3.11-slim`, `node:20-buster-slim`) — do not use `:latest`.
- Avoid installing build-time tools into the runtime image.
- Copy only what’s needed into the final image (avoid copying the whole repo).
- Set `LABEL` values (maintainer, org, vcs-ref, build-date) for traceability.
- Use `ARG` for build-time variables (e.g. `BUILD_DATE`, `VCS_REF`, `NODE_ENV`) but keep runtime config via env vars.

Minimal Dockerfile skeleton
```dockerfile
# build stage
FROM node:20-bullseye-slim AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production=false
COPY . .
RUN npm run build

# runtime stage
FROM node:20-bullseye-slim AS runtime
# use tini for PID 1 (see section)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates tini && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./package.json
ENV NODE_ENV=production
EXPOSE 3000
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "dist/index.js"]
```

Entrypoint, PID 1 and signals
- Use tini (or an equivalent) as PID 1: it handles forwarding signals and reaping zombies.
- Prefer JSON-form `ENTRYPOINT` and `CMD` arrays so that signals are delivered properly and there is no shell PID handling ambiguity.
- Keep runtime processes as the main foreground process — do not use shell wrappers unless necessary.

Image build hygiene & cache
- Reorder Dockerfile steps to maximize cache reuse:
  - copy dependency files (package.json/Gemfile) first and install deps,
  - then copy application code.
- Use small layers and `--no-install-recommends` for apt to shrink images.
- Clean package manager caches after install (apt, apk).
- For multi-arch or advanced builds use `docker buildx` with a CI builder.
- For local k8s (kind) development: either `docker build` + `kind load docker-image` or `buildx` with `--load` to make images available locally.

.tips:
- Use `--platform` when building images in CI if you need deterministic platform artifacts.
- Use reproducible builds: pass `--build-arg VCS_REF=$(git rev-parse --short HEAD)` and write it into the image metadata.

.dockerignore
- Exclude large and ephemeral directories: `node_modules`, `.venv`, `venv`, `dist`, `build`, `.git`, `.DS_Store`, `tmp`, `log`, `coverage`, secrets, and local editor files.
- Example `.dockerignore`:
```
node_modules
dist
.vscode
.env
.git
*.log
tmp
coverage
```

Compose patterns: local vs CI
- Maintain two compose files:
  - `docker-compose.yml` (local dev): full dev setup with volumes, debug tools, mail catcher, dev database.
  - `docker-compose.ci.yml` (CI/test): minimal set for tests (app + single DB), ephemeral volumes or tmpfs, and resource limits lowered for CI.
- Prefer named volumes for local dev persistence and `tmpfs` for CI/test DBs to avoid permission and cleanup issues.
- Do not rely on `imagePullPolicy: never` in production manifests; use it only for local convenience.

docker-compose tips
- Provide a `docker-compose.override.yml` with developer-specific overrides (ports, env) and do not commit personal configs.
- Add `profiles` to compose to toggle optional services (e.g., mail, debugger).

Local developer experience (startup)
- Provide a single script to get dev running (`scripts/startup.sh` or `bin/dev`):
  - builds images as needed,
  - creates local certs if using TLS,
  - starts services,
  - runs initial seeds/migrations,
  - prints convenient endpoints.
- Keep the script idempotent and adoptable by CI: it should be possible to run locally without manual tweaks.

Local TLS & email testing
- Use `mkcert` and a local reverse proxy (Caddy) to provide HTTPS locally and avoid CORS/cookie issues.
- Email: use Mailpit or MailHog to capture outbound mail in development (never send real mail in dev).

Databases in Docker (dev & CI)
- For dev: use a persistent named volume (so developer restarts keep data) and set preloaded seeds or fixtures.
- For CI: use ephemeral DBs. `tmpfs` or ephemeral volumes are preferred to ensure test isolation and speed.
- Provide scripts to reset or seed the DB: `scripts/db-reset.sh`.
- Do not configure replication or HA for development; keep a single instance and mock the rest.

Secrets and credentials
- Never put secrets into images or version control.
- For local dev, use `.env` files that are gitignored and load them via `docker compose --env-file`.
- In CI, inject secrets using the CI secret mechanism or environment variable injection.
- For sandboxed loop environments, inject minimal scoped credentials or mount a secure credentials file at runtime.

CI / Registry integration
- Build in CI and push images to a registry with a content-unique tag (git SHA).
- Example flow:
  1. CI builds image: `docker buildx build --tag ghcr.io/me/repo:$GIT_SHA --push .`
  2. CI deploy uses that exact tag.
- Keep a stable tagging scheme: `registry/org/repo:$GIT_SHA`.
- Limit stored images in the registry (cleanup policy) to avoid cost buildup.

Security & runtime best practices
- Run containers as a non-root user where possible:
  - Create a user with a fixed UID in the Dockerfile, switch `USER` to that UID in the final stage.
- Set a read-only root filesystem if possible and add writable dirs as volumes.
- Drop unnecessary Linux capabilities; avoid `--privileged`.
- Scan images for vulnerabilities in CI (Trivy, Snyk). Run scans as part of the pipeline but do not block basic development if you haven't reached release maturity.

Performance and iteration
- For fast builds use bind mounts and run code outside the container during early development. For reproducible CI builds, use fully built images.
- Use rebuild caches: mount a persistent cache for package managers in CI, and make use of multi-stage caching patterns.

Sandbox compatibility notes
- If you run inside a sandbox/VM, ensure your build pipeline can either mount host directories into the sandbox or copy source into it (see `tar | exec` patterns).
- For CI that executes builds inside isolated runners, ensure the runner has credentials to push to the registry.

Minimal commands (single dev)
- Build locally (tag by SHA):
```bash
GIT_SHA=$(git rev-parse --short HEAD)
docker build -t ghcr.io/you/app:${GIT_SHA} .
```
- Buildx multi-platform (recommended for CI):
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/you/app:${GIT_SHA} --push .
```
- Run dev compose:
```bash
docker compose up --build
```
- Run CI compose for tests:
```bash
docker compose -f docker-compose.ci.yml up --build --abort-on-container-exit
```
- Load image into kind for local k8s:
```bash
docker build -t ghcr.io/you/app:${GIT_SHA} .
kind load docker-image ghcr.io/you/app:${GIT_SHA}
```

Examples and snippets
- Minimal `Dockerfile` and `docker-compose.yml` examples are above. Keep your compose/service definitions human readable and compact.
- Add `healthcheck` definitions in Dockerfile or compose when helpful:
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
  interval: 30s
  timeout: 5s
  retries: 3
```

Common pitfalls to avoid
- Committing secrets or private keys in images or `.dockerignore` omissions.
- Relying on `:latest` for deployable images.
- Building images inside production cluster nodes.
- Heavy orchestration templating for a single developer — prefer direct, explicit manifests.

Summary checklist
- Multi-stage Dockerfile, pinned base images, tini as PID 1.
- `.dockerignore` that excludes build artifacts and secrets.
- Two compose files: full dev + minimal CI.
- Build tagged images by SHA and push from CI.
- Provide a `startup` script for reproducible local dev.
- Inject secrets at runtime, not baked into images.
- Keep single-replica defaults and small resource requests for single-developer clusters.

If you’d like, I can add a concrete `scripts/build-and-push.sh` and `scripts/startup.sh` for your repo with your registry parameters prefilled — tell me your registry and preferred auth method (PAT, GHCR, ECR, etc.) and I’ll draft them.