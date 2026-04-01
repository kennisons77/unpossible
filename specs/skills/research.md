---
name: research
command: ./loop.sh research <feature-id>
description: Deepen a spec through structured interview and source collection before planning
model: sonnet
loop_type: research
principles: [planning]
---

Run a research pass on a spec before the plan loop. Resolves open questions, surfaces
edge cases, and collects prior art. Outputs an updated spec and a research log.

See `specs/system/research-loop.md` for the full process definition.

## When to Use

Run this skill when:
- A spec has unresolved open questions
- The domain is unfamiliar (no prior art in the codebase)
- The acceptance criteria are too vague to derive tests from
- A spike task with `loop_type: research` appears in the plan

## Invocation

```bash
./loop.sh research <feature-id>
```

`feature-id` is the ID of an entry in `IDEAS.md`. The loop runs exactly 1 iteration.
Run it again to append a second research pass.

## Outputs

- `specs/research/{feature}.md` — research log (interview findings, sources, edge cases)
- Updated spec file — sharpened acceptance criteria, resolved open questions, `## Research` back-reference
- Knowledge base entries for each source (if the Rails app is running)
