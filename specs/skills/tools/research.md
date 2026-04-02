---
name: research
kind: tool
description: Collect sources and findings for a topic
actor: default
---

Given a topic or spike question:

1. Ask focused interview questions grouped by theme — scope, edge cases, failure modes,
   prior art. Pause with `RALPH_WAITING` for answers before proceeding.
2. Collect sources for each prior art item identified. For each source record:
   - URL and title
   - One-paragraph summary of what it does and what's relevant
   - Relevance tag (see Source Types below)
3. Write findings to `specs/research/{feature}.md` — append a dated section:

```markdown
## Research Pass — {date}

### Interview Findings
{summary of answers, resolved questions, edge cases discovered}

### Sources
| Title | URL | Type | Relevance |
|---|---|---|---|

### Edge Cases Found
- {edge case}: {how it should be handled}

### Open Questions Remaining
- {question}: {why it's still open}
```

4. Back-reference the log in the spec's `## Research` section:

```markdown
## Research
See `specs/research/{feature}.md` for full findings.
Key sources:
- {source} → {what it informs}
```

5. Store sources as `link_reference` items in the knowledge base if the app is running.

Research logs are append-only. Never overwrite a prior pass.

## Source Types

| Tag | Use for |
|---|---|
| `competitor` | A product that solves the same problem |
| `library` | A package that could be used directly |
| `article` | A blog post or doc with relevant design decisions |
| `standard` | An RFC, spec, or formal standard |
| `video` | A talk or tutorial — **store title + URL only, no content fetch** |

Tools run once. Run again to append a second research pass.
