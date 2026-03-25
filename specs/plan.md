# Plan — unpossible

## Goals

- BATS test harness running in Docker for all shell scripts
- `new-project.sh` scaffold
- Feature-scoped spec organisation (`specs/features/`)
- Structured work log (ticket-style WORKLOG.md, UI-friendly)
- Idea parking lot with research and promote commands
- Agent code review loop (build → review chaining)
- Project dashboard: local web UI + API that surfaces project goals, UAT/acceptance criteria, and worklog as browsable collections (no external services — parses unpossible markdown)
- Metrics system: local-first, Prometheus-shaped instrumentation covering loop iteration cost, context size, lines changed, and LLM call count; unpossible itself is the proving ground; the agent scaffolds the same pattern into new projects automatically
- Improvement mode: agent reads unpossible's own prompts/practices, researches open-source agentic frameworks and published best practices, and proposes changes as a PR; every proposed change must include an improvement hypothesis and a metric that verifies it — no change for change's sake
- External benchmarking: improvement mode can ingest OSS framework repos and articles, compare their approaches to unpossible's model, and surface only changes that fit our constraints and have a verifiable hypothesis
- Failure analysis & prompt learning: structured LLM interaction logging (prompt, agent/model, truncated response, commit SHA) enables post-mortem tracing of production bugs or test failures back to the planning/build phase that introduced them; findings drive targeted refinements to prompts and practices, proposed as PRs with the same hypothesis-plus-metric requirement as improvement mode
