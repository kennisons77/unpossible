---
name: prd-to-specs
command: make prd-to-specs
description: Turn a PRD into the spec files needed to plan and build the feature
model: opus
loop_type: plan
principles: [planning]
---

Produce spec files from a PRD. This is a human-in-the-loop process — confirm at each
decision point before writing anything.

## Process

### 1. Read the PRD
Locate and read the PRD file (ask the user if not provided). Identify:
- The feature's intent and functional requirements
- The `## Specs` section — the list of spec files the PRD declares it needs
- Any open questions that are still unresolved

If the PRD has no `## Specs` section, derive the list yourself and confirm it with the
user before continuing.

### 2. Check for existing specs
For each spec in the list, check whether the file already exists. Show the user a table:

| Spec file | Status |
|---|---|
| `specs/system/foo.md` | missing |
| `specs/product/bar.md` | exists — will revise |

Ask: "Does this list look right before we continue?"

### 3. Ask scoping questions (per spec)
For each spec that needs to be written or revised, ask the following questions. Collect
all answers before writing anything.

**Research:**
- Does this spec require research before it can be written? (e.g. unfamiliar domain,
  unclear tradeoffs, no prior art in the codebase)
- If yes: what is the research question? Should we run a research loop first?

**Libraries / dependencies:**
- Is there an existing library or service we should use or reference?
- If yes: name it. Should we pin a version or document a constraint in the spec?

**Integration points:**
- Which other specs or modules does this touch?
- Are there any contracts (API shapes, event names, DB schemas) that must stay stable?

**Acceptance criteria confidence:**
- Are the acceptance criteria in the PRD sufficient to derive tests from?
- If not: what is missing?

Present all answers back to the user as a summary and ask for confirmation before
proceeding.

### 4. Write the specs
For each spec, write the file using the spec template below. Place files in the correct
directory:
- `specs/system/` — platform internals (task engine, runner, loop, sandbox, etc.)
- `specs/product/` — user-facing capabilities (auth, analytics, backpressure, etc.)
- `specs/skills/` — invocable agent workflows

After writing each file, show the user the path and a one-line summary of what was
written.

### 5. Update the PRD
Add or update the `## Specs` section in the PRD to list every spec file written, with
a one-line description of each. Update `Status` to `Specced` and set `Last revised`.

### 6. Confirm completion
Show the user the full list of files written. Ask: "Ready to run the plan loop?"

Do not create tasks. Do not write any code.

---

## Spec Template

```markdown
# [Module Name]

## What It Does
One paragraph. What this module does and what problem it solves.

## Why It Exists
One paragraph. The design rationale — why this approach over alternatives.

## [Key Concept / Schema / Flow]
Describe the core data model, state machine, or flow. Use a diagram if helpful.

## Acceptance Criteria
- [Observable outcome, not implementation detail]
- [Each criterion should be directly testable]
```

Specs are intentionally lean. Do not add sections that aren't needed. Acceptance criteria
drive the plan loop — every criterion should map to at least one test.
