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
- Audit new gems for maintenance status before adding
