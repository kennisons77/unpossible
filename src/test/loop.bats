#!/usr/bin/env bats

setup() {
  export TEST_DIR="/tmp/bats-test-$$"
  mkdir -p "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "ACTIVE_PROJECT file exists" {
  [ -f "/workspace/ACTIVE_PROJECT" ]
}

@test "ACTIVE_PROJECT is non-empty" {
  run cat /workspace/ACTIVE_PROJECT
  [ -n "$output" ]
}

@test "loop.sh is executable" {
  [ -x "/workspace/loop.sh" ]
}

@test "loop.sh exits non-zero when ACTIVE_PROJECT is missing" {
  cd "$TEST_DIR"
  cp /workspace/loop.sh .
  mkdir -p projects/test-project
  echo "PROMPT_build.md content" > PROMPT_build.md
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  
  run bash loop.sh
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ACTIVE_PROJECT file not found" ]]
}

@test "loop.sh exits non-zero when ACTIVE_PROJECT is empty" {
  cd "$TEST_DIR"
  cp /workspace/loop.sh .
  touch ACTIVE_PROJECT
  mkdir -p projects/test-project
  echo "PROMPT_build.md content" > PROMPT_build.md
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  
  run bash loop.sh
  [ "$status" -ne 0 ]
  [[ "$output" =~ "ACTIVE_PROJECT is empty" ]]
}

@test "loop.sh exits non-zero when project directory does not exist" {
  cd "$TEST_DIR"
  cp /workspace/loop.sh .
  echo "nonexistent-project" > ACTIVE_PROJECT
  echo "PROMPT_build.md content" > PROMPT_build.md
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  
  run bash loop.sh
  [ "$status" -ne 0 ]
  [[ "$output" =~ "project directory" ]] && [[ "$output" =~ "does not exist" ]]
}

@test "loop.sh uses repo root paths for unpossible project" {
  cd "$TEST_DIR"
  cp /workspace/loop.sh .
  echo "unpossible" > ACTIVE_PROJECT
  echo "PROMPT_build.md content" > PROMPT_build.md
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  git add -A
  git commit -m "init"
  
  run bash -c 'bash loop.sh 2>&1 | head -20'
  [[ "$output" =~ "Prompt: PROMPT_build.md" ]] || [[ "$output" =~ "Prompt: ./PROMPT_build.md" ]]
}

@test "loop.sh uses projects subdirectory for non-unpossible project" {
  cd "$TEST_DIR"
  cp /workspace/loop.sh .
  echo "myproject" > ACTIVE_PROJECT
  mkdir -p projects/myproject
  echo "PROMPT_build.md content" > projects/myproject/PROMPT_build.md
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  git add -A
  git commit -m "init"
  
  run bash -c 'bash loop.sh 2>&1 | head -20'
  [[ "$output" =~ "Prompt: projects/myproject/PROMPT_build.md" ]]
}

@test "loop.sh falls back to root PROMPT when project-level does not exist" {
  cd "$TEST_DIR"
  cp /workspace/loop.sh .
  echo "myproject" > ACTIVE_PROJECT
  mkdir -p projects/myproject
  echo "PROMPT_build.md content" > PROMPT_build.md
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  git add -A
  git commit -m "init"
  
  run bash -c 'bash loop.sh 2>&1 | head -20'
  [[ "$output" =~ "Prompt: PROMPT_build.md" ]]
}

@test "loop.sh accepts plan mode argument" {
  cd "$TEST_DIR"
  cp /workspace/loop.sh .
  echo "unpossible" > ACTIVE_PROJECT
  echo "PROMPT_plan.md content" > PROMPT_plan.md
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  git add -A
  git commit -m "init"
  
  run bash -c 'bash loop.sh plan 2>&1 | head -20'
  [[ "$output" =~ "Mode:   plan" ]]
  [[ "$output" =~ "Prompt: PROMPT_plan.md" ]] || [[ "$output" =~ "Prompt: ./PROMPT_plan.md" ]]
}
