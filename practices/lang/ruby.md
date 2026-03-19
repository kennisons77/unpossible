# Ruby Practices

Loaded when specs/prd.md Language is Ruby.

## Style
- Follow standard Ruby idioms — code should read like prose
- Prefer `map`, `select`, `reduce` over manual loops
- Use keyword arguments for methods with more than two parameters
- Avoid `unless` with `else` — use `if` for clarity

## Error Handling
- Raise specific exception classes, not `RuntimeError`
- Rescue specific exceptions — never `rescue Exception`
- Let errors propagate unless this layer can genuinely handle them

## Testing (RSpec)
- Describe behavior, not implementation: `it "returns nil when not found"`
- Use `context` blocks to group scenarios: start with "when", "with", or "without"
- One expectation per example in unit tests
- Use `let` for lazy setup; `let!` only when the side effect must happen before the example
- Prefer `expect().to` syntax over `should`

## Structure
- One class per file; filename matches class name in snake_case
- Keep classes small — extract collaborators rather than growing a god object
- Avoid monkey-patching core classes; use refinements if necessary

## Dependencies (Gems)
- Pin exact versions in `Gemfile.lock` — commit it
- Constrain with tilde-minor: `gem 'rails', '~> 8'` — not exact, allows patch updates
- Audit new gems for maintenance status before adding
- Add `rack-attack` to any app with public endpoints — rate limiting from day one
- Run `brakeman` on every PR — treat high-severity findings as blockers

## Code Metrics (Rubocop enforced)
- Line length: 120 chars max
- Method length: 15 lines max
- Block length: 25 lines max
- Cyclomatic complexity: 6 max
- Perceived complexity: 7 max
- Max parameters: 5
- String literals: single quotes
- Hash syntax: ruby19 (`key: value`, not `key => value`)
- Required plugins: `rubocop-performance`, `rubocop-rails`, `rubocop-rspec`

## Test Coverage
- Enforce 90%+ line coverage via SimpleCov — CI fails below threshold
- Add to `spec/rails_helper.rb` with `SimpleCov.minimum_coverage 90`
- Track branch coverage in addition to line coverage

## Auth Patterns
- `activerecord-session_store` over cookie sessions for auditability
- SAML/OAuth2 (`omniauth-saml`, `doorkeeper`) only when the spec requires it — don't add speculatively

## Structured Logging
- Add Lograge from day one — structured request logs are worth the one-line config
- Filter sensitive params in `config/initializers/filter_parameter_logging.rb`
