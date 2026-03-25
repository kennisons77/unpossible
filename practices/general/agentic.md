# Agentic Development Practices

## The Cost Model Has Flipped

Writing code is now near-free. The scarce resource is **comprehension** — loading context, navigating indirection, diagnosing failures. Every practice here optimizes for comprehension cost, not writing cost.

## Legibility

- One file, one concept. If you need to load 5 files to understand one behavior, the code is under-decomposed.
- Prefer explicit duplication over wrong abstractions. N copies the AI can update in one pass cost less than one abstraction that forces context-chasing.
- Abstract only when the boundary is proven stable AND the abstraction reduces context load — not on sight of duplication. When in doubt: duplicate.
- Smaller files = cheaper parallel reasoning sessions, better git blame, easier isolation. Cap at ~200 lines; split by concept when exceeded.

## Code Structure
- If a function or module has exactly one caller, inline it — don't abstract for its own sake.
- A logical change should touch ≤3 files. More is a signal of wrong decomposition.
- Names should be grep-friendly: specific enough that searching returns ≤5 results. Avoid `handler`, `manager`, `util`, `helper` — they accumulate unrelated code.

## Specs and Prompts

- Write specs for the reader who has zero prior context. Every spec loads fresh into a new context window.
- One spec per activity (verb, not noun). `upload-photo.md` not `image-system.md`.
- Acceptance criteria are observable outcomes, not implementation details.
- Keep spec files lean — every byte loads every iteration. Brevity compounds.
- Use Markdown over JSON for agent-readable files — it tokenizes more efficiently.
- Prompts are load-bearing. Every word in a prompt is a constraint. Add lines surgically; never rewrite wholesale.

## Tests

- Tests are now free to write. Write exhaustive boundary cases, not minimal happy paths.
- A good test is **self-diagnosing**: it fails with a message that costs ~50 tokens to understand, not 2,000.
- No shared fixtures or DRY test helpers — hidden context is expensive. Each test must be independently understandable.
- Flaky tests are the most expensive class of defect in an agentic loop. Each flake burns 3,000–5,000 tokens on a non-defect. Eliminate them before running the loop at scale.
- Backpressure is the control mechanism: the agent cannot mark a task complete until tests pass.

## Commits
- One logical change per commit. Atomic commits make bisect and review tractable.
- Commit message: imperative verb + why, not what. "Fix race condition in auth refresh" not "update auth.go".
- Never commit a broken state — the loop commits only on green.

## Work in Progress

- The constraint is **alignment** (human judgment), not generation (AI output). Apply WIP limits to alignment decisions, not to what the AI builds.
- Cap active alignment decisions at 3–5. Teams running 15 parallel threads with no coherence tracking ship code nobody understands.
- The metric that matters: what percentage of human time is spent on alignment decisions vs. everything else.

## Review

- Reviews should ask "does this align with what we're trying to achieve?" not just "is the implementation correct?" — those are different questions.
- A second agent reviewing the first agent's work catches alignment drift before it compounds.

## Context Budget

- Claude's usable context is bounded. Every file loaded every iteration costs from that budget.
- Measure token cost of your spec and practices files. Keep them under 500 tokens each where possible.
- Kill any subagent exceeding 10 turns — it has lost the thread.
