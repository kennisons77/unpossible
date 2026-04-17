# Research: Jupyter Notebooks as Design Documents

**Status:** Proposed
**Created:** 2026-04-17

## Purpose

Investigate using Jupyter notebooks as executable design documents that sit between PRDs and specs in the project hierarchy. Notebooks can contain animated flowcharts, data model tables, UI mockups, and API contract examples — all runnable and verifiable, not just illustrative.

## Why This Matters

Markdown specs describe what the system does. A notebook spec *demonstrates* it. The gap between "the data model has these columns" and seeing a populated table with sample joins is the gap between description and shared understanding. Notebooks close that gap for both human-to-human and human-to-LLM communication.

## What a Design Notebook Contains

- **Flowcharts and state machines** — Python `diagrams` library or Mermaid via `IPython.display`. Animate transitions with ipywidgets.
- **Data model tables** — define schema as a dataframe, render it, generate sample data showing what tables look like populated. Show joins, query results, edge cases.
- **UI mockups** — HTML/CSS/JS cells render directly in the notebook. Prototype dashboard cards, table layouts, form flows. Not production code — enough to reach shared understanding.
- **API contract examples** — construct sample request/response payloads, validate against JSON schema, show output inline. The spec is also the test.
- **Cost and capacity models** — calculate token costs, storage estimates, batch sizes with real formulas that update when assumptions change.

## How It Fits the Reference Graph

A notebook is a file in git. The parser treats it like any other artifact:

- **Node type:** `design_notebook` → generative answer (same category as PRDs)
- **Frontmatter convention:** a markdown cell at the top with `spec:` and `task:` references matching existing conventions
- **Parser behavior:** extract metadata cell only — no need to execute the notebook

Position in the hierarchy:

```
Project → Pitch → PRD → Design Notebook → Specs → Implementation Plan → Code
```

## Known Edges

| Concern | Mitigation |
|---|---|
| Notebook JSON diffs are noisy | `nbstripout` strips output before commit; `nbdime` provides semantic diff |
| Agent can write but not run notebooks in sandbox | Agent authors the `.ipynb`, developer runs it locally to verify. Acceptable for Phase 0. |
| Web UI rendering | `nbconvert` renders notebooks as HTML. Adds a dependency to Component 5 (web UI). |
| Token cost for context loading | Notebook JSON is heavier than markdown. Use skill-style progressive loading — metadata only until needed. |
| Claude authoring quality | Claude can generate valid `.ipynb` files. Quality of diagrams and mockups needs empirical testing. |

## Recommended Next Steps

1. **Manual trial** — next time a module needs design (e.g., analytics dashboard 11.2), have Claude generate a `.ipynb` with data model tables, sample queries, and an HTML dashboard mockup. Run it in Jupyter. Evaluate whether it accelerates shared understanding.
2. **If valuable** — add `design_notebook` as a node type in `specs/system/reference-graph/spec.md` and define the frontmatter convention.
3. **If worth formalizing** — create a `design` skill (`specs/skills/workflows/design.md`) that produces notebooks alongside or instead of PRDs.

## Open Questions

| Question | Notes |
|---|---|
| Which Python libraries should be standard for design notebooks? | Candidates: `diagrams`, `itables`, `ipywidgets`, `pandas`. Keep the dependency set small. |
| Should notebooks be committed with or without output? | Without (via `nbstripout`) keeps diffs clean but requires re-running. With output preserves the rendered state for readers who don't have Jupyter. |
| Can the sandbox eventually run notebooks? | A Jupyter kernel in the Docker sandbox would let the agent author and verify in one step. Future enhancement. |
| How do notebooks interact with spec drift detection? | Content hashing would need to operate on the input cells only (not output), or use `nbstripout` as a pre-hash step. |
