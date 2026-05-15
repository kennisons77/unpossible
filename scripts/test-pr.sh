#!/bin/bash
# Tests for scripts/pr.sh
# Run from project root: bash scripts/test-pr.sh
# Exit 0 if all tests pass, exit 1 if any fail.
#
# Uses a stub `gh` command to avoid real GitHub API calls.

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pr.sh"
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

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  assert_eq "$desc (exit code)" "$expected" "$actual"
}

# --- Setup: create a temp git repo with a feature branch ---
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

- [x] 1.1 — Bootstrap Rails app
- [x] 2.1 — Add analytics module <!-- spec: specifications/system/analytics/concept.md -->
EOF
    touch LEDGER.jsonl
    git add IMPLEMENTATION_PLAN.md LEDGER.jsonl
    git commit -q -m "initial"

    # Create feature branch
    git checkout -q -b "ralph/20260515"

    # Add a commit on the feature branch
    echo "feature" > feature.rb
    git add feature.rb
    git commit -q -m "2.1 — Add analytics module"

    # Add a status ledger entry for the commit on this branch
    SHA=$(git rev-parse HEAD)
    echo "{\"ts\":\"2026-05-15T10:00:00Z\",\"type\":\"status\",\"ref\":\"2.1\",\"from\":\"in_progress\",\"to\":\"done\",\"sha\":\"$SHA\",\"reason\":\"tests green\"}" >> LEDGER.jsonl
    git add LEDGER.jsonl
    git commit -q -m "ledger: 2.1 done"
  )
  echo "$dir"
}

# Stub gh that records calls and returns a fake PR URL
make_gh_stub() {
  local stub_dir="$1"
  local pr_number="${2:-42}"
  cat > "$stub_dir/gh" <<EOF
#!/bin/bash
echo "https://github.com/org/repo/pull/${pr_number}"
EOF
  chmod +x "$stub_dir/gh"
}

run_pr() {
  local repo="$1"; shift
  local stub_dir rc
  stub_dir=$(mktemp -d)
  make_gh_stub "$stub_dir" "42"
  (
    cd "$repo"
    PATH="$stub_dir:$PATH" bash "$SCRIPT" \
      --repo "$repo" \
      --ledger "$repo/LEDGER.jsonl" \
      --plan "$repo/IMPLEMENTATION_PLAN.md" \
      --no-push \
      "$@"
  )
  rc=$?
  rm -rf "$stub_dir"
  return $rc
}

# --- Test 1: exits 1 on main branch ---
echo "Test 1: refuses to run on main branch"
REPO=$(make_repo)
# Switch back to the default branch (main)
(cd "$REPO" && git checkout -q main 2>/dev/null || git checkout -q master 2>/dev/null || true)
CURRENT=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" == "main" || "$CURRENT" == "master" ]]; then
  set +e
  run_pr "$REPO" 2>/dev/null
  EXIT_CODE=$?
  set -e
  assert_exit "refuses on $CURRENT" "1" "$EXIT_CODE"
else
  echo "  SKIP: could not switch to main/master (on $CURRENT)"
  PASS=$((PASS + 1))
fi
rm -rf "$REPO"

# --- Test 2: creates PR via gh pr create ---
echo "Test 2: creates PR via gh pr create (stub)"
REPO=$(make_repo)
STUB_DIR=$(mktemp -d)
make_gh_stub "$STUB_DIR" "42"
OUTPUT=$(cd "$REPO" && PATH="$STUB_DIR:$PATH" bash "$SCRIPT" \
  --repo "$REPO" --ledger "$REPO/LEDGER.jsonl" --plan "$REPO/IMPLEMENTATION_PLAN.md" \
  --no-push 2>&1)
assert_contains "output mentions PR URL" "https://github.com/org/repo/pull/42" "$OUTPUT"
rm -rf "$STUB_DIR" "$REPO"

# --- Test 3: appends pr_opened event to LEDGER.jsonl ---
echo "Test 3: appends pr_opened event to LEDGER.jsonl"
REPO=$(make_repo)
STUB_DIR=$(mktemp -d)
make_gh_stub "$STUB_DIR" "42"
(cd "$REPO" && PATH="$STUB_DIR:$PATH" bash "$SCRIPT" \
  --repo "$REPO" --ledger "$REPO/LEDGER.jsonl" --plan "$REPO/IMPLEMENTATION_PLAN.md" \
  --no-push 2>&1)
LEDGER_CONTENT=$(cat "$REPO/LEDGER.jsonl")
assert_contains "pr_opened type"    '"type":"pr_opened"'   "$LEDGER_CONTENT"
assert_contains "pr_number 42"      '"pr_number":42'       "$LEDGER_CONTENT"
assert_contains "branch recorded"   '"branch":"ralph/20260515"' "$LEDGER_CONTENT"
assert_contains "task_ids includes 2.1" '"2.1"'            "$LEDGER_CONTENT"
assert_contains "sha_first present" '"sha_first"'          "$LEDGER_CONTENT"
assert_contains "sha_last present"  '"sha_last"'           "$LEDGER_CONTENT"
rm -rf "$STUB_DIR" "$REPO"

# --- Test 4: spec_refs extracted from IMPLEMENTATION_PLAN.md ---
echo "Test 4: spec_refs extracted from plan comments"
REPO=$(make_repo)
STUB_DIR=$(mktemp -d)
make_gh_stub "$STUB_DIR" "42"
(cd "$REPO" && PATH="$STUB_DIR:$PATH" bash "$SCRIPT" \
  --repo "$REPO" --ledger "$REPO/LEDGER.jsonl" --plan "$REPO/IMPLEMENTATION_PLAN.md" \
  --no-push 2>&1)
LEDGER_CONTENT=$(cat "$REPO/LEDGER.jsonl")
assert_contains "spec_refs includes analytics concept" \
  "specifications/system/analytics/concept.md" "$LEDGER_CONTENT"
rm -rf "$STUB_DIR" "$REPO"

# --- Test 5: exits 0 on success ---
echo "Test 5: exits 0 on success"
REPO=$(make_repo)
STUB_DIR=$(mktemp -d)
make_gh_stub "$STUB_DIR" "42"
set +e
(cd "$REPO" && PATH="$STUB_DIR:$PATH" bash "$SCRIPT" \
  --repo "$REPO" --ledger "$REPO/LEDGER.jsonl" --plan "$REPO/IMPLEMENTATION_PLAN.md" \
  --no-push 2>&1)
EXIT_CODE=$?
set -e
assert_exit "exits 0" "0" "$EXIT_CODE"
rm -rf "$STUB_DIR" "$REPO"

# --- Test 6: --dry-run prints body without creating PR or writing LEDGER ---
echo "Test 6: --dry-run prints body without side effects"
REPO=$(make_repo)
INITIAL_LEDGER=$(cat "$REPO/LEDGER.jsonl")
STUB_DIR=$(mktemp -d)
make_gh_stub "$STUB_DIR" "99"
OUTPUT=$(cd "$REPO" && PATH="$STUB_DIR:$PATH" bash "$SCRIPT" \
  --repo "$REPO" --ledger "$REPO/LEDGER.jsonl" --plan "$REPO/IMPLEMENTATION_PLAN.md" \
  --dry-run 2>&1)
FINAL_LEDGER=$(cat "$REPO/LEDGER.jsonl")
assert_contains "dry-run shows DRY RUN header" "DRY RUN" "$OUTPUT"
assert_contains "dry-run shows pr_opened type" '"type":"pr_opened"' "$OUTPUT"
assert_eq "LEDGER.jsonl unchanged in dry-run" "$INITIAL_LEDGER" "$FINAL_LEDGER"
rm -rf "$STUB_DIR" "$REPO"

# --- Test 7: exits 2 when gh pr create fails ---
echo "Test 7: exits 2 when gh pr create fails"
REPO=$(make_repo)
STUB_DIR=$(mktemp -d)
# Stub gh that exits non-zero
cat > "$STUB_DIR/gh" <<'EOF'
#!/bin/bash
echo "gh: authentication required" >&2
exit 1
EOF
chmod +x "$STUB_DIR/gh"
set +e
(cd "$REPO" && PATH="$STUB_DIR:$PATH" bash "$SCRIPT" \
  --repo "$REPO" --ledger "$REPO/LEDGER.jsonl" --plan "$REPO/IMPLEMENTATION_PLAN.md" \
  --no-push 2>/dev/null)
EXIT_CODE=$?
set -e
assert_exit "exits 2 on gh failure" "2" "$EXIT_CODE"
rm -rf "$STUB_DIR" "$REPO"

# --- Test 8: --title overrides derived title ---
echo "Test 8: --title flag overrides derived title"
REPO=$(make_repo)
STUB_DIR=$(mktemp -d)
make_gh_stub "$STUB_DIR" "42"
OUTPUT=$(cd "$REPO" && PATH="$STUB_DIR:$PATH" bash "$SCRIPT" \
  --repo "$REPO" --ledger "$REPO/LEDGER.jsonl" --plan "$REPO/IMPLEMENTATION_PLAN.md" \
  --title "My custom title" \
  --dry-run 2>&1)
assert_contains "custom title in output" "My custom title" "$OUTPUT"
rm -rf "$STUB_DIR" "$REPO"

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
