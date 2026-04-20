#!/bin/bash
# Tests for scripts/controlled-commit.sh
# Run from project root: bash scripts/test-controlled-commit.sh
# Exit 0 if all tests pass, exit 1 if any fail.

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/controlled-commit.sh"
PASS=0
FAIL=0

# --- Test harness ---
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "        expected: $expected"
    echo "        actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "        expected to contain: $needle"
    echo "        actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_contains() {
  local desc="$1" needle="$2" file="$3"
  if grep -qF -- "$needle" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "        expected '$file' to contain: $needle"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_contains() {
  local desc="$1" needle="$2" file="$3"
  if ! grep -qF -- "$needle" "$file" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    echo "        expected '$file' NOT to contain: $needle"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  assert_eq "$desc (exit code)" "$expected" "$actual"
}

# --- Setup: create a temp git repo ---
# Returns the repo path in REPO variable (caller must cd to it)
make_repo() {
  local dir
  dir=$(mktemp -d)
  (
    cd "$dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    cat > IMPLEMENTATION_PLAN.md <<'EOF'
## Tasks

- [ ] 1.2 — Create controlled commit skill script
- [ ] 2.1 — Initialize Go module
- [x] 1.1 — Create LEDGER.jsonl schema
EOF
    touch LEDGER.jsonl
    git add IMPLEMENTATION_PLAN.md LEDGER.jsonl
    git commit -q -m "initial"
  )
  echo "$dir"
}

# Wrapper: run controlled-commit.sh inside a given repo, passing --ledger and --plan
run_cc() {
  local repo="$1"; shift
  (
    cd "$repo"
    bash "$SCRIPT" \
      --ledger "$repo/LEDGER.jsonl" \
      --plan "$repo/IMPLEMENTATION_PLAN.md" \
      "$@"
  )
}

# --- Test 1: appends status event to LEDGER.jsonl ---
echo "Test 1: appends status event to LEDGER.jsonl"
REPO=$(make_repo)
(cd "$REPO" && echo "dummy" > code.rb && git add code.rb)
run_cc "$REPO" --ref "1.2" --from "todo" --to "done" \
  --message "1.2 — controlled commit skill" --reason "tests green"
LEDGER_CONTENT=$(cat "$REPO/LEDGER.jsonl")
assert_contains "contains ref 1.2"    '"ref":"1.2"'       "$LEDGER_CONTENT"
assert_contains "contains to:done"    '"to":"done"'       "$LEDGER_CONTENT"
assert_contains "contains from:todo"  '"from":"todo"'     "$LEDGER_CONTENT"
assert_contains "contains type:status" '"type":"status"'  "$LEDGER_CONTENT"
assert_contains "contains reason"     '"reason":"tests green"' "$LEDGER_CONTENT"
rm -rf "$REPO"

# --- Test 2: marks task done in IMPLEMENTATION_PLAN.md ---
echo "Test 2: marks task done in IMPLEMENTATION_PLAN.md"
REPO=$(make_repo)
(cd "$REPO" && echo "dummy" > code.rb && git add code.rb)
run_cc "$REPO" --ref "1.2" --to "done" --message "1.2 — done"
assert_file_contains     "1.2 marked done"      "- [x] 1.2 —" "$REPO/IMPLEMENTATION_PLAN.md"
assert_file_contains     "2.1 still unchecked"  "- [ ] 2.1 —" "$REPO/IMPLEMENTATION_PLAN.md"
assert_file_contains     "1.1 still checked"    "- [x] 1.1 —" "$REPO/IMPLEMENTATION_PLAN.md"
rm -rf "$REPO"

# --- Test 3: commits code + LEDGER.jsonl + IMPLEMENTATION_PLAN.md atomically ---
echo "Test 3: commits all three files atomically"
REPO=$(make_repo)
(cd "$REPO" && echo "feature code" > feature.rb && git add feature.rb)
run_cc "$REPO" --ref "1.2" --to "done" --message "1.2 — feature"
CHANGED=$(cd "$REPO" && git show --name-only HEAD | tail -n +6)
assert_contains "commit includes feature.rb"           "feature.rb"           "$CHANGED"
assert_contains "commit includes LEDGER.jsonl"         "LEDGER.jsonl"         "$CHANGED"
assert_contains "commit includes IMPLEMENTATION_PLAN.md" "IMPLEMENTATION_PLAN.md" "$CHANGED"
rm -rf "$REPO"

# --- Test 4: commit message is used verbatim ---
echo "Test 4: commit message is used verbatim"
REPO=$(make_repo)
(cd "$REPO" && echo "x" > x.rb && git add x.rb)
run_cc "$REPO" --ref "1.2" --to "done" --message "1.2 — my exact message"
COMMIT_MSG=$(cd "$REPO" && git log -1 --format="%s")
assert_eq "commit message matches" "1.2 — my exact message" "$COMMIT_MSG"
rm -rf "$REPO"

# --- Test 5: LEDGER.jsonl append is idempotent within the same second ---
echo "Test 5: LEDGER.jsonl append is idempotent within the same second"
REPO=$(make_repo)
(cd "$REPO" && echo "x" > x.rb && git add x.rb)
run_cc "$REPO" --ref "1.2" --to "done" --message "1.2 — first"
LINE_COUNT_AFTER_FIRST=$(wc -l < "$REPO/LEDGER.jsonl" | tr -d ' ')
assert_eq "one line after first run" "1" "$LINE_COUNT_AFTER_FIRST"
# Stage something new and run again immediately (same second = same timestamp = same line)
(cd "$REPO" && echo "y" > y.rb && git add y.rb)
run_cc "$REPO" --ref "1.2" --to "done" --message "1.2 — retry"
LINE_COUNT_AFTER_SECOND=$(wc -l < "$REPO/LEDGER.jsonl" | tr -d ' ')
assert_eq "still one line after retry (idempotent)" "1" "$LINE_COUNT_AFTER_SECOND"
rm -rf "$REPO"

# --- Test 6: exits 1 when --ref is missing ---
echo "Test 6: exits 1 when --ref is missing"
REPO=$(make_repo)
set +e
run_cc "$REPO" --to "done" --message "msg" 2>/dev/null
EXIT_CODE=$?
set -e
assert_exit "missing --ref" "1" "$EXIT_CODE"
rm -rf "$REPO"

# --- Test 7: exits 1 when --to is missing ---
echo "Test 7: exits 1 when --to is missing"
REPO=$(make_repo)
set +e
run_cc "$REPO" --ref "1.2" --message "msg" 2>/dev/null
EXIT_CODE=$?
set -e
assert_exit "missing --to" "1" "$EXIT_CODE"
rm -rf "$REPO"

# --- Test 8: exits 1 when --message is missing ---
echo "Test 8: exits 1 when --message is missing"
REPO=$(make_repo)
set +e
run_cc "$REPO" --ref "1.2" --to "done" 2>/dev/null
EXIT_CODE=$?
set -e
assert_exit "missing --message" "1" "$EXIT_CODE"
rm -rf "$REPO"

# --- Test 9: exits 1 for invalid --to status ---
echo "Test 9: exits 1 for invalid --to status"
REPO=$(make_repo)
set +e
run_cc "$REPO" --ref "1.2" --to "invalid_status" --message "msg" 2>/dev/null
EXIT_CODE=$?
set -e
assert_exit "invalid --to status" "1" "$EXIT_CODE"
rm -rf "$REPO"

# --- Test 10: does not mark done when --to is in_progress ---
echo "Test 10: does not mark done when --to is in_progress"
REPO=$(make_repo)
(cd "$REPO" && echo "x" > x.rb && git add x.rb)
run_cc "$REPO" --ref "1.2" --to "in_progress" --message "1.2 — started"
assert_file_contains     "1.2 still unchecked" "- [ ] 1.2 —" "$REPO/IMPLEMENTATION_PLAN.md"
assert_file_not_contains "1.2 not marked done" "- [x] 1.2 —" "$REPO/IMPLEMENTATION_PLAN.md"
rm -rf "$REPO"

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
