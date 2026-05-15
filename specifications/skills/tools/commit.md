---
name: commit
kind: tool
description: Atomically commit code, append LEDGER.jsonl status event, and update IMPLEMENTATION_PLAN.md
actor: default
runs: once
principles: [version-control]
---

Commit a completed beat atomically: code changes, ledger event, and plan checkbox in
one git commit. The agent never runs raw `git commit` for beat completions — it always
goes through this skill.

## When to Use

After all acceptance criteria for a beat are green (tests pass, typechecks pass,
lints pass). Invoked as step 9 of the build loop.

## Steps

1. Confirm the working tree has staged or unstaged changes to commit. If nothing to
   commit, output `RALPH_WAITING: nothing to commit for beat {ref}`.

2. Stage code changes:
   ```bash
   git add <changed files>
   ```
   Do not use `git add -A` — stage only files relevant to the beat.

3. Run the controlled commit script:
   ```bash
   scripts/controlled-commit.sh \
     --ref "{task_ref}" \
     --from in_progress \
     --to done \
     --reason "tests green, {N} examples 0 failures" \
     --message "{beat title}

   - {what changed}
   - {why — the spec or acceptance criterion it satisfies}"
   ```
   The script appends a `status` event to LEDGER.jsonl, updates the IMPLEMENTATION_PLAN.md
   checkbox from `[ ]` to `[x]`, stages both files, and commits. The commit message
   "why" line is mandatory.

4. Optionally attach rich context as a git note (reasoning, flowcharts, screenshots):
   ```bash
   git notes add -m "{extended reasoning or review context}" HEAD
   ```
   Git notes are pushed separately: `git push origin refs/notes/*`.

## Failure Handling

If `git commit` fails, the script exits 2. The LEDGER.jsonl append is idempotent —
a retry will skip the duplicate entry. Fix the underlying issue and re-run.

## What This Skill Does NOT Do

- Does not push. Push is a separate step after the beat is committed.
- Does not create branches. The build loop creates `ralph/{timestamp}` branches.
- Does not handle `pr_opened`, `pr_review`, or `pr_merged` events — those are the
  `pr` skill's responsibility.

## Reference

- Script: `scripts/controlled-commit.sh`
- Tests: `scripts/test-controlled-commit.sh`
- Ledger format: `specifications/system/reference-graph/concept.md#file-schemas`
