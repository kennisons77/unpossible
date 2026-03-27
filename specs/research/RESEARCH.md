# Unpossible2 — Research & Planning Notes

> Collected via interview 2026-03-27. Drives the first ralph planning loops.

---

## Core Principles

- **Reliability.** The system must behave predictably. Failures are caught, logged, and recoverable. Nothing silently breaks.
- **Flexibility.** Components are replaceable. LLM providers, databases, sandbox runtimes — none are locked in.
- **Simplicity.** Build the simplest thing that works. No pre-optimisation. Optimise only when there is evidence it's needed.
- **Adaptability.** The system improves itself over time — both how it runs agent loops (prompt quality, tool selection, cost) and the quality of what it produces. Evidence from every loop feeds back into future loops.
- **Determinism over magic.** The system should have an explicit understanding of what it's doing at each step. Don't rely on LLM autonomy where a defined structure will do.
- **MD files as source of truth.** Human-readable specs and research docs remain the canonical layer. The database is a query/retrieval layer on top, not a replacement.
- **Security by default.** Never expose secrets or PII to LLMs or external systems.

---

## Ralph Loop Types

Four loop types, each with a distinct purpose:

| Loop | Purpose |
|------|---------|
| **Plan** | Break down a goal into tasks, load relevant context from the knowledge base, produce a structured plan |
| **Build** | Execute a task — write code, generate a spec, produce an artifact — using a constrained tool set |
| **Review** | A second LLM verifies the output of a build loop against the task definition and acceptance criteria |
| **Reflect** | Periodically analyse accumulated loop evidence (costs, errors, review feedback, tool performance, product outcomes) and propose improvements to the system itself |

The reflect loop targets two things:
1. **How the system runs** — prompt templates, tool selection rules, cost efficiency, task schema structure
2. **What the system produces** — patterns in what works across builds, fed back into future planning and building

Reflect loop output is a proposed change (to config, specs, or code) that goes through the normal plan/build/review cycle before being applied. The system improves itself but never bypasses its own backpressure.

A framework for storing research data and ideas, and developing modular pieces — first for unpossible2 itself, then for its projects.

This requires:
1. A knowledge base with efficient context retrieval (vector store + MD files)
2. A data schema to drive agent asks (task-driven, provider-aware)
3. An agent sandbox (Docker/K8s, starting simple)
4. A granular agent state machine (deterministic tool selection, producer/reviewer pattern)
5. Analytics tracking LLM interactions and costs

---

## 1. Knowledge Base & Context Retrieval

### Approach
- MD files remain the source of truth and human-readable layer
- Postgres + pgvector as the vector store (already used in geneAIe via `pgvector/pgvector:pg16`)
- Git-based change detection drives re-indexing — only re-embed files that have changed
- No scraping. Links are stored as references (URL + description) and passed to the LLM as-is

### Embedding Unit
Paragraph/section level — semantic boundaries within MD files, not whole files or individual sentences.

### Content Types
- MD files (specs, research, practices, pitches)
- Plain text notes
- Link references (URL + metadata, no fetched content for now)
- Documents (future)

### Library Item Lifecycle
Each item has a `parent_id` (the feature/product/research context it belongs to). When a parent is removed, the UI offers three options:
- Cascade delete the library items
- Archive them
- Reassign to another context

This is triggered as an async background job on parent deletion (dependent-destroy pattern).

### Path to Multi-Tenancy
Local-first with Postgres in k3s. Schema includes `org_id` / `tenant_id` from day one so the migration path is additive, not structural.

---

## 2. Task Schema (Driving Agent Asks)

### Goal
The task record — not the LLM — determines what tools are available and how the ask is structured. The LLM receives a tailored, constrained prompt specific to the provider being used.

### Task drives:
- Which tools are in scope (e.g. "write code" → file tools + sandbox; "research" → search + knowledge base)
- Which LLM provider and model to use
- The prompt template, shaped for that provider's strengths
- The reviewer LLM (if applicable)

### Agent I/O Storage
Every agent interaction is stored: input prompt, output, model used, token counts, cost estimate, task reference. This enables:
- Resumption of interrupted sessions
- Cost analysis per task type
- Avoiding repeat calls for known results ("don't ask what we already know")

---

## 3. Sandbox

### Current State
geneAIe has a working Docker Compose sandbox: Rails app + Postgres (pgvector) + MinIO. Solid for local dev but it's an app container, not an agent execution container.

### Plan
- Keep Docker Compose for local development
- Run k3s locally (already used in Loom's infra)
- Build a thin agent execution image — just the tools the agent needs, not a full app stack
- Add a simple job dispatcher that creates/destroys containers per agent run
- Migrate to full K8s pod provisioning (Loom Weaver-style) once the agent state machine and I/O schema are stable

### Why not go straight to Weaver-style K8s?
Full Weaver requires: K8s pod provisioning API, WireGuard tunnel for agent I/O routing, SPIFFE-style secret injection. That's significant infrastructure before there's anything to run in it. Build the agent first.

---

## 4. Agent State Machine

### Concurrency
- Main agents: single-threaded for now
- Subagents: concurrent (spawned by a main agent for parallel subtasks)

### Producer / Reviewer Pattern
- One LLM produces output (code, analysis, plan)
- A second LLM reviews/verifies it
- These can be different providers/models
- Review happens after production completes — no mid-stream interruption for now (no pre-optimisation)

### Tool Selection
- Deterministic: the task schema specifies the allowed tool set
- The LLM selects from that constrained set, not the full registry
- Prompts are tailored per provider — the same task may be asked differently to Claude vs GPT vs a local model

---

## 5. Analytics & Cost Tracking

Per agent run, store:
- Model used (provider + model name)
- Input token count
- Output token count
- Estimated cost
- Task reference
- Timestamp + duration

This is sufficient for the first loops. Richer analytics (dashboards, aggregation, experiment tracking) come later.

---

## Decisions Made

### Language & Framework
**Ruby on Rails.** Familiar, well-documented, rich out-of-the-box features (Active Job, Action Cable, ORM). LLM latency dominates over Ruby throughput concerns. Go remains a candidate for extracting hot-path components later if needed.

### Modularity Pattern
**Monorepo with namespaced modules**, not Rails engines. Each module owns its models, services, jobs, and controllers under `app/modules/{name}/`. Cross-module calls go through a public service interface. Mirrors Loom's strict layer separation without the engine overhead.

Proposed module structure:
```
app/modules/
  knowledge/    # vector store, indexing, library items, link references
  tasks/        # task schema, agent asks, tool set definitions
  agents/       # state machine, producer/reviewer pattern, subagent dispatch
  sandbox/      # container lifecycle, job dispatcher
  analytics/    # cost tracking, LLM I/O storage, token counts
```

### Embedding Model
**OpenAI `text-embedding-3-small`** to start — cheap, fast, simple API. The embedder is a swappable service behind an interface so Ollama can replace it later (when hardware allows) as a config change, not a rewrite.

### Indexer Process
To be decided in planning loop — likely a Rails background job (Active Job) triggered by git change detection, not a standalone service.

### Task Schema Creation
To be decided in planning loop — likely manually authored MD parsed into DB initially, with a UI form added later.
