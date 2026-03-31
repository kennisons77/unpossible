# Rails Framework Practices

Loaded when specs/prd.md Framework is Rails.

## Service Objects

- Live in `app/services/`
- Plain Ruby classes, not ActiveRecord
- Single public class method (`.call` by convention)
- Return value or raise — no silent failures
- Keep stateless when possible; pass dependencies as arguments
- Name describes the action: `CategorizationService`, `PiiRedactionService`

## Background Jobs

- Suffix with `Job`: `PipelineOrchestratorJob`, `FolderWatcherJob`
- Inherit from `ApplicationJob`
- Queue names in `config/queue.yml` — use descriptive names: `pipeline`, `ingestion`, `default`
- One responsibility per job — chain jobs rather than building monoliths
- Idempotent when possible — safe to retry on failure
- Recurring jobs configured in `config/recurring.yml` (Solid Queue)

## Migrations

- Reversible by default — use `change` method, not `up`/`down` unless necessary
- No data changes in migrations — use Rake tasks or seeds for data
- Add indexes for foreign keys and frequently queried columns
- Use `t.references` for foreign keys (adds index automatically)
- Timestamp migrations: `rails g migration` handles this

## RSpec Structure

- `spec/models/` — model validations, associations, scopes, instance methods
- `spec/requests/` — controller actions, routing, response codes, JSON structure (API logic)
- `spec/services/` — service object business logic
- `spec/jobs/` — background job behavior
- `spec/integration/` — multi-service flows (e.g., upload → pipeline → storage)
- `spec/system/` — full browser flows with Capybara (login → upload → search)

## Factory Patterns (FactoryBot)

- One factory per model in `spec/factories/`
- Use traits for variations: `factory :document do ... trait :with_blob do ... end end`
- Associations: `association :user` or `user` (FactoryBot infers)
- Sequences for unique values: `sequence(:email) { |n| "user#{n}@example.com" }`
- Keep factories minimal — only required attributes in base factory

## Request vs. System Specs

- **Request specs:** Test controller logic, routing, response codes, JSON structure; no JavaScript, no browser
- **System specs:** Test full user flows with Capybara; includes JavaScript, simulates real browser
- Use request specs for API endpoints and most controller actions
- Use system specs sparingly for critical happy paths (login → upload → search)

## Controller Concerns

- Live in `app/controllers/concerns/`
- Use `ActiveSupport::Concern` for shared behavior
- Example: `Authentication` concern with `require_authentication` before_action
- Keep concerns focused — one responsibility per concern

## Model Concerns

- Live in `app/models/concerns/`
- Extract shared behavior across models
- Example: `Searchable` concern with FTS logic
- Prefer composition over inheritance — concerns are better than STI in most cases

## Active Storage
- TO RESEARCH: replacing this with a local file store?
- Attach blobs via `has_one_attached :blob_name` or `has_many_attached :blob_name`
- Store in S3-compatible backend (MinIO for local, S3 for production)
- Blobs are immutable — never update, only create new versions
- Use `blob.download` to read content, `blob.open` for streaming

## Routing

- RESTful routes by default — use `resources :documents`
- Nest routes only when the parent is required: `resources :concerns do resources :documents end`
- Custom actions: `member do post :confirm end` or `collection do get :search end`
- Namespace API routes: `namespace :api do namespace :v1 do ... end end`

## Configuration

- Environment-specific config in `config/environments/`
- Shared config in `config/initializers/`
- Secrets via ENV vars, never committed — use `ENV.fetch('KEY')` to fail fast on missing
- Use `Rails.application.config.x.custom_setting` for app-specific config

## Testing Discipline

- One expectation per example in unit tests (models, services)
- Multiple expectations OK in integration/system tests (testing a flow)
- Use `let` for lazy setup, `let!` for eager (side effects must happen before example)
- Stub external services (LLM, OCR) in unit tests — real calls only in integration if needed
- Use `travel_to` for time-dependent tests, not `allow(Time).to receive(:now)`
