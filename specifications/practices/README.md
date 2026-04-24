# Practices — Unpossible

Always-on rules that shape agent behaviour across all tasks and loop types.
Loaded selectively based on the task — not all at once.

See `specifications/system/practices.md` for the full loading rules.

## Frontmatter

Every practice file has YAML frontmatter. Skills (`specifications/skills/`) use a
different schema — both are documented here for comparison.

### Practice schema

```yaml
name:        slug                          # file stem, lowercase
kind:        practice                      # always 'practice'
domain:      Human-readable topic          # e.g. "Coding", "Threat modeling"
description: one-line summary              # what this practice is about
loaded_by:   all | human | [loop, ...]    # who loads this file
```

`loaded_by` values:
- `all` — injected into every agent config as a resource.
- `human` — never loaded by agents; human reference only.
- Array of loop names (`plan`, `build`, `review`, `research`) — loaded by those
  loops, either always or on demand. The distinction between always-loaded and
  on-demand is captured in `specifications/system/practices.md`, not in the
  frontmatter.

### Skill schema

```yaml
name:        slug                        # file stem, lowercase
kind:        tool | workflow | loop       # what it is
command:     how a human invokes it       # e.g. ./loop.sh [n]
description: one-line summary
actor:       default | plan | build | research | review
runs:        once | n | until <condition>
principles:  [practice, ...]             # optional — practices the skill references
tools:       [tool, ...]                 # optional — skills this skill composes
```

Skills are executable instructions — the schema drives dispatch. Practices are
reference material — the schema drives loading and drift detection.

## Index

| File                                       | Domain          | Loaded by                      |
|--------------------------------------------|-----------------|--------------------------------|
| [changeability.md](changeability.md)       | Changeability   | plan, review, build            |
| [coding.md](coding.md)                     | Coding          | review, build                  |
| [planning.md](planning.md)                 | Planning        | plan                           |
| [verification.md](verification.md)         | Verification    | plan, build                    |
| [automation.md](automation.md)             | Automation      | build                          |
| [cost.md](cost.md)                         | Cost            | all                            |
| [Developer.md](Developer.md)               | Developer       | all                            |
| [version-control.md](version-control.md)   | Version control | build                          |
| [security.md](security.md)                 | Security        | build                          |
| [threat-modeling.md](threat-modeling.md)    | Threat modeling | build                          |
| [lookup-tables.md](lookup-tables.md)       | Lookup tables   | build                          |
| [retry.md](retry.md)                       | Retry strategy  | build                          |
| [multi-tenancy.md](multi-tenancy.md)       | Multi-tenancy   | plan, build                    |
| [entrypoint-dispatch.md](entrypoint-dispatch.md) | Containers | build                          |
| [structural-vocabulary.md](structural-vocabulary.md) | Structural vocabulary | plan, review, build            |
| [structural-vocabulary-extended.md](structural-vocabulary-extended.md) | Structural vocabulary (extended) | plan, review (on demand) |
| [structural-vocabulary-README.md](structural-vocabulary-README.md) | Structural vocabulary overview | human |
| [glossary.md](glossary.md)                 | Glossary        | plan, review, build            |
| [decision-journal.md](decision-journal.md) | Decision journal | build                          |
| [LOOKUP.md](LOOKUP.md)                     | Reference       | all                            |
| [zed.md](zed.md)                           | Editor          | human                          |
