#!/usr/bin/env bats

setup() {
  export TEST_DIR="/tmp/bats-new-project-$$"
  mkdir -p "$TEST_DIR"
  cp /workspace/new-project.sh "$TEST_DIR/"
  cd "$TEST_DIR"
  git config --global user.email "test@example.com"
  git config --global user.name "Test"
  git config --global init.defaultBranch main
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "new-project.sh is executable" {
  [ -x "/workspace/new-project.sh" ]
}

@test "new-project.sh exits non-zero when no project name provided" {
  run bash new-project.sh
  [ "$status" -ne 0 ]
  [[ "$output" =~ "project name required" ]]
}

@test "new-project.sh exits non-zero when project name is empty string" {
  run bash new-project.sh ""
  [ "$status" -ne 0 ]
  [[ "$output" =~ "cannot be empty" ]]
}

@test "new-project.sh exits non-zero when project name contains slashes" {
  run bash new-project.sh "my/project"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "cannot contain slashes" ]]
}

@test "new-project.sh exits non-zero when project name contains backslashes" {
  run bash new-project.sh 'my\project'
  [ "$status" -ne 0 ]
  [[ "$output" =~ "cannot contain slashes" ]]
}

@test "new-project.sh exits non-zero when project name contains spaces" {
  run bash new-project.sh "my project"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "cannot contain spaces" ]]
}

@test "new-project.sh creates projects directory structure" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  [ -d "projects/testproject" ]
  [ -d "projects/testproject/specs" ]
  [ -d "projects/testproject/src" ]
  [ -d "projects/testproject/src/test" ]
  [ -d "projects/testproject/infra" ]
}

@test "new-project.sh creates spec files" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  [ -f "projects/testproject/specs/prd.md" ]
  [ -f "projects/testproject/specs/plan.md" ]
  
  # Verify prd.md has required sections
  grep -q "Technical Constraints" projects/testproject/specs/prd.md
  grep -q "Language:" projects/testproject/specs/prd.md
  grep -q "Base image:" projects/testproject/specs/prd.md
  grep -q "Test command" projects/testproject/specs/prd.md
}

@test "new-project.sh creates IMPLEMENTATION_PLAN.md" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  [ -f "projects/testproject/IMPLEMENTATION_PLAN.md" ]
  grep -q "IMPLEMENTATION_PLAN" projects/testproject/IMPLEMENTATION_PLAN.md
  grep -q "Phase 0" projects/testproject/IMPLEMENTATION_PLAN.md
}

@test "new-project.sh creates Dockerfile" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  [ -f "projects/testproject/infra/Dockerfile" ]
  grep -q "FROM" projects/testproject/infra/Dockerfile
}

@test "new-project.sh creates docker-compose.yml" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  [ -f "projects/testproject/infra/docker-compose.yml" ]
  grep -q "services:" projects/testproject/infra/docker-compose.yml
  grep -q "app:" projects/testproject/infra/docker-compose.yml
  grep -q "test:" projects/testproject/infra/docker-compose.yml
}

@test "new-project.sh creates test directory with .gitkeep" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  [ -f "projects/testproject/src/test/.gitkeep" ]
}

@test "new-project.sh exits non-zero when project already exists" {
  bash new-project.sh testproject
  run bash new-project.sh testproject
  [ "$status" -ne 0 ]
  [[ "$output" =~ "already exists" ]]
}

@test "new-project.sh accepts valid project names with hyphens" {
  run bash new-project.sh my-test-project
  [ "$status" -eq 0 ]
  [ -d "projects/my-test-project" ]
}

@test "new-project.sh accepts valid project names with underscores" {
  run bash new-project.sh my_test_project
  [ "$status" -eq 0 ]
  [ -d "projects/my_test_project" ]
}

@test "new-project.sh substitutes project name in prd.md" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  grep -q "Product Requirements Document — testproject" projects/testproject/specs/prd.md
  ! grep -q "\[PROJECT_NAME\]" projects/testproject/specs/prd.md
}

@test "new-project.sh substitutes project name in plan.md" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  grep -q "Plan — testproject" projects/testproject/specs/plan.md
  ! grep -q "\[PROJECT_NAME\]" projects/testproject/specs/plan.md
}

@test "new-project.sh substitutes project name in IMPLEMENTATION_PLAN.md" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  grep -q "IMPLEMENTATION_PLAN — testproject" projects/testproject/IMPLEMENTATION_PLAN.md
  ! grep -q "\[PROJECT_NAME\]" projects/testproject/IMPLEMENTATION_PLAN.md
}

@test "new-project.sh initialises a git repo in the project dir" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  [ -d "projects/testproject/.git" ]
}

@test "new-project.sh sets remote when url provided" {
  run bash new-project.sh testproject https://github.com/example/testproject.git
  [ "$status" -eq 0 ]
  run git -C projects/testproject remote get-url origin
  [ "$status" -eq 0 ]
  [[ "$output" =~ "testproject.git" ]]
}

@test "new-project.sh generates Dockerfile with correct COPY path" {
  run bash new-project.sh testproject
  [ "$status" -eq 0 ]
  grep -q "COPY src/ \." projects/testproject/infra/Dockerfile
  ! grep -q "COPY \.\./src/" projects/testproject/infra/Dockerfile
}
