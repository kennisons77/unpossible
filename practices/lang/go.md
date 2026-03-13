# Go Practices

Loaded when specs/prd.md Language is Go.

## Error Handling
- Wrap errors with context: `fmt.Errorf("doing X: %w", err)`
- Handle errors at the call site — don't log and return
- Use sentinel errors (`var ErrNotFound = errors.New(...)`) for errors callers need to match

## Testing
- Use table-driven tests: `[]struct{ name, input, want }`
- Test files live alongside source: `foo_test.go` next to `foo.go`
- Use `t.Helper()` in test helpers so failures point to the call site

## Naming
- Package names: short, lowercase, no plurals (`user` not `users`, `store` not `storage`)
- Interfaces: named by behavior, often with `-er` suffix (`Reader`, `Storer`)
- Unexported by default — export only what callers need

## Structure
- Flat package structure until complexity demands otherwise
- `cmd/` for entry points, internal logic in packages at root or `internal/`
- Avoid `util`, `common`, `helpers` packages — name by domain

## Style
- `gofmt` is non-negotiable — always format before committing
- Short variable names are idiomatic in Go for short-lived vars (`r` for request, `w` for writer)
- Prefer early returns to reduce nesting
