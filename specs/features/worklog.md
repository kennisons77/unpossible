# Feature: Structured Work Log

## Overview

A machine-readable, human-friendly work log that tracks completed tasks with metadata for filtering and reporting.

## Purpose

`WORKLOG.md` provides a structured history of work completed by the agent, enabling:
- Progress tracking across iterations
- Filtering by status, feature, or time period
- Audit trail with commit references
- UI-friendly display via `scripts/worklog.sh`

## Schema

Each entry in `WORKLOG.md` follows this format:

```markdown
## [ID] Title

- **Status:** todo | in-progress | done
- **Feature:** <feature-name>
- **Started:** YYYY-MM-DDTHH:MM:SSZ
- **Completed:** YYYY-MM-DDTHH:MM:SSZ (or empty if not done)
- **Commit:** <commit-sha> (or empty if not committed)

### Summary

Brief description of what was done and why.
```

### Field Definitions

- **ID**: Auto-incrementing integer starting at 1
- **Title**: Short description of the task (from IMPLEMENTATION_PLAN.md)
- **Status**: Current state (todo, in-progress, done)
- **Feature**: Feature name from IMPLEMENTATION_PLAN.md section header
- **Started**: ISO 8601 timestamp when task began
- **Completed**: ISO 8601 timestamp when task finished (empty until done)
- **Commit**: Git commit SHA after successful completion (empty until committed)
- **Summary**: Markdown-formatted explanation of work done

## Example

```markdown
## [1] Document specs directory structure

- **Status:** done
- **Feature:** Spec Organisation by Feature
- **Started:** 2026-03-24T17:26:00Z
- **Completed:** 2026-03-24T17:28:00Z
- **Commit:** e5e0c68

### Summary

Created specs/README.md documenting directory structure, feature organization convention, and spec-writing guidelines. No tests required (documentation only).
```

## Integration

The build agent appends entries to `projects/<name>/WORKLOG.md` after each successful task completion, before marking the task done in `IMPLEMENTATION_PLAN.md`.
