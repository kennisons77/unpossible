# Agentic Context Management — Research

How coding agent harnesses structure specification and context files to keep LLM
context windows tight but expandable on demand.

## Research Pass — 2026-04-20

### 1. Cursor Rules (.cursorrules → .cursor/rules/)

**Pattern:** Cursor migrated from a single `.cursorrules` file (project root, always loaded)
to a directory-based system `.cursor/rules/` with per-file metadata:

```markdown
---
description: "React component conventions"
globs: ["src/components/**/*.tsx"]
alwaysApply: false
---

Use functional components with hooks...
```

Three loading modes:
- `alwaysApply: true` — injected into every request (like a system prompt)
- `alwaysApply: false` + `globs` — loaded only when the user's active file matches the glob
- `alwaysApply: false` + `description` only — agent decides whether to load based on semantic match to the task

The glob-triggered conditional loading is the key innovation. The agent sees a manifest
of available rules (name + description, ~20 tokens each) and pulls full content only
when relevant. This is a two-tier system: cheap manifest always loaded, expensive body
loaded on demand.

**Who uses it:** Cursor (proprietary IDE). Community `.cursorrules` repos on GitHub
(cursor.directory) have thousands of examples.

**Novelty vs frontmatter + conditional loading:** The glob-based auto-trigger is more
automatic than manual frontmatter tags. The "description-only" mode where the agent
self-selects is genuinely novel — it's semantic routing without explicit tags.

---

### 2. Claude Code — CLAUDE.md

**Pattern:** A `CLAUDE.md` file at project root (and optionally in subdirectories) that
Claude Code reads automatically when entering a project. Supports:

- Project root `CLAUDE.md` — always loaded
- Subdirectory `CLAUDE.md` — loaded when working in that directory
- `~/.claude/CLAUDE.md` — user-global defaults

Content is free-form markdown. Anthropic recommends:
- Keep it under 1000 tokens for the root file
- Use imperative instructions ("Always use...", "Never...")
- Include build/test commands, code style, and project-specific conventions
- Avoid duplicating what's already in README or docs

The hierarchical override model (global → project → subdirectory) mirrors CSS specificity.
Subdirectory files can override or extend root-level instructions.

**Who uses it:** Claude Code (Anthropic's CLI agent). The pattern has been adopted by
other tools that detect and respect CLAUDE.md.

**Novelty:** The hierarchical directory scoping is simple but effective. Not novel
compared to your current approach (frontmatter + conditional loading), but the
"always short, always loaded" philosophy is a useful constraint. The key insight is
that the root file is a *routing document* — it tells the agent where to look, not
what to know.

---

### 3. Aider — Conventions Files

**Pattern:** Aider uses multiple mechanisms:

- `.aider.conf.yml` — tool configuration (not context)
- `CONVENTIONS.md` — loaded via `--read` flag or `/read` command
- `--map-tokens` budget — controls how much of the repo map is included
- Repo map — automatic AST-based summary of all files (function signatures, class names)

The repo map is Aider's key context innovation. It uses tree-sitter to parse every file
into a condensed signature map:

```
src/auth.py:
  class AuthService:
    def login(self, email: str, password: str) -> Token
    def refresh(self, token: Token) -> Token
```

This map is always loaded (budget-controlled) and gives the agent enough to know *what
exists* without loading *how it works*. The `--map-tokens` flag (default 1024) caps how
much of this map is included.

Read-only files (`--read`) are injected as full content but marked as non-editable.
This is used for conventions, API docs, or reference implementations.

**Who uses it:** Aider (open-source CLI agent).

**Novelty:** The AST-based repo map is genuinely novel compared to frontmatter. It's
an automatic "table of contents" that doesn't require manual annotation. The token
budget cap on the map is a practical solution to the "how much context" problem.

---

### 4. SWE-agent, OpenHands, Devon, Mentat

**SWE-agent (Princeton):**
- Uses a "thought-action-observation" loop with a fixed prompt template
- Context is managed via a sliding window over file content — the agent sees 100 lines
  at a time and must explicitly scroll/search
- No persistent project-level context files; everything is discovered per-task
- The key pattern: *restrict what the agent can see* to force deliberate exploration
- Uses "demonstrations" (few-shot examples) loaded conditionally based on task type

**OpenHands (formerly OpenDevin):**
- Microagent system: small markdown files that are conditionally triggered
- Three types: `repo` (always loaded for that repo), `knowledge` (keyword-triggered),
  `task` (spawned as sub-agents)
- Knowledge microagents have trigger keywords in frontmatter:

```yaml
---
name: docker-debugging
triggers: ["docker", "container", "dockerfile"]
---
When debugging Docker issues, always check...
```

- This is keyword-based routing — simpler than semantic but zero-cost to evaluate

**Devon (Cognition Labs / open-source fork):**
- Session-based context with explicit "knowledge base" that persists across tasks
- Uses a planning phase that produces a scratchpad (similar to your IMPLEMENTATION_PLAN.md)
- Context is managed by the orchestrator, not the agent — the agent requests what it needs

**Mentat:**
- Explicit file inclusion model — user specifies which files to include via CLI args
- Auto-context mode uses embeddings to find relevant files based on the task description
- Context is a flat list of included files, no hierarchy or conditional loading
- The embedding-based auto-include is their main innovation

**Novelty:** OpenHands' keyword-triggered microagents are the closest parallel to your
system. SWE-agent's deliberate restriction (force the agent to search) is a different
philosophy — less context upfront, more tool use. Devon's "agent requests what it needs"
is the pull model vs your push model.

---

### 5. Research & Blog Posts on Agentic Context Management (2025-2026)

Key findings from the discourse:

**"Context Engineering" (term coined ~early 2025):**
- Emerged as a discipline distinct from "prompt engineering"
- Focuses on *what information reaches the model and when*, not just *how it's phrased*
- Key practitioners: Simon Willison, Swyx, Anthropic applied team
- Core insight: the context window is a *database query result*, not a *document*

**Anthropic's prompt caching guidance (2025):**
- Place stable content at the beginning of the prompt (system prompt, reference docs)
- Place variable content at the end (current task, recent conversation)
- Cache breakpoints should align with content stability boundaries
- Recommended structure: `[cached system] [cached reference] [variable task] [variable conversation]`
- Cost reduction: cached tokens are 90% cheaper on read, 25% more expensive on first write
- Implication for file structure: separate "stable reference" files from "per-task" files

**Langchain/LangGraph patterns:**
- "Retrieval-augmented generation for code" — embed codebase, retrieve relevant chunks
- This has largely lost to AST-based approaches (Aider's repo map) for coding agents
- RAG works for documentation but not for code structure understanding

**Key blog posts / talks:**
- "Building effective agents" (Anthropic, 2025) — advocates for simple loops over complex
  orchestration, recommends keeping agent prompts under 4000 tokens
- "Context window management for coding agents" (various, 2025) — consensus that
  tiered loading (always/conditional/never) outperforms flat inclusion
- Swyx's "context engineering" posts — frames the problem as information architecture

---

### 6. Anthropic's Prompt Caching & Context Structuring

**Prompt caching mechanics:**
- Minimum cacheable block: 1024 tokens (Claude 3.5), 2048 tokens (Claude 3)
- Cache lives for 5 minutes, refreshed on each hit
- Structure prompts so the cacheable prefix is identical across requests

**Recommended layering for agents:**

```
Layer 1 (cached, stable):     System prompt + tool definitions
Layer 2 (cached, semi-stable): Project context (AGENTS.md equivalent)
Layer 3 (cached, session):     Current plan / task description
Layer 4 (uncached, variable):  Retrieved file content, conversation history
```

**Implication for file design:**
- Files that are "always loaded" should be written to be cache-friendly — stable text
  that rarely changes, positioned early in the prompt
- Files that change per-iteration (like activity logs) should be last
- This matches your current split: AGENTS.md (stable) vs IMPLEMENTATION_PLAN.md (variable)

---

### 7. "Context Engineering" as a Discipline

The term has solidified around these principles:

1. **Tiered relevance** — not all context is equally important at all times
2. **Pull vs push** — agent requests context (tool use) vs harness pushes context (injection)
3. **Summarization as compression** — replace verbose context with summaries, expand on demand
4. **Routing metadata** — cheap descriptors that help decide whether to load expensive content
5. **Budget awareness** — the harness tracks token spend and makes tradeoff decisions
6. **Temporal decay** — recent context is more relevant than old context

Applied to coding agents specifically:
- The "repo map" pattern (Aider) is the dominant solution for "what exists"
- Conditional file loading (Cursor rules, OpenHands microagents) is the dominant solution for "how to work here"
- Scratchpads/plans (Devon, your IMPLEMENTATION_PLAN.md) are the dominant solution for "what am I doing"

---

### 8. Tiered/Layered Context Patterns

Consensus pattern across tools (2025-2026):

| Tier | When loaded | Token budget | Examples |
|---|---|---|---|
| Always | Every request | 500-2000 | System prompt, project rules, build commands |
| Session | Start of task | 1000-4000 | Current plan, relevant specs |
| On-demand | Agent requests or glob matches | Variable | File content, API docs, error logs |
| Never (indexed) | Only via search | 0 until retrieved | Full codebase, historical logs |

**Key insight:** The "always" tier must be ruthlessly short. Every token there is paid
on every request. The ROI threshold is: "Would the agent make a mistake without this
on >50% of requests?" If not, move it to session or on-demand.

**Cursor's approach:** Always tier is `alwaysApply: true` rules. On-demand is glob-matched
or description-matched rules. Never tier is the rest of the codebase (accessed via tools).

**Your current approach:** AGENTS.md is always-loaded. Skills files have frontmatter
with `loaded_by` tags. This is equivalent to Cursor's system but with explicit actor
routing instead of glob matching.

---

### 9. File-Level Metadata for Agent Routing

Patterns observed:

**Frontmatter tags (your system, OpenHands):**
```yaml
---
name: feature-x
kind: concept
loaded_by: [build, plan]
---
```
- Pro: explicit, no ambiguity
- Con: requires manual maintenance, can drift

**Glob patterns (Cursor):**
```yaml
globs: ["src/components/**/*.tsx"]
```
- Pro: automatic, no per-file annotation needed
- Con: only works for file-path-based relevance, not semantic relevance

**Keyword triggers (OpenHands):**
```yaml
triggers: ["docker", "container"]
```
- Pro: cheap to evaluate, semantic-ish
- Con: brittle, requires anticipating all relevant keywords

**Embedding-based (Mentat, some RAG systems):**
- Pro: truly semantic, no manual annotation
- Con: expensive to compute, requires embedding infrastructure, less predictable

**Description-based self-selection (Cursor's newest mode):**
- The agent sees a one-line description and decides whether to load
- Pro: semantic without embeddings, leverages the LLM's own judgment
- Con: costs tokens for the decision, can be inconsistent

**Emerging consensus:** Hybrid approaches win. Use globs for obvious structural matches,
keywords for domain-specific knowledge, and descriptions for ambiguous cases. Your
`loaded_by` tag is a manual version of what these systems automate.

---

### 10. Token Budget Management

**How harnesses decide what fits:**

**Fixed allocation (Aider):**
- `--map-tokens 1024` — hard cap on repo map
- Remaining budget goes to file content and conversation
- Simple, predictable, but doesn't adapt to task complexity

**Priority queue (SWE-agent, some enterprise tools):**
- Each context item has a priority score
- Fill the window from highest to lowest priority until budget exhausted
- Priority = recency × relevance × stability

**Adaptive (emerging pattern, 2025-2026):**
- Start with minimal context
- If the agent asks clarifying questions or makes errors, inject more
- "Context on failure" — only expand when the agent demonstrates it needs more
- This is the pull model taken to its extreme

**Summarization cascades:**
- When context exceeds budget, summarize older/lower-priority items
- Keep full text for the 2-3 most relevant files, summaries for the rest
- Anthropic's recommendation: use a cheaper/faster model to generate summaries

**Your current approach (cost.md):**
- Subagent caps (≤3 subagents, ≤5 turns) are a form of budget management
- Activity log trimming (last 10 entries) is temporal decay
- The "stable vs variable" split aligns with cache-friendly structuring

---

### Sources

| Title | URL | Type | Relevance |
|---|---|---|---|
| Cursor Rules Documentation | https://docs.cursor.com/context/rules | article | Glob-based conditional context loading |
| Claude Code CLAUDE.md docs | https://docs.anthropic.com/en/docs/claude-code | article | Hierarchical project context |
| Aider Repository Map | https://aider.chat/docs/repomap.html | article | AST-based automatic context generation |
| OpenHands Microagents | https://docs.all-hands.dev/modules/usage/microagents | article | Keyword-triggered context injection |
| SWE-agent paper (Yang et al.) | https://arxiv.org/abs/2405.15793 | standard | Restricted-view context philosophy |
| Anthropic Prompt Caching | https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching | article | Cache-friendly prompt structuring |
| "Building Effective Agents" (Anthropic) | https://www.anthropic.com/research/building-effective-agents | article | Agent architecture recommendations |
| Mentat auto-context | https://github.com/AbanteAI/mentat | library | Embedding-based file selection |
| Devon knowledge base | https://github.com/entropy-research/devon | library | Session-persistent context |

---

### Synthesis: What's Novel vs Your Current System

Your system (frontmatter + `loaded_by` + tiered files) is already in the top quartile
of sophistication. Specific gaps and opportunities:

| Their pattern | Your equivalent | Gap |
|---|---|---|
| Cursor glob-triggered rules | `loaded_by` tags | You require manual tagging; globs would auto-route based on which files the agent is editing |
| Cursor description-based self-selection | Skills file list with descriptions | You already have this in the context entry format — agent sees name + description, loads on demand |
| Aider repo map | None | You have no automatic "what exists" summary. A tree-sitter-based map would reduce exploratory tool calls |
| OpenHands keyword triggers | None explicit | Your `loaded_by: [build, plan]` is actor-based, not content-based. Adding keyword triggers could help for cross-cutting concerns |
| Anthropic cache layering | Implicit in your stable/variable split | Making cache boundaries explicit in agent configs would reduce cost |
| Adaptive context (load on failure) | Subagent caps | You cap cost but don't adaptively expand context when the agent is stuck |
| Activity log trimming | Already implemented | You're ahead here |

**Highest-value additions:**
1. **Repo map** — automatic AST summary, always loaded, capped at ~1000 tokens
2. **Glob-based rule activation** — for rules tied to file types/paths
3. **Explicit cache boundary markers** — in agent configs, mark where the cache prefix ends
4. **Description-only manifests** — for large spec collections, load only the TOC and let the agent pull

---

### Open Questions Remaining

- How does Cursor handle conflicts between multiple glob-matched rules? Priority system?
- What's the measured token savings of Aider's repo map vs naive file inclusion?
- Has anyone benchmarked "agent self-selects context" vs "harness selects context" on coding tasks?
- What's the failure mode when keyword triggers miss? (OpenHands likely has data on this)
- How do teams maintain glob patterns as codebases evolve? Drift problem?
