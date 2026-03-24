#!/usr/bin/env bats

setup() {
  export TEST_PROJECT="test-worklog-$$"
  export TEST_DIR="/tmp/$TEST_PROJECT"
  mkdir -p "$TEST_DIR"
  echo "$TEST_PROJECT" > /workspace/ACTIVE_PROJECT
  mkdir -p "/workspace/projects/$TEST_PROJECT"
  
  cat > "/workspace/projects/$TEST_PROJECT/WORKLOG.md" <<EOF
## [1] First task

- **Status:** done
- **Feature:** Test Feature
- **Started:** 2026-03-24T10:00:00Z
- **Completed:** 2026-03-24T10:30:00Z
- **Commit:** abc123

### Summary

First test task completed.

## [2] Second task

- **Status:** in-progress
- **Feature:** Another Feature
- **Started:** 2026-03-24T11:00:00Z
- **Completed:** 
- **Commit:** 

### Summary

Second test task in progress.

## [3] Third task

- **Status:** done
- **Feature:** Test Feature
- **Started:** 2026-03-24T12:00:00Z
- **Completed:** 2026-03-24T12:15:00Z
- **Commit:** def456

### Summary

Third test task completed.
EOF
}

teardown() {
  rm -rf "$TEST_DIR"
  rm -rf "/workspace/projects/$TEST_PROJECT"
  echo "unpossible" > /workspace/ACTIVE_PROJECT
}

@test "worklog.sh is executable" {
  [[ -x /workspace/scripts/worklog.sh ]]
}

@test "worklog.sh list produces table output" {
  run /workspace/scripts/worklog.sh list
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "ID" ]]
  [[ "$output" =~ "TITLE" ]]
  [[ "$output" =~ "STATUS" ]]
  [[ "$output" =~ "FEATURE" ]]
}

@test "worklog.sh show displays entry details" {
  run /workspace/scripts/worklog.sh show 1
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "First task" ]]
  [[ "$output" =~ "done" ]]
  [[ "$output" =~ "Test Feature" ]]
}

@test "worklog.sh show exits non-zero for invalid id" {
  run /workspace/scripts/worklog.sh show 999
  [[ "$status" -ne 0 ]]
}

@test "worklog.sh filter --status=done filters correctly" {
  run /workspace/scripts/worklog.sh filter --status=done
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "First task" ]]
  [[ "$output" =~ "Third task" ]]
  [[ ! "$output" =~ "Second task" ]]
}

@test "worklog.sh filter --status=in-progress filters correctly" {
  run /workspace/scripts/worklog.sh filter --status=in-progress
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "Second task" ]]
  [[ ! "$output" =~ "First task" ]]
  [[ ! "$output" =~ "Third task" ]]
}

@test "worklog.sh filter --feature filters correctly" {
  run /workspace/scripts/worklog.sh filter --feature="Test Feature"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "First task" ]]
  [[ "$output" =~ "Third task" ]]
  [[ ! "$output" =~ "Second task" ]]
}

@test "worklog.sh exits non-zero with no command" {
  run /workspace/scripts/worklog.sh
  [[ "$status" -ne 0 ]]
}

@test "worklog.sh show exits non-zero with no id" {
  run /workspace/scripts/worklog.sh show
  [[ "$status" -ne 0 ]]
}

@test "worklog.sh filter exits non-zero with no argument" {
  run /workspace/scripts/worklog.sh filter
  [[ "$status" -ne 0 ]]
}
