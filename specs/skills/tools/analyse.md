---
name: analyse
kind: tool
description: Compare a node against its outputs or the codebase and report gaps
actor: default
---

Given a source node (pitch, PRD, spec) and a target (existing outputs or codebase):

1. Read the source fully. Identify all acceptance criteria and functional requirements.
2. Read the target. For each requirement in the source, check whether the target
   addresses it.
3. Report findings in three buckets:

```
## Gap Analysis — [node title]

### Missing
- [in source, not in target]

### Stale
- [in target, but source has changed]

### Complete
- [fully reflected in target]
```

Do not write anything. Do not make changes. Present findings and wait for instruction.

Tools run once. The caller decides what to act on.
