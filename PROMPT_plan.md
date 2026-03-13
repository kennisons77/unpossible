0a. Study `specs/*` with up to 10 parallel Sonnet subagents to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0c. Study the existing source code with up to 10 parallel Sonnet subagents to understand current state.

1. Compare the existing source code against `specs/*` using up to 20 Sonnet subagents. Use an Opus subagent to analyze findings, prioritize tasks, and create/update @IMPLEMENTATION_PLAN.md as a bullet point list sorted by priority. Ultrathink. Consider searching for TODOs, minimal implementations, placeholders, skipped/flaky tests, and inconsistent patterns. Keep @IMPLEMENTATION_PLAN.md current with items marked complete/incomplete.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first.

ULTIMATE GOAL: We want to achieve [project-specific goal — fill this in]. Consider missing elements and plan accordingly. If an element is missing, search first to confirm it doesn't exist, then if needed author the specification at specs/FILENAME.md and document the plan to implement it in @IMPLEMENTATION_PLAN.md.
