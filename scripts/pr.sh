#!/bin/bash
# PR skill — creates a pull request with graph-linked metadata.
#
# Usage:
#   scripts/pr.sh [--title <title>] [--base <branch>] [--repo <path>] [--ledger <path>] [--plan <path>] [--dry-run]
#
# Options:
#   --title <title>   PR title (optional — derived from beat titles if omitted)
#   --base <branch>   Base branch (default: main)
#   --repo <path>     Git repo root (default: current working directory)
#   --ledger <path>   Override LEDGER.jsonl path (default: <repo>/LEDGER.jsonl)
#   --plan <path>     Override IMPLEMENTATION_PLAN.md path (default: <repo>/IMPLEMENTATION_PLAN.md)
#   --dry-run         Print PR body and LEDGER entry without creating the PR
#
# Refuses to run on main/master. Requires `gh` CLI to be authenticated.
#
# Exit codes:
#   0 — success
#   1 — usage error or precondition failure
#   2 — gh pr create failed

set -euo pipefail

# --- Argument parsing ---
TITLE=""
BASE="main"
REPO_ROOT=""
LEDGER=""
PLAN=""
DRY_RUN=false
NO_PUSH=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)   TITLE="$2";     shift 2 ;;
    --base)    BASE="$2";      shift 2 ;;
    --repo)    REPO_ROOT="$2"; shift 2 ;;
    --ledger)  LEDGER="$2";    shift 2 ;;
    --plan)    PLAN="$2";      shift 2 ;;
    --dry-run) DRY_RUN=true;   shift ;;
    --no-push) NO_PUSH=true;   shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Resolve repo root: explicit flag > git toplevel from CWD
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
fi
REPO_ROOT=$(cd "$REPO_ROOT" && pwd)

LEDGER="${LEDGER:-$REPO_ROOT/LEDGER.jsonl}"
PLAN="${PLAN:-$REPO_ROOT/IMPLEMENTATION_PLAN.md}"

# --- Preconditions ---
BRANCH=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "Error: refusing to create PR from $BRANCH. Switch to a feature branch first." >&2
  exit 1
fi

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install from https://cli.github.com/" >&2
  exit 1
fi

[ -f "$PLAN" ] || { echo "Error: IMPLEMENTATION_PLAN.md not found at $PLAN" >&2; exit 1; }

# --- Collect commits on this branch since fork from base ---
COMMITS=$(git -C "$REPO_ROOT" log "${BASE}..HEAD" --format="%H %s" 2>/dev/null || true)
if [ -z "$COMMITS" ]; then
  echo "Error: no commits found between $BASE and HEAD. Nothing to PR." >&2
  exit 1
fi

SHA_FIRST=$(git -C "$REPO_ROOT" log "${BASE}..HEAD" --format="%H" | tail -1)
SHA_LAST=$(git -C "$REPO_ROOT" log "${BASE}..HEAD" --format="%H" | head -1)

# --- Extract task IDs from LEDGER.jsonl entries matching branch commits ---
TASK_IDS=()
SPEC_REFS=()

if [ -f "$LEDGER" ]; then
  # Collect all SHAs on this branch (short and full)
  BRANCH_SHAS=$(git -C "$REPO_ROOT" log "${BASE}..HEAD" --format="%H %h" 2>/dev/null || true)

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    entry_type=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('type',''))" 2>/dev/null || true)
    [ "$entry_type" != "status" ] && continue

    entry_sha=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('sha','') or '')" 2>/dev/null || true)
    entry_ref=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('ref',''))" 2>/dev/null || true)

    [ -z "$entry_sha" ] && continue
    [ -z "$entry_ref" ] && continue

    # Match if any branch SHA starts with or equals entry_sha
    if echo "$BRANCH_SHAS" | grep -q "$entry_sha"; then
      TASK_IDS+=("$entry_ref")
    fi
  done < "$LEDGER"
fi

# --- Extract spec refs from IMPLEMENTATION_PLAN.md for matched task IDs ---
for ref in "${TASK_IDS[@]+"${TASK_IDS[@]}"}"; do
  # Look for spec: in the comment on the plan item line
  spec_ref=$(grep -E "^- \[.\] ${ref} —" "$PLAN" | grep -oE 'spec: *[^ ,>]+' | sed 's/spec: *//' || true)
  if [ -n "$spec_ref" ]; then
    SPEC_REFS+=("$spec_ref")
  fi
done

# Remove duplicates
if [ ${#TASK_IDS[@]} -gt 0 ]; then
  TASK_IDS=($(printf '%s\n' "${TASK_IDS[@]}" | sort -u))
fi
if [ ${#SPEC_REFS[@]} -gt 0 ]; then
  SPEC_REFS=($(printf '%s\n' "${SPEC_REFS[@]}" | sort -u))
fi

# --- Derive title from beat titles if not provided ---
if [ -z "$TITLE" ]; then
  if [ ${#TASK_IDS[@]} -gt 0 ]; then
    # Use first beat title
    first_ref="${TASK_IDS[0]}"
    beat_title=$(grep -E "^- \[.\] ${first_ref} —" "$PLAN" | sed -E "s/^- \[.\] ${first_ref} — ([^<]+).*/\1/" | xargs || true)
    if [ -n "$beat_title" ]; then
      TITLE="${beat_title}"
    fi
  fi
  # Fall back to branch name
  [ -z "$TITLE" ] && TITLE="$BRANCH"
fi

# Truncate title to 70 chars
TITLE="${TITLE:0:70}"

# --- Build PR description ---
TASKS_SECTION=""
for ref in "${TASK_IDS[@]+"${TASK_IDS[@]}"}"; do
  beat_title=$(grep -E "^- \[.\] ${ref} —" "$PLAN" | sed -E "s/^- \[.\] ${ref} — ([^<]+).*/\1/" | xargs || true)
  TASKS_SECTION+="- [x] ${ref} — ${beat_title}"$'\n'
done
[ -z "$TASKS_SECTION" ] && TASKS_SECTION="_(none matched in LEDGER.jsonl)_"$'\n'

SPECS_SECTION=""
for spec in "${SPEC_REFS[@]+"${SPEC_REFS[@]}"}"; do
  SPECS_SECTION+="- \`${spec}\`"$'\n'
done
[ -z "$SPECS_SECTION" ] && SPECS_SECTION="_(none)_"$'\n'

COMMITS_SECTION=""
while IFS= read -r line; do
  sha="${line:0:7}"
  msg="${line:8}"
  COMMITS_SECTION+="- \`${sha}\` ${msg}"$'\n'
done <<< "$COMMITS"

BODY="## What

${TITLE}

## Tasks

${TASKS_SECTION}
## Specs

${SPECS_SECTION}
## Commits

${COMMITS_SECTION}"

# --- Build LEDGER.jsonl entry ---
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# JSON arrays for task_ids and spec_refs
task_ids_json=$(printf '%s\n' "${TASK_IDS[@]+"${TASK_IDS[@]}"}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null || echo "[]")
spec_refs_json=$(printf '%s\n' "${SPEC_REFS[@]+"${SPEC_REFS[@]}"}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null || echo "[]")

if $DRY_RUN; then
  echo "=== DRY RUN ==="
  echo "Branch: $BRANCH → $BASE"
  echo "Title: $TITLE"
  echo ""
  echo "--- PR Body ---"
  echo "$BODY"
  echo ""
  echo "--- LEDGER entry (pr_number will be filled after gh pr create) ---"
  echo "{\"ts\":\"$TS\",\"type\":\"pr_opened\",\"pr_number\":0,\"branch\":\"$BRANCH\",\"task_ids\":${task_ids_json},\"spec_refs\":${spec_refs_json},\"sha_first\":\"$SHA_FIRST\",\"sha_last\":\"$SHA_LAST\"}"
  exit 0
fi

# --- Create the PR ---
PR_URL=$(gh pr create \
  --base "$BASE" \
  --title "$TITLE" \
  --body "$BODY" 2>&1) || { echo "Error: gh pr create failed: $PR_URL" >&2; exit 2; }

echo "PR created: $PR_URL"

# Extract PR number from URL (e.g. https://github.com/org/repo/pull/42)
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$' || echo "0")

# --- Append pr_opened event to LEDGER.jsonl ---
LEDGER_LINE="{\"ts\":\"$TS\",\"type\":\"pr_opened\",\"pr_number\":${PR_NUMBER},\"branch\":\"$BRANCH\",\"task_ids\":${task_ids_json},\"spec_refs\":${spec_refs_json},\"sha_first\":\"$SHA_FIRST\",\"sha_last\":\"$SHA_LAST\"}"

echo "$LEDGER_LINE" >> "$LEDGER"
echo "LEDGER.jsonl: appended pr_opened event for PR #${PR_NUMBER}"

# --- Commit the LEDGER.jsonl update ---
git -C "$REPO_ROOT" add "$LEDGER"
git -C "$REPO_ROOT" commit -m "ledger: record PR #${PR_NUMBER} opened"
if ! $NO_PUSH; then
  git -C "$REPO_ROOT" push
fi

echo "Done. PR #${PR_NUMBER}: $PR_URL"
