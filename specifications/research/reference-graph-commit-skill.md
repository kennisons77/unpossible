# Reference Graph — Controlled Commit Skill

## Research Pass — 2026-04-22

### Interview Findings

The spike had three open questions. Answers derived from codebase analysis and the
reference-graph concept spec.

**Q1: How should the skill be invoked from the build loop?**

The build loop (kiro-cli chat) already runs git commands directly via bash tools. The
controlled commit skill is a *sequence of steps* the agent follows, not a separate
process. It should be documented as a skill (markdown instructions) that the build
agent executes step-by-step using its existing bash tool access. No subprocess or
wrapper needed.

The `loop.sh` already handles branch creation and git push. The skill fills the gap
between "tests pass" and "git push" — it ensures LEDGER.jsonl and IMPLEMENTATION_PLAN.md
are updated atomically with the code commit.

**Q2: Should it be a Ruby service, a shell script, or a standalone CLI?**

Neither. The controlled commit skill is a *skill file* (markdown instructions) that
the build agent follows. The agent already has bash tool access and can run git commands
directly. A Ruby service or shell script would add indirection without benefit — the
agent is the executor.

The only code component needed is `LedgerAppender` (already exists) for appending
LEDGER.jsonl entries. The IMPLEMENTATION_PLAN.md checkbox update is a text substitution
the agent performs with its file-editing tools.

**Q3: How to handle IMPLEMENTATION_PLAN.md checkbox updates atomically with git commit?**

Git's atomicity covers this: stage all files before committing. The sequence is:

1. Edit IMPLEMENTATION_PLAN.md (mark `[ ]` → `[x]`, update status comment)
2. Append LEDGER.jsonl entry via `LedgerAppender` (or direct file append)
3. `git add` code files + IMPLEMENTATION_PLAN.md + LEDGER.jsonl
4. `git commit` — all three land in one commit

If the commit fails (e.g. pre-commit hook rejects), none of the ledger/plan changes
are recorded. The agent retries from step 1. This is safe because `LedgerAppender`
is idempotent (skips duplicate lines).

The IMPLEMENTATION_PLAN.md item format from the concept spec uses inline HTML comments
for machine-readable metadata:
```markdown
- [x] 3.1 — Batch middleware <!-- status: done, spec: ..., test: ... -->
```
The agent's str_replace tool handles this substitution reliably.

### Sources

| Title | URL | Type | Relevance |
|---|---|---|---|
| Git atomicity (man git-commit) | https://git-scm.com/docs/git-commit | standard | Confirms single commit = atomic unit; all staged files land together or not at all |
| LedgerAppender (existing) | web/app/lib/ledger_appender.rb | library | Already implements idempotent append; reuse directly |
| reference-graph concept spec | specifications/system/reference-graph/concept.md | standard | Defines the atomic sequence and LEDGER.jsonl event schema |

### Edge Cases Found

- **Commit fails mid-sequence**: LEDGER.jsonl append happens before `git commit`. If
  commit fails, the LEDGER.jsonl file has an uncommitted entry. On retry, `LedgerAppender`
  idempotency skips the duplicate. The file is then staged and committed on the next
  attempt. No inconsistency.

- **Agent crashes between append and commit**: Same as above — idempotency handles it.
  The uncommitted LEDGER.jsonl entry is staged on the next run.

- **IMPLEMENTATION_PLAN.md already checked**: The agent should check before editing.
  If the box is already `[x]`, skip the edit. This prevents double-editing on retry.

- **Multiple tasks in one commit**: The spec says "one commit per passing beat"
  (version-control.md). The skill enforces this by design — it is invoked once per
  beat, not once per loop run.

### Open Questions Remaining

- **LEDGER.jsonl append from agent vs Ruby**: The agent can append directly via bash
  (`echo '...' >> LEDGER.jsonl`) or call `LedgerAppender` via a Rails runner. Direct
  bash append is simpler and has no Rails boot cost. However, `LedgerAppender` provides
  idempotency and type validation. Recommendation: use `LedgerAppender` via
  `bundle exec rails runner` for correctness, accept the ~2s boot cost.

- **Status comment format in IMPLEMENTATION_PLAN.md**: The concept spec shows
  `<!-- status: done, spec: ..., test: ... -->` but current plan items don't have this
  format. Decide whether to retrofit existing items or only add to new items going
  forward. Recommendation: add to new items only — retrofitting is noise.

### Recommendation

Implement task 4.1 as a skill file at `specifications/skills/tools/commit.md`. The
skill instructs the build agent to:

1. Append a `status` event to LEDGER.jsonl (type: `status`, from: `in_progress`,
   to: `done`, ref: task ID, sha: null at this point)
2. Edit IMPLEMENTATION_PLAN.md: `[ ]` → `[x]`
3. `git add` all staged code + LEDGER.jsonl + IMPLEMENTATION_PLAN.md
4. `git commit -m "{beat title}\n\n- {what changed}\n- {why}"`
5. Update the LEDGER.jsonl entry's `sha` field — **not possible post-commit without
   amending**. Resolution: append a second event with the SHA after commit:
   `{"type":"status","ref":"...","from":"done","to":"done","sha":"<sha>","reason":"sha recorded"}`
   This is two events but preserves append-only semantics.

The skill file is the deliverable for task 4.1. No code changes needed.
