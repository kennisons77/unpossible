# Rust Practices

Loaded when specs/prd.md Language is Rust.

## Error Handling
- Use `Result<T, E>` — never `unwrap()` or `expect()` in production code paths
- Define a project-level error type (or use `thiserror`) — don't return `Box<dyn Error>` from library code
- Use `?` for propagation; add context with `.map_err(|e| format!("doing X: {e}"))`

## Ownership
- Prefer borrowing over cloning — clone only when ownership is genuinely needed
- Return owned types from public APIs; accept borrows in arguments
- Lifetime annotations are a last resort — restructure first

## Testing
- Unit tests go in a `#[cfg(test)]` module at the bottom of the same file
- Integration tests go in `tests/`
- Use `assert_eq!` with the expected value first (convention)

## Structure
- One concept per module; `mod.rs` only when the module has submodules
- `pub use` re-exports in `lib.rs` to keep the public API surface explicit
- Feature-flag heavy dependencies with `[features]` in `Cargo.toml`

## Style
- `cargo fmt` and `cargo clippy` before every commit — treat clippy warnings as errors
- Prefer iterators over manual loops
- Name types, not implementation details: `UserId(u64)` not `user_id: u64` where identity matters
