---
name: reference-graph-commit
kind: research
status: active
date: 2026-05-15
topic: Controlled Commit Skill (Reference Graph Priority 1)
spec: specifications/system/reference-graph/concept.md#1-controlled-commit-skill-priority-1
---

# Research: Reference Graph Controlled Commit Skill

## Summary

The controlled commit skill replaces raw `git commit` in the build loop with an atomic
sequence that commits code, appends a LEDGER.jsonl status event, and updates
IMPLEMENTATION_PLAN.md in a single git commit. The spec is well-defined. No blocking
open questions. Ready to build.

## Findings

### What Already Exists

- `LedgerAppender` (`web/app/lib/ledger_appender.rb`) — handles LEDGER.jsonl append
  with idempotency and type validation. Supports all required event types including
  `status`, `pr_opened`, `pr_review`, `pr_merged`.
- `LEDGER.jsonl` at project root — append-only, 6 entries present.
- `IMPLEMENTATION_PLAN.md` — uses `- [ ]` / `- [x]` checkbox format.
- `pr.md` skill (`specifications/skills/tools/pr.md`) — already defines `pr_opened`,
  `pr_review`, `pr_merged` ledger events. The controlled commit skill is the missing
  complement: it handles `status` events on every beat commit.

### What Needs to Be Built

A skill file at `specifications/skills/tools/commit.md` that defines the atomic
commit sequence. The build loop's step 9 ("Commit") should reference this skill.

The skill is a shell-level procedure (not a Rails service) because it runs in the
agent container, not the Rails process. It uses:
- `git add` — stage files
- `LedgerAppender` via a rake task or standalone Ruby script — append LEDGER.jsonl
- `sed` or Ruby — update IMPLEMENTATION_PLAN.md checkbox
- `git commit` — single atomic commit

### Atomic Sequence (from spec)

1. Stage code changes (`git add <files>`)
2. Append LEDGER.jsonl `status` event: `from: in_progress → to: done`
3. Update IMPLEMENTATION_PLAN.md: `- [ ]` → `- [x]`
4. `git add LEDGER.jsonl IMPLEMENTATION_PLAN.md`
5. `git commit -m "{beat title}\n\n- {what changed}\n- {why}"`
6. Optionally `git notes add` for rich context

If the commit fails, nothing is recorded — git's atomicity guarantees consistency.

### LEDGER.jsonl Entry Format

```json
{"ts":"2026-05-15T12:00:00Z","type":"status","ref":"4.1","from":"in_progress","to":"done","sha":"abc1234","reason":"tests green, N examples 0 failures"}
```

The `sha` field is populated after `git commit` succeeds (use `git rev-parse HEAD`).
This means the LEDGER.jsonl entry is appended *before* the commit (without sha), then
the commit includes it, and a second append with sha is not needed — the sha can be
omitted or added as a follow-up `git notes` entry.

**Resolution:** Append the entry with `sha: null` before committing (as the existing
LEDGER.jsonl entries show — the first entry has `"sha":null`). The commit SHA is
recoverable from git log by matching the timestamp. This is consistent with current
practice.

### IMPLEMENTATION_PLAN.md Update

The skill must change `- [ ] N.M — {title}` to `- [x] N.M — {title}`. A simple
Ruby one-liner or `sed` command handles this. The item format in the spec includes
optional HTML comment metadata — the checkbox update must preserve the rest of the line.

Pattern: `s/^- \[ \] (N\.M —)/- [x] \1/`

### Open Questions — Resolved

| Question | Resolution |
|---|---|
| Git notes merge conflicts | Low risk for solo dev. Use `git notes append` (not `add`) to avoid overwrite. Defer multi-collaborator handling. |
| LEDGER.jsonl growth | Periodic summarization when file exceeds ~500 lines. Not needed for Phase 0. |
| Plan item renumbering | Reference parser uses title-based stable refs, not numeric IDs. Numeric IDs in LEDGER.jsonl are acceptable as human-readable labels — the parser matches on title if ID is ambiguous. |

### Skill File Location

`specifications/skills/tools/commit.md` — consistent with `pr.md` placement.

The build loop skill (`specifications/skills/loops/build.md`) step 9 currently says
"Commit." — update to reference the commit skill explicitly.

### Implementation Approach

The skill is a markdown procedure file (like `pr.md`). No new Ruby code needed — the
`LedgerAppender` already handles the append. The skill invokes it via:

```bash
bundle exec ruby -e "
require_relative 'web/app/lib/ledger_appender'
LedgerAppender.append({
  ts: Time.now.utc.iso8601,
  type: 'status',
  ref: ENV['TASK_REF'],
  from: 'in_progress',
  to: 'done',
  sha: nil,
  reason: ENV['REASON']
})
"
```

Or via a rake task if the Rails environment is available.

**Preferred:** A standalone Ruby script at `scripts/ledger_append.rb` that can be
called without Rails boot (faster, no dependency on Rails being available in the
agent container). The `LedgerAppender` class has no Rails dependencies — it only
uses `File` and `JSON`.

### Build Tasks Derived from This Research

1. **Write `specifications/skills/tools/commit.md`** — the skill file defining the
   atomic commit sequence. No code changes needed.
2. **Add `scripts/ledger_append.rb`** — thin CLI wrapper around `LedgerAppender` for
   use from shell scripts and the agent container.
3. **Update `specifications/skills/loops/build.md`** — step 9 references the commit
   skill.
4. **Update `IMPLEMENTATION_PLAN.md`** — add build tasks 4.2, 4.3, 4.4 derived from
   this research.

### Confidence Assessment

- Skill file format: **high confidence** — follows `pr.md` pattern exactly
- LedgerAppender reuse: **high confidence** — no Rails deps, already tested
- Standalone script approach: **high confidence** — simpler than rake task
- Git notes integration: **deferred** — low priority for Phase 0, no blocking issue

## Back-References

- Spec: `specifications/system/reference-graph/concept.md` § Controlled Commit Skill
- Existing tool: `web/app/lib/ledger_appender.rb`
- Related skill: `specifications/skills/tools/pr.md`
- Build loop: `specifications/skills/loops/build.md`
