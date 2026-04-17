#!/bin/bash
# Controlled commit skill — atomically commits code + LEDGER.jsonl + IMPLEMENTATION_PLAN.md.
#
# Usage:
#   scripts/controlled-commit.sh --ref <task_ref> --to <status> --message <msg> [options]
#
# Options:
#   --ref <ref>       Task reference (e.g. "1.2") — required
#   --to <status>     Target status: todo|in_progress|done|blocked — required
#   --message <msg>   Commit message — required
#   --from <status>   Source status (optional, recorded in ledger)
#   --reason <text>   Reason for transition (optional)
#   --sha <sha>       Git SHA to record in ledger (optional)
#   --ledger <path>   Override LEDGER.jsonl path (default: project root)
#   --plan <path>     Override IMPLEMENTATION_PLAN.md path (default: project root)
#
# The caller is responsible for staging code changes (git add) before invoking this script.
# This script adds LEDGER.jsonl and IMPLEMENTATION_PLAN.md to the staged set, then commits.
#
# If the commit fails, nothing is recorded in git history. The LEDGER.jsonl append is
# idempotent — a retry will skip the duplicate entry.
#
# Exit codes:
#   0 — success
#   1 — usage error or precondition failure
#   2 — commit failed (nothing was recorded in git history)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Argument parsing ---
REF=""
FROM_STATUS=""
TO_STATUS=""
MESSAGE=""
REASON=""
SHA=""
LEDGER=""
PLAN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref)     REF="$2";         shift 2 ;;
    --from)    FROM_STATUS="$2"; shift 2 ;;
    --to)      TO_STATUS="$2";   shift 2 ;;
    --message) MESSAGE="$2";     shift 2 ;;
    --reason)  REASON="$2";      shift 2 ;;
    --sha)     SHA="$2";         shift 2 ;;
    --ledger)  LEDGER="$2";      shift 2 ;;
    --plan)    PLAN="$2";        shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[ -z "$REF" ]       && { echo "Error: --ref is required" >&2; exit 1; }
[ -z "$TO_STATUS" ] && { echo "Error: --to is required" >&2; exit 1; }
[ -z "$MESSAGE" ]   && { echo "Error: --message is required" >&2; exit 1; }

VALID_STATUSES="todo in_progress done blocked"
echo "$VALID_STATUSES" | grep -qw "$TO_STATUS" || { echo "Error: invalid --to status: $TO_STATUS" >&2; exit 1; }
if [ -n "$FROM_STATUS" ]; then
  echo "$VALID_STATUSES" | grep -qw "$FROM_STATUS" || { echo "Error: invalid --from status: $FROM_STATUS" >&2; exit 1; }
fi

# Resolve paths (allow overrides for testing)
LEDGER="${LEDGER:-$PROJECT_ROOT/LEDGER.jsonl}"
PLAN="${PLAN:-$PROJECT_ROOT/IMPLEMENTATION_PLAN.md}"

# --- Preconditions ---
[ -f "$PLAN" ] || { echo "Error: IMPLEMENTATION_PLAN.md not found at $PLAN" >&2; exit 1; }

# Warn if no staged code changes (not an error — ledger-only commits are valid)
if git diff --cached --quiet 2>/dev/null; then
  echo "Warning: no staged code changes. Proceeding with LEDGER.jsonl + IMPLEMENTATION_PLAN.md only." >&2
fi

# --- Build LEDGER.jsonl entry ---
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SHA_VAL="${SHA:-null}"
[ "$SHA_VAL" != "null" ] && SHA_VAL="\"$SHA_VAL\""
REASON_VAL="${REASON:-controlled commit}"

FROM_FIELD=""
[ -n "$FROM_STATUS" ] && FROM_FIELD=",\"from\":\"$FROM_STATUS\""

LEDGER_LINE="{\"ts\":\"$TS\",\"type\":\"status\",\"ref\":\"$REF\"${FROM_FIELD},\"to\":\"$TO_STATUS\",\"sha\":$SHA_VAL,\"reason\":\"$REASON_VAL\"}"

# Idempotency: skip if exact line already exists
if [ -f "$LEDGER" ] && grep -qF "$LEDGER_LINE" "$LEDGER" 2>/dev/null; then
  echo "LEDGER.jsonl: entry already exists, skipping append"
else
  echo "$LEDGER_LINE" >> "$LEDGER"
  echo "LEDGER.jsonl: appended $TO_STATUS event for ref $REF"
fi

# --- Update IMPLEMENTATION_PLAN.md checkbox ---
# Only mark done when transitioning to done status.
if [ "$TO_STATUS" = "done" ]; then
  TMPFILE=$(mktemp)
  sed "s/^- \[ \] ${REF} —/- [x] ${REF} —/" "$PLAN" > "$TMPFILE"
  mv "$TMPFILE" "$PLAN"
  echo "IMPLEMENTATION_PLAN.md: marked $REF as done"
fi

# --- Stage LEDGER.jsonl and IMPLEMENTATION_PLAN.md ---
git add "$LEDGER" "$PLAN"

# --- Commit ---
if ! git commit -m "$MESSAGE"; then
  echo "Error: git commit failed. Staged changes preserved. Re-run after fixing the issue." >&2
  exit 2
fi

echo "Committed: $(git rev-parse --short HEAD) — $MESSAGE"
