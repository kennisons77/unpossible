# General Coding Practices

Loaded every build iteration. Language-agnostic rules that apply to all code written in this project.

## Comments
- Explain *why*, never *what* — if a comment restates the code, delete it
- A function that needs a comment to describe what it does should be renamed or split
- Mark non-obvious decisions: `// must happen before X because Y`
- TODO comments must include a reason: `// TODO: replace once Z is resolved`

## Naming
- Self-documenting names — a reader should know what a thing does without opening it
- No single-letter variables outside loop counters
- No abbreviations unless domain-standard (e.g. `ctx`, `err`, `id` are fine; `usrMgr` is not)
- Booleans read as assertions: `isReady`, `hasError`, `canRetry`

## Functions
- Single responsibility — one function does one thing
- If you need a comment to summarize what a function does, split or rename it
- Prefer short functions; deep nesting is a sign of missing extraction
- Side effects should be obvious from the name or signature

## Files
- One concept per file
- Filename should make its contents guessable without opening it
- Group files by feature or domain, not by type (e.g. `user/` not `models/`, `handlers/`, `utils/`)

## Dead Code
- Delete it — never comment it out
- If it might be needed later, that's what git is for

## Error Handling
- Explicit and visible — no silent swallows
- Errors should propagate with context so the call site can understand what failed
- Don't log *and* return an error — pick one

## Dependencies
- Prefer stdlib
- Add a package only when the benefit clearly outweighs the cost of the dependency
- Pin versions explicitly

## General
- No magic numbers — name constants
- Fail fast: validate inputs at the boundary, trust internals
- Consistency beats cleverness — follow the patterns already in the codebase
