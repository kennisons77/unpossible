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
- Group files by feature or domain at the top level (e.g. `modules/analytics/` not
  a flat `models/`, `services/`, `utils/`). Within a feature module, framework
  conventions (models/, services/, controllers/) are acceptable — the module boundary
  is the feature boundary

## Dead Code
- Delete it — never comment it out
- If it might be needed later, that's what git is for

## Error Handling
- Explicit and visible — no silent swallows
- Errors should propagate with context so the call site can understand what failed
- Don't log *and* return an error — pick one
- **Fail-open vs fail-closed** — know which category each operation falls into.
  Core workflow steps (tests, migrations, LLM calls) fail closed: a failure stops
  progress. Infrastructure side-effects (activity log writes, lint checks, audit
  events) fail open: a failure is logged and the main flow continues. If you're
  unsure which category something is, it's fail-closed until proven otherwise

## Dependencies
- Prefer stdlib
- Add a package only when the benefit clearly outweighs the cost of the dependency
- Pin versions explicitly

## Refactoring vs Rewriting

A refactor is a behavior-preserving transformation — same inputs, same outputs, better
structure. If the change can break something, it's a rewrite. Call it what it is.

A rewrite is a bet: you're wagering that the new code will be better enough to justify
the risk of breaking what works. Before proposing one, answer:

1. What's the concrete problem with the current code? ("messy" is not a problem)
2. What breaks or gets harder if we leave it alone?
3. What's the blast radius if the rewrite introduces a bug?
4. Is there a smaller, behavior-preserving refactor that gets 80% of the benefit?

If you can't answer #1 and #2 with specifics, don't touch it. Working code that looks
ugly is better than clean code that doesn't work.

LLMs are biased toward rewrites — they optimize for "clean" over "safe". Resist the
urge to rewrite a module just because you'd write it differently from scratch. The
review loop proposes refactor beats; the human decides which bets are worth taking.

Reference: [That's Not Refactoring](https://www.codewithjason.com/thats-not-refactoring/)

## Code Navigation

Prefer LSP-powered tools (`code` tool) over grep for navigating code:
- Finding where a method is defined → `goto_definition`, not `grep "def method_name"`
- Finding all callers of a method → `find_references`, not `grep "method_name"`
- Understanding a class interface → `get_document_symbols`, not reading the whole file
- Checking types or signatures → `get_hover`, not scanning for comments

Grep is for literal text in comments, config values, and non-code patterns. If you're
searching for a symbol name, use the code tool first. Fall back to grep only when LSP
is unavailable or returns no results.

This matters for cost: `find_references` returns precise locations. Grep returns every
line containing the string, including false positives in comments, strings, and unrelated
code — each of which costs tokens to read and discard.

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
