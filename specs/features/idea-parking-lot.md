# Feature: Idea Parking Lot

## Overview

A structured parking lot for ideas that aren't ready for implementation yet. Ideas can be researched, refined, and promoted to full specs when ready.

## Purpose

`IDEAS.md` provides a lightweight way to capture and track ideas before they become formal specs, enabling:
- Capture ideas without committing to implementation
- Research and validate ideas before promoting to specs
- Track open questions and decision points
- Audit trail of idea lifecycle (parked → researching → ready/rejected → promoted)

## Schema

Each entry in `IDEAS.md` follows this format:

```markdown
## [ID] Title

- **Status:** parked | researching | ready | rejected | promoted
- **Created:** YYYY-MM-DDTHH:MM:SSZ
- **Promoted:** YYYY-MM-DDTHH:MM:SSZ (or empty if not promoted)

### Description

What is this idea? What problem does it solve?

### Open Questions

- Question 1?
- Question 2?
```

### Field Definitions

- **ID**: Auto-incrementing integer starting at 1
- **Title**: Short description of the idea
- **Status**: Current state
  - `parked`: Captured but not yet researched
  - `researching`: Agent is actively investigating feasibility
  - `ready`: Research complete, ready to promote to spec
  - `rejected`: Research determined idea is not viable
  - `promoted`: Converted to a formal spec file
- **Created**: ISO 8601 timestamp when idea was added
- **Promoted**: ISO 8601 timestamp when promoted to spec (empty until promoted)
- **Description**: Markdown-formatted explanation of the idea and its purpose
- **Open Questions**: Bulleted list of unknowns to resolve during research

## Example

```markdown
## [1] Multi-language support in loop.sh

- **Status:** ready
- **Created:** 2026-03-24T17:00:00Z
- **Promoted:** 

### Description

Allow loop.sh to detect the project language from prd.md and load the appropriate practices/lang/<language>.md file automatically. Currently the agent must manually check for language-specific practices.

### Open Questions

- Should we fail if language is declared but practices file doesn't exist?
- How to handle multi-language projects (e.g. Go backend + TypeScript frontend)?
```

## Integration

### Research Mode

`./loop.sh research <id>` loads the idea, feeds it to an agent with `PROMPT_research.md`, and updates the status based on findings:
- Agent investigates feasibility, answers open questions
- Updates status to `ready` (viable) or `rejected` (not viable)
- Adds research findings to the Description section

### Promote Command

`./loop.sh promote <id>` converts a ready idea into a formal spec:
- Creates `projects/<name>/specs/<title-slugified>.md` with idea content
- Updates IDEAS.md entry status to `promoted` and sets promoted_at timestamp
- Exits non-zero if idea is not in `ready` status or already promoted
