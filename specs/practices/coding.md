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

## Makefile Consistency

Any change to infrastructure (Dockerfiles, entrypoints, compose files, rake tasks, or
environment variables) must be checked against the Makefile. If the change affects how
services start, build, or run, update the corresponding Makefile target. The Makefile is
the developer's primary interface — if it's out of sync, the workflow is broken.

## Context Window Management (load-bearing decision)

When passing turn history to a provider, use the **pinned + sliding** strategy:

- Always include: system prompt, all `agent_question` and `human_input` turns
- Trim from oldest first: `llm_response` and `tool_result` turns
- If still over budget after trimming all non-pinned turns, abort with `RALPH_WAITING`

Rationale: human inputs are load-bearing — they represent decisions and clarifications
that cannot be reconstructed. Intermediate LLM responses are recoverable context; the
human thread is not. Never trim `agent_question` or `human_input` turns to fit a budget.
