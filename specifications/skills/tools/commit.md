---
name: commit
kind: tool
description: Atomically commit code, append LEDGER.jsonl, and update IMPLEMENTATION_PLAN.md
actor: build
runs: once
principles: [version-control]
---

Commit a passing beat atomically: code + LEDGER.jsonl + IMPLEMENTATION_PLAN.md in one
git commit. Never run `git commit` directly — always use this skill.

## When to Use

After tests pass for a beat. Once per beat — never bundle multiple beats.

## Steps

1. **Record in-progress in LEDGER.jsonl** — append a status event:
   ```json
   {"ts":"<ISO8601>","type":"status","ref":"<task_id>","from":"in_progress","to":"done","sha":null,"reason":"tests green"}
   ```
   Use `LedgerAppender` via Rails runner (idempotent — safe to retry):
   ```bash
   bundle exec rails runner "LedgerAppender.append({ts: Time.now.utc.iso8601, type: 'status', ref: '<task_id>', from: 'in_progress', to: 'done', sha: nil, reason: 'tests green'})"
   ```

2. **Update IMPLEMENTATION_PLAN.md** — mark the task complete:
   - Change `- [ ] <task_id>` → `- [x] <task_id>`
   - If the item has a `<!-- status: ... -->` comment, update `status: todo` or
     `status: in_progress` → `status: done`
   - If the box is already `[x]`, skip this step.

3. **Stage all files**:
   ```bash
   git add -A
   ```

4. **Commit** with structured message:
   ```
   {beat title}

   - {what changed}
   - {why — the spec or acceptance criterion it satisfies}
   ```
   The "why" line is mandatory. Example:
   ```
   Add BatchRequestMiddleware

   - Implements POST /api/batch fan-out and aggregation
   - Satisfies specifications/system/batch-requests.md#fan-out
   ```

5. **Record the commit SHA in LEDGER.jsonl** — append a second event with the SHA:
   ```bash
   SHA=$(git rev-parse HEAD)
   bundle exec rails runner "LedgerAppender.append({ts: Time.now.utc.iso8601, type: 'status', ref: '<task_id>', from: 'done', to: 'done', sha: '$SHA', reason: 'sha recorded'})"
   git add LEDGER.jsonl
   git commit --amend --no-edit
   ```
   The amend folds the SHA entry into the same commit. This is safe because the commit
   has not been pushed yet.

## Failure Handling

- If `git commit` fails: LEDGER.jsonl has an uncommitted entry. On retry, `LedgerAppender`
  idempotency skips the duplicate. Stage and commit again.
- If the Rails runner fails: check that `LEDGER.jsonl` is writable and `LedgerAppender`
  is loaded. Do not proceed to `git commit` until the append succeeds.
- If the amend fails: push the commit without the SHA entry. The reference parser
  tolerates missing SHA on `done` events — it resolves the SHA from git log by matching
  the task ref.

## What This Skill Does NOT Do

- Does not push. `loop.sh` handles push after `RALPH_COMPLETE`.
- Does not create branches. `loop.sh` creates `ralph/{timestamp}` branches.
- Does not open PRs. Use the `pr` skill after the loop run completes.

## Research

See `specifications/research/reference-graph-commit-skill.md` for full findings.
Key decisions:
- Skill file (not Ruby service or shell script) — agent already has bash tool access
- `LedgerAppender` for idempotent append — reuse existing code
- Two-event pattern for SHA recording — preserves append-only semantics
