# Bash Language Practices

Bash-specific patterns for this project. Loaded when working on shell scripts.

## Error Handling

- `set -e` — exit on first error (use in new-project.sh style scripts)
- `set -euo pipefail` — strict mode for production scripts (worklog.sh pattern)
  - `-u` catches unset variables
  - `-o pipefail` fails if any command in a pipeline fails
- Validate inputs at the top — fail fast with clear error messages
- Exit codes: 0 for success, 1 for user error, 2+ for internal errors

## Quoting

- Always quote variables: `"$VAR"` not `$VAR`
- Exception: when word splitting is intentional (rare)
- Quote command substitutions: `"$(command)"`
- Use `[[ ]]` for conditionals, not `[ ]` — safer and more features

## Variables

- UPPERCASE for environment variables and constants: `PROJECT_NAME`, `REPO_ROOT`
- lowercase for local function variables
- Declare intent: `local var="value"` inside functions
- Strip whitespace from file reads: `tr -d '[:space:]'`

## Arrays

- Declare: `arr=(item1 item2 item3)`
- Access all: `"${arr[@]}"`
- Length: `${#arr[@]}`
- Always quote array expansions

## Functions

- Define with `function_name() { ... }` syntax
- Use `local` for all function-scoped variables
- Return status codes, output to stdout
- Document complex functions with a comment block

## Paths

- Compute script directory: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- Compute repo root from script location: `REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"`
- Use absolute paths for file operations — don't rely on `pwd`
- Check file existence before reading: `[[ -f "$FILE" ]]`

## Heredocs

- Use `<< EOF` for multi-line strings
- Quote the delimiter (`<< 'EOF'`) to prevent variable expansion if literals are needed
- Indent with tabs if using `<<-` (strips leading tabs)

## BATS Test Structure

- One test file per script: `src/test/script-name.bats`
- `setup()` runs before each test — create temp dirs, set env vars
- `teardown()` runs after each test — clean up temp resources
- Test names read as sentences: `@test "description of expected behavior"`
- Use `run` to capture command output and exit status
- Assertions: `[ condition ]` or `[[ condition ]]`
- Check exit status: `[ "$status" -eq 0 ]`
- Check output: `[[ "$output" =~ pattern ]]`

## Portability

- Avoid GNU-specific flags — test on macOS and Linux
- Use `#!/usr/bin/env bash` not `#!/bin/bash` (macOS compatibility)
- Prefer POSIX tools; document when GNU extensions are required
- Test in Docker to catch portability issues early

## Output

- Errors to stderr: `echo "Error: message" >&2`
- Use `printf` for formatted output (more predictable than `echo`)
- Structured output: prefer line-based formats (one record per line) over complex parsing

## Common Patterns

- Read file into variable: `VAR=$(cat "$FILE" | tr -d '[:space:]')`
- Check if command exists: `command -v cmd >/dev/null 2>&1`
- Iterate over lines: `while IFS= read -r line; do ... done < "$FILE"`
- Cleanup on exit: `trap cleanup EXIT`
- Case statements for mode selection (see loop.sh AGENT configuration)

## What to Avoid

- `eval` — almost always a sign of bad design
- Backticks — use `$()` instead
- `cd` without error handling — use subshells `(cd dir && command)` or check exit status
- Parsing `ls` output — use globs or `find` instead
- `cat file | command` — use `command < file` or `command "$file"`
