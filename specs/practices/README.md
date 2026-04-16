# Practices — Unpossible

Always-on rules that shape agent behaviour across all tasks and loop types.
Loaded selectively based on the task — not all at once.

See `specs/system/practices.md` for the full loading rules.

## Index

| File                                       | Domain          | Loaded when                    |
|--------------------------------------------|-----------------|--------------------------------|
| [changeability.md](changeability.md)       | Changeability   | plan, review, build (on demand) |
| [coding.md](coding.md)                     | Coding          | review, build (on demand)      |
| [planning.md](planning.md)                 | Planning        | plan                           |
| [verification.md](verification.md)         | Verification    | plan, build (on demand)        |
| [automation.md](automation.md)             | Automation      | build (on demand)              |
| [cost.md](cost.md)                         | Cost            | all                            |
| [version-control.md](version-control.md)   | Version control | build                          |
| [security.md](security.md)                 | Security        | build (on demand)              |
| [threat-modeling.md](threat-modeling.md)    | Threat modeling | build (on demand)              |
| [lookup-tables.md](lookup-tables.md)       | Lookup tables   | build (on demand)              |
| [retry.md](retry.md)                       | Retry strategy  | build (on demand)              |
| [multi-tenancy.md](multi-tenancy.md)       | Multi-tenancy   | plan, build (on demand)        |
| [entrypoint-dispatch.md](entrypoint-dispatch.md) | Containers | build (on demand)              |
| [structural-vocabulary.md](structural-vocabulary.md) | Structural vocabulary | plan, review, build (on demand) |
| [zed.md](zed.md)                           | Editor          | human reference only           |
