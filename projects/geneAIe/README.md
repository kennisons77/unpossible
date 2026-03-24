# geneAIe — The Sovereign Library

A self-hosted personal data governance system. Upload fragmented digital and physical records (government IDs, medical documents, bills, contracts), classify them with Claude Haiku, normalize them into structured Markdown files tracked in git, and search everything locally.

**Philosophy:** The LLM proposes, the human confirms.

---

## Requirements

- Docker and Docker Compose
- An [Anthropic API key](https://console.anthropic.com/) (for Claude Haiku classification)

---

## Quick Start

### 1. Clone and navigate

```bash
git clone <repo-url>
cd unpossible/projects/geneAIe
```

### 2. Set environment variables

Create a `.env` file in the `infra/` directory:

```bash
cp infra/.env.example infra/.env
```

Then edit `infra/.env` and set your Anthropic API key (see [Environment Variables](#environment-variables) below).

### 3. Build and start

```bash
docker compose -f infra/docker-compose.yml build
docker compose -f infra/docker-compose.yml up app
```

This starts three services:
| Service | URL | Purpose |
|---------|-----|---------|
| Rails app | http://localhost:3000 | Main web interface |
| MinIO API | http://localhost:9000 | S3-compatible blob storage |
| MinIO Console | http://localhost:9001 | MinIO admin UI |

### 4. Set up the database

On first run, create and migrate the database:

```bash
docker compose -f infra/docker-compose.yml exec app bin/rails db:create db:migrate db:seed
```

### 5. Log in

Visit http://localhost:3000/session/new

Default credentials (created by `db/seeds.rb`):
- **Email:** `admin@sovereign.local`
- **Password:** `password`

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | — | Anthropic API key for Claude Haiku (document classification and extraction) |
| `DATABASE_URL` | No | `postgres://sovereign:sovereign@db:5432/sovereign_library_development` | PostgreSQL connection string |
| `RAILS_ENV` | No | `development` | Rails environment (`development`, `test`, `production`) |
| `SECRET_KEY_BASE` | No | Auto-generated | Rails session encryption key — set explicitly in production |
| `AWS_ACCESS_KEY_ID` | No | `minioadmin` | MinIO access key (S3-compatible blob storage) |
| `AWS_SECRET_ACCESS_KEY` | No | `minioadmin` | MinIO secret key |
| `AWS_ENDPOINT` | No | `http://minio:9000` | MinIO endpoint URL |
| `RAILS_MAX_THREADS` | No | `5` | Database connection pool size |

For local development, Docker Compose injects defaults for all except `ANTHROPIC_API_KEY`. Create `infra/.env`:

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

In production, set `SECRET_KEY_BASE` to a randomly generated value:

```bash
docker compose -f infra/docker-compose.yml run --rm app bin/rails secret
```

---

## Running Tests

Tests run in an isolated Docker container against a dedicated test database:

```bash
docker compose -f infra/docker-compose.yml run --rm test
```

This will:
1. Drop and recreate the test database
2. Run all migrations
3. Execute the full RSpec suite

To run a specific file or example:

```bash
# Run a single spec file
docker compose -f infra/docker-compose.yml run --rm test bundle exec rspec spec/models/document_spec.rb

# Run with verbose output
docker compose -f infra/docker-compose.yml run --rm test bundle exec rspec --format documentation
```

### Running tests locally (without Docker)

If you have Ruby 3.3 and PostgreSQL installed locally:

```bash
cd src
bundle install
DATABASE_URL=postgres://... RAILS_ENV=test bin/rails db:create db:migrate
bundle exec rspec
```

### Current test status

- 41 examples, 0 failures
- Coverage: User, Session, Document, Concern, DocumentField models + session request flows

---

## Project Structure

```
geneAIe/
├── infra/
│   ├── Dockerfile           # Ruby 3.3 + OCR tools (Tesseract, Poppler, libvips)
│   └── docker-compose.yml   # PostgreSQL (pgvector), MinIO, app, test services
├── src/                     # Rails 8 application
│   ├── app/
│   │   ├── controllers/
│   │   ├── models/          # User, Session, Document, Concern, DocumentField
│   │   ├── services/        # ETL pipeline services (in progress)
│   │   └── views/
│   ├── config/
│   │   ├── database.yml
│   │   └── storage.yml      # Active Storage (disk for dev, S3/MinIO for production)
│   ├── db/migrate/
│   └── spec/                # RSpec tests + FactoryBot factories
└── specs/
    ├── prd.md               # Full product requirements
    └── plan.md              # Implementation checklist
```

---

## Technology Stack

- **Rails 8.0** + Ruby 3.3
- **PostgreSQL 16** with pgvector (for future semantic search)
- **Solid Queue** — database-backed background jobs (no Redis needed)
- **Solid Cache** — database-backed caching (no Redis needed)
- **MinIO** — local S3-compatible blob storage
- **Active Storage** — file attachment abstraction
- **Tailwind CSS** + Hotwire (Turbo + Stimulus)
- **Claude Haiku** — document classification and structured extraction
- **Tesseract OCR** — fallback text extraction for scanned documents
- **Git** — auto-commit every normalized document to a local library

---

## Development Notes

- The database uses `sql` schema format (not `schema.rb`) because pgvector types are incompatible with the Ruby schema dumper. Always use `db:migrate`, never `db:schema:load`.
- Blobs are stored in MinIO and never committed to git. Normalized Markdown files are committed to the git-tracked library.
- PII redaction (SSN, DOB, passport numbers, account numbers) runs before any Claude API call.
- The default MinIO data directory is `../.data/minio/` (git-ignored).
