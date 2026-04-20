---
name: glossary
kind: practice
domain: Glossary
description: Canonical term definitions and tag slugs that connect artifacts
loaded_by: [plan, review, build]
---

# Glossary

Canonical term definitions for the Unpossible project. Each entry defines a tag slug
that can be used to connect artifacts across the system — concepts, requirements, plan
items, tests, LEDGER.jsonl entries, and commits.

Lives alongside `structural-vocabulary.md`. The glossary defines **what things are
called** (terms). The structural vocabulary defines **how things are shaped** (patterns).
The structural vocabulary can reference glossary terms; the glossary does not reference
patterns.

## How Tags Work

Any artifact can be tagged with one or more glossary slugs:

```markdown
<!-- tags: rate-limiting, api, security -->
## Rate Limiting
```

```markdown
- [ ] Implement rate limit middleware <!-- id: impl-rate-limit, tags: rate-limiting, api -->
```

```json
{"ts":"...","type":"status","ref":"impl-rate-limit","tags":["rate-limiting","api"],"from":"todo","to":"done"}
```

```ruby
RSpec.describe "Rate limiting", spec: "specifications/system/api/concept.md#rate-limiting", tags: ["rate-limiting"] do
```

Tags are complementary to IDs (precise pointers) and `spec:` metadata (precise links).
Tags provide conceptual grouping — "everything related to rate-limiting."

The reference parser collects tags across all artifact types and builds a conceptual
clustering layer in the graph.

## Future Vision

The glossary is not just a dictionary. It is connective tissue:

- **Practices extend glossary terms.** A practice file extends a term's definition with
  how that concept is implemented in this system. The parser infers these connections
  from content.
- **Tests are executable specifications.** They encode thinking, not just verify
  correctness. A test tagged with glossary terms and linked to concept sections via
  `spec:` is a first-class artifact in the chain.
- **The full chain:** `brief → concept → requirements → plan → code + tests → activity
  log → commit → PR`. Each link can be tagged with glossary terms, creating a
  conceptual layer that spans the entire development lifecycle.

## Loading

| Loop | Loaded |
|---|---|
| Plan | ✓ (same as structural-vocabulary.md) |
| Review | ✓ |
| Build | on demand |
| Research | no |

## Terms

### agent-runner
The module that executes agent loops — prompt assembly, provider dispatch, turn
recording, dedup, and observability.

### analytics
LLM cost tracking, product events, feature flag exposures, and audit logging.

### api
HTTP endpoints exposed by the system. Documentation, request testing, batch requests.

### audit-log
Append-only record of destructive or sensitive operations. Written by
`Analytics::AuditLogger`. Never raises, never blocks the caller.

### auth
Authentication and authorization — JWT tokens, sidecar auth, rate limiting.

### backpressure
Mechanisms that prevent work from proceeding until quality gates are met. Linters,
tests, review loops, feature flags with hypotheses.

### beat
The unit of work in the implementation plan. Produced by the plan loop from concepts
and gap analysis. Consumed by the build loop. A beat has a title, acceptance criteria,
and a deterministic ID. It is not written directly — it is the residue of concept +
requirements + gap analysis in agreement.

### brief
The ideology-level artifact. Why something exists and who it's for. Formerly "pitch."

### concept
The broad behavioral definition of a feature. What it does, acceptance criteria,
behavioral model. The source of truth for intent. Formerly "spec."

### deterministic-id
A content-derived identifier assigned to a plan item at creation time. Frozen once
assigned. Used by LEDGER.jsonl and cross-artifact tracing. Format:
`SHA256(normalize(title) + concept_path)[:12]`.

### feature-flags
Schema, lifecycle, and hypothesis requirements for feature flags.

### glossary
This file. Canonical term definitions and tag slugs.

### infrastructure
Docker, compose, deployment, health checks, networking.

### iteration
One pass through a loop. The build loop runs one iteration per beat. The plan loop
runs one iteration per gap-analysis pass. Each iteration is a separate agent invocation
with its own context window.

### ledger
`LEDGER.jsonl` — the append-only event log that records status transitions, blocks,
spec changes, and PR lifecycle events. One JSON object per line. Never modified or
deleted. The reference parser derives the project graph from it.

### loop
The execution model. A loop runs a workflow repeatedly until a condition is met.
Four loops: plan (produce beats), build (execute beats), review (find weaknesses),
research (collect sources). Each loop type has its own agent config, loaded practices,
and termination condition.

### platform-override
A runtime-specific implementation file that extends a core spec without repeating it.
Lives in `specifications/platform/{platform}/`. Declares `extends:` in frontmatter
pointing to the core spec it layers on.

### practice
An always-on discipline rule loaded by agents. Reference material, not executable.
Lives in `specifications/practices/`. Loaded selectively by loop type — not all at
once. Shapes agent behaviour without being part of the instruction.

### prompt-assembly
The process of combining skill instructions, practice context, agent config resources,
and conversation history into a provider-ready prompt. Owned by the agent runner.
Cache-aware — stable prefixes are cached, variable suffixes are appended.

### provider
An LLM API backend — Claude, OpenAI, or any future model service. The agent config
selects the provider; the skill instruction is provider-agnostic. Provider-specific
best practices live in `specifications/skills/providers/`.

### rate-limiting
Throttling requests to protect system resources. Implemented via rack-attack.

### reference-graph
The file-and-git-native system for tracking project state. Replaces the Postgres-backed
ledger. The parser derives relationships from files, git history, and LEDGER.jsonl.

### repo-map
An auto-generated AST-based summary of the codebase — class names, method signatures,
module boundaries — injected as agent context to reduce orientation cost. Token-budgeted.
See `specifications/system/repo-map/concept.md`.

### requirements
The precise technical translation of a concept into software patterns. Personas,
scenarios, functional requirements. Formerly "PRD."

### sandbox
Container lifecycle and Docker dispatcher for agent execution.

### security
Attack surface reduction, secret handling, PII filtering, prompt sanitization.

### skill
An executable instruction that tells an agent what to do. Model-agnostic. Three kinds:
tool (primitive, runs once), workflow (tools composed into a named output), loop
(workflow run until a condition is met). Lives in `specifications/skills/`.

### token-budget
A cap on context window usage for a specific resource or agent. Prevents any single
piece of context from consuming disproportionate tokens. Applied to repo maps, practice
loading, and subagent spawning.

### traceability
The ability to follow an artifact from concept through code to deployment. Cross-artifact
tracing via deterministic IDs, tags, git notes, and the reference parser.
