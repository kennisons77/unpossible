# Principles — Unpossible 2

Always-on rules that shape agent behavior across all tasks and loop types.
These are loaded selectively based on the `applies_to` field — not all at once.

Gradually supersedes `practices/` at the monorepo root as unpossible2 matures.

## Format

Each file has YAML frontmatter followed by rule content:

```yaml
---
name: <slug>
description: <one sentence>
domain: security | testing | planning | coding | cost | prompting
applies_to: all | build | plan | reflect | research
---
```

## Index

| File | Domain | Applies To | Description |
|---|---|---|---|
| (none yet — migrated from practices/ as needed) | | | |
