---
name: pr
kind: tool
description: Create a pull request with graph-linked metadata
actor: default
runs: once
principles: [version-control]
---

Create a pull request that links commits to specs, plan tasks, and review threads
in the reference graph. The PR is a first-class graph node — not a GitHub artifact
that happens to exist alongside the project.

## When to Use

After a loop run completes on a `ralph/{timestamp}` branch and all beats are green.
The developer (or a future automation) invokes this skill to package the branch as a
reviewable PR.

## Steps

1. Identify the current branch. Confirm it is a `ralph/*` branch (or a named feature
   branch). Refuse to run on `main` or `master`.

2. Collect commits on the branch since the fork point from main:
   ```
   git log main..HEAD --oneline
   ```

3. Collect LEDGER.jsonl entries whose `sha` matches any commit in the range. Extract
   the unique `ref` values — these are the plan task IDs this PR implements.

4. For each task ID, read the `spec:` metadata from IMPLEMENTATION_PLAN.md to get the
   linked spec file paths.

5. Build the PR description:
   ```markdown
   ## What

   {One-sentence summary derived from the beat titles.}

   ## Tasks

   - [x] {task_id} — {beat title}
   ...

   ## Specs

   - `{spec_path}#{section}` — {spec title}
   ...

   ## Commits

   - `{sha}` {message}
   ...

   ## Review Guidance

   {Optional: anything the reviewer should focus on, derived from open questions
   or spec contradictions encountered during the build.}
   ```

6. Create the PR:
   ```
   gh pr create --base main --title "{concise title}" --body "{description}"
   ```
   Title must be under 70 characters.

7. Append a `pr_opened` event to LEDGER.jsonl:
   ```json
   {"ts":"...","type":"pr_opened","pr_number":{n},"branch":"{branch}","task_ids":["{ref}",...],"spec_refs":["{path}",...],"sha_first":"{first}","sha_last":"{last}"}
   ```

8. Commit the LEDGER.jsonl update:
   ```
   git add LEDGER.jsonl
   git commit -m "ledger: record PR #{n} opened"
   git push
   ```

## After Merge

When the PR is merged (detected by the developer or a future webhook):

1. Append a `pr_merged` event to LEDGER.jsonl:
   ```json
   {"ts":"...","type":"pr_merged","pr_number":{n},"merge_sha":"{sha}"}
   ```

2. Commit the LEDGER.jsonl update on main.

## After Review (Manual for Phase 0)

When review comments are left on the PR:

1. Append a `pr_review` event to LEDGER.jsonl:
   ```json
   {"ts":"...","type":"pr_review","pr_number":{n},"reviewer":"{handle}","verdict":"{approved|changes_requested|commented}","thread_count":{n}}
   ```

2. If the review contains decisions worth preserving (why-not-X answers, scope
   clarifications, design tradeoffs), attach them as a git note on the merge commit:
   ```
   git notes add -m "{summary of review decisions}" {merge_sha}
   ```

   This makes review decisions queryable by the reference parser without calling the
   GitHub API.

## What This Skill Does NOT Do

- Does not merge the PR. Merging is a human decision.
- Does not sync review comments in real time. Phase 0 is manual.
- Does not create branches. The build loop already does that.
