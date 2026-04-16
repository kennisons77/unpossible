# Lookup Tables

## What They Are

Lookup tables are Markdown tables that map key terms to their canonical locations —
spec files, module paths, API endpoints, model names. They are loaded once at the start
of a loop iteration and give the agent a precise index to navigate the codebase and
specs without broad file scanning.

## Why They Matter

Without a lookup table, an agent discovering an unfamiliar term does one of three things:
1. Scans the entire codebase — expensive
2. Guesses a file path — often wrong
3. Hallucinates an answer — silently wrong

A lookup table eliminates all three. A 20-row table costs ~200 tokens. The alternative
— loading multiple files to find the same information — costs 10–50×.

## Where Lookup Tables Live

| File                       | Contains                                        |
|----------------------------|-------------------------------------------------|
| `specs/README.md`          | Spec → module → loop type                       |
| `AGENTS.md`                | Build/run/test commands + key codebase patterns  |
| `specs/practices/LOOKUP.md` | Term → practices file + rule name               |
| `web/app/modules/LOOKUP.md` | Module name → path → public service interface   |

These are the four tables an agent needs at the start of any iteration.

## Format Rules

- **Term column** — the exact name an agent would search for
- **Location column** — shortest unambiguous path or reference
- **Purpose column** — one sentence: what it does, not what it is
- No nested tables. No prose between rows. Tables only.
- Keep rows alphabetical within each section

## Reference Style

Prefer concept references over path references in prose:

```
✓  "see the ledger spec"
✗  "see specs/system/ledger/spec.md"
```

Hard-coded paths belong only in lookup tables and `AGENTS.md`, where exactness is
required and the one-update rule (see `version-control.md`) keeps them current.

## Maintenance Rules

- Update the relevant lookup table in the same commit that adds the thing being indexed
- A class, spec, or rule that isn't in a lookup table effectively doesn't exist to the agent
- If an agent scans files to find something that should be in a lookup table, add it
- Lookup tables are maintained by hand or by the build loop as part of the task that
  creates the thing being indexed
