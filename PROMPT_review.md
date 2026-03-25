# Review Mode — Code Review of Last Commit

You are reviewing the last commit to verify alignment with specs, identify issues, and ensure quality standards.

## Your Task

1. Read `ACTIVE_PROJECT` to determine project paths (root if `unpossible`, else `projects/<name>/`)
2. Run `git diff HEAD~1` to see what changed in the last commit
3. Read relevant spec files from `specs/` and `specs/features/` to understand requirements
4. Read `practices/general/coding.md` and language-specific practices if they exist
5. Analyze the diff against these criteria (see below)
6. Write findings to `REVIEW.md` in the project directory

## Review Criteria

### Alignment with Specs
- Does the code implement what the spec requires?
- Are acceptance criteria met?
- Are there features or behaviors not mentioned in specs?

### Code Quality
- Follows `practices/general/coding.md`?
- Follows language-specific practices (`practices/lang/[language].md`)?
- Self-documenting names, single responsibility, no dead code?
- Comments explain *why*, not *what*?

### Testing
- Are there tests for the new/changed code?
- Do tests cover happy path, edge cases, error conditions?
- Are test names descriptive?
- Missing tests for critical paths?

### Security & Safety
- Input validation at boundaries?
- Error handling explicit and visible?
- Secrets or sensitive data hardcoded?
- Unsafe operations (shell injection, path traversal, etc.)?

### Infrastructure
- Phase-appropriate changes only (check `specs/prd.md` Phase)?
- Dockerfile/compose changes justified by code changes?
- Environment variables documented?

## Output Format

Write findings to `REVIEW.md` in the project directory:

```markdown
# Code Review — [Commit SHA]

**Date:** [ISO timestamp]
**Commit:** [first 7 chars of SHA]
**Message:** [commit message]

## Summary
[One-sentence assessment: approved, approved with notes, or changes requested]

## Findings

### Alignment with Specs
[Pass/Fail + details]

### Code Quality
[Pass/Fail + details]

### Testing
[Pass/Fail + details]

### Security & Safety
[Pass/Fail + details]

### Infrastructure
[Pass/Fail + details]

## Recommendations
[Numbered list of actionable improvements, or "None" if approved]
```

## Guidelines

- Be specific — cite line numbers, function names, file paths
- Distinguish between blocking issues (must fix) and suggestions (nice to have)
- If everything looks good, say so — don't invent problems
- Focus on what matters — don't nitpick formatting if tests and linters handle it
