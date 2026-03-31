# Doc Linter (doclint)

## [1] Doc Linter

- **Status:** ready
- **Created:** 2026-03-31
- **Promoted:**

### Description

A Go CLI binary (`doclint`) that validates, auto-fixes, and reports on markdown and README
files across an unpossible project. Its job is to eliminate mechanical doc work so that
LLM iterations only touch things requiring genuine reasoning.

Ships as a compiled binary inside the unpossible 2 repo under `tools/doclint/`. Runs as
a post-loop step in the Makefile. Reads its structural rules from a format spec file
(`specs/doc-format.md`) so the rules evolve with the project without changing the binary.

**Language: Go.** Single static binary, no runtime dependencies, fast enough to run after
every loop iteration without adding meaningful latency.

**Core responsibilities:**

1. **Validate structure** — check all markdown files against the format spec. Flag missing
   required sections, incorrect heading hierarchy, files that exceed token budget thresholds.

2. **Validate cross-references** — check that terms, section names, and file references used
   in one doc resolve correctly in the docs they point to. Flag broken links and undefined
   terms.

3. **Sync checks** — detect drift between docs and their source of truth:
   - README sections that list Makefile targets: flag when targets in the Makefile don't
     match what the README documents
   - Directory READMEs: flag when files present in the directory aren't mentioned and vice
     versa (configurable per-directory)

4. **Auto-fix (safe)** — apply without confirmation:
   - Normalize heading levels to match the format spec
   - Add missing required sections as stubs (e.g. `## Open Questions\n\n_None._`)
   - Fix trailing whitespace, missing newlines at EOF
   - Update auto-generated sections (Makefile target lists) from source of truth

5. **Auto-fix (aggressive)** — require `--fix=aggressive` flag or interactive confirmation:
   - Reorder sections to match the format spec sequence
   - Rename sections to match canonical names in the format spec
   - Rewrite cross-references when a referenced section has been renamed

6. **LLM queue** — issues the binary cannot fix are written to `specs/doc-issues.md` in a
   structured format. Each entry includes: file, line, issue type, and a plain-English
   description of what needs resolving. The loop reads this file at the start of each
   iteration and treats unresolved entries as tasks.

**Architecture:**

- `tools/doclint/main.go` — CLI entry point, flag parsing, exit codes
- `tools/doclint/lint/` — rule engine: loads `specs/doc-format.md`, walks the file tree,
  runs rules against each file
- `tools/doclint/fix/` — fix engine: safe fixes applied automatically, aggressive fixes
  gated by flag or prompt
- `tools/doclint/report/` — writes `specs/doc-issues.md` for issues requiring LLM or
  human resolution
- `tools/doclint/sync/` — Makefile parser and directory scanner for drift detection

**CLI interface:**

```
doclint [flags] [path]

Flags:
  --fix             Apply safe fixes automatically (default: false)
  --fix=aggressive  Apply safe + aggressive fixes (prompts for confirmation unless --yes)
  --yes             Skip confirmation prompts (for use in loop/CI)
  --format-spec     Path to format spec file (default: specs/doc-format.md)
  --report          Path to issues output file (default: specs/doc-issues.md)
  --quiet           Suppress stdout, only write report file
```

Exit codes: `0` = clean or all issues fixed, `1` = unfixed issues remain, `2` = binary
error (bad config, unreadable files).

**Format spec (`specs/doc-format.md`):**

A markdown file that defines the rules doclint enforces. Sections:

- `## Required Files` — list of files that must exist in the project
- `## File Rules` — per-file or per-glob rules: required sections, section order, max tokens
- `## Vocabulary` — terms that must be used consistently; aliases that should be normalized
- `## Sync Rules` — which docs are derived from which sources (e.g. README target list ←
  Makefile)

The format spec is itself validated by doclint on every run (bootstrapped rule: the spec
must contain all four required sections).

**Makefile integration:**

```makefile
lint-docs:
    @./tools/doclint/doclint --fix --report

lint-docs-fix:
    @./tools/doclint/doclint --fix=aggressive --yes --report
```

`lint-docs` runs automatically after each successful loop commit (added to the post-commit
hook the loop manages). `lint-docs-fix` is a manual target for bulk cleanup.

**LLM queue format (`specs/doc-issues.md`):**

```markdown
## Doc Issues

<!-- doclint: auto-generated, do not edit manually -->

- [ ] `specs/upload-photo.md` line 14: missing required section `## Acceptance Criteria`
- [ ] `README.md` line 32: Makefile target `sb-sync` documented but not present in Makefile
- [ ] `specs/prd.md`: term "base image" used here but "docker image" used in upload-photo.md — normalize to one
```

The loop agent reads this file, resolves items it can, and checks them off. doclint removes
checked items on the next run.

### Acceptance Criteria

- `doclint` with no flags exits `1` and prints a summary when any rule in the format spec
  is violated; exits `0` when the project is clean
- `--fix` resolves all safe-fixable issues and re-runs validation; exits `0` if only
  safe issues were present
- Makefile drift detection catches at least: targets present in Makefile but missing from
  README, and targets in README but removed from Makefile
- Cross-reference validation catches broken internal links (`[text](other-file.md#section)`)
  and undefined vocabulary terms
- `specs/doc-issues.md` is written with one entry per unfixed issue in the format above;
  resolved issues (checked off by the loop) are removed on the next run
- The format spec itself is validated on every run; a malformed format spec exits `2` with
  a clear error
- Binary builds with `CGO_ENABLED=0` and produces a single static binary under 10MB

### Open Questions

_None._

### Resolved

- **Watch mode:** deferred. Post-loop only for now. Add `--watch` when post-loop latency
  proves insufficient during active spec writing.
- **Zed task:** yes — `lint-docs` added to `.zed/tasks.json` so it runs from the command
  palette during spec writing without opening the terminal.
