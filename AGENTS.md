## Build & Run

- Build image:  `docker compose -f infra/docker-compose.yml build --build-arg HTTP_PROXY="$HTTP_PROXY" --build-arg HTTPS_PROXY="$HTTPS_PROXY" --build-arg NO_PROXY="$NO_PROXY" --build-arg PROXY_CA_CERT_B64="$PROXY_CA_CERT_B64"`
- Run app:      `docker compose -f infra/docker-compose.yml up app`
- Run tests:    `docker compose -f infra/docker-compose.yml run --rm test`

## Validation

Run after each implementation:

- Tests:    `docker compose -f infra/docker-compose.yml run --rm test`
- Lint:     `docker compose -f infra/docker-compose.yml run --rm test bundle exec rubocop` (once RuboCop is set up)

## Infra Notes

- Application code lives in `app/` — the Dockerfile copies this directory into the container.
- `infra/Dockerfile` — `ruby:3.3-slim` base, includes build-essential, libpq-dev, tesseract-ocr, poppler-utils, git, nodejs. Proxy CA cert support via `PROXY_CA_CERT_B64` build arg.
- `infra/docker-compose.yml` — services: `app` (web), `test` (rspec), `db` (pgvector/pg16), `minio` (S3-compatible storage). DB uses tmpfs (bind mounts cause initdb corruption in sandbox).
- `infra/k8s/` — Kubernetes manifests. `imagePullPolicy: Never` for local clusters.

## Codebase Patterns

- Rails 8.1 app with PostgreSQL, Solid Queue (jobs), Solid Cache
- Propshaft asset pipeline, Tailwind CSS, Turbo/Stimulus
- RSpec with FactoryBot and Shoulda Matchers
- Services in `app/services/`, jobs in `app/jobs/`
- Git operations use CLI (not rugged gem) — git is installed in the container

## Gotchas

- Dockerfile `COPY app/ .` overwrites generated Gemfile.lock — must run `bundle lock` after the copy step
- Named Docker volumes don't work in this sandbox — use tmpfs or bind mounts
- Docker build needs proxy build args passed explicitly (sandbox firewall)
- After changing Gemfile, extract Gemfile.lock from image: `docker run --rm infra-test cat Gemfile.lock > app/Gemfile.lock`
