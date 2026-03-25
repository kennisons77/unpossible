#!/usr/bin/env bats

setup() {
  export TEST_DIR="/tmp/bats-review-test-$$"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"
  
  # Setup minimal git repo
  git init
  git config user.email "test@test.com"
  git config user.name "Test"
  
  # Copy loop.sh
  cp /workspace/loop.sh .
  
  # Create ACTIVE_PROJECT
  echo "unpossible" > ACTIVE_PROJECT
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "loop.sh review loads PROMPT_review.md" {
  cat > PROMPT_review.md << 'EOF'
# Review Mode

Test prompt content.
EOF

  # Mock the agent command to just echo mode info
  export AGENT="echo"
  
  run bash loop.sh review
  [[ "$output" =~ "Mode:   review" ]]
  [[ "$output" =~ "PROMPT_review.md" ]]
}

@test "loop.sh review exits non-zero if PROMPT_review.md not found" {
  run bash loop.sh review
  [ "$status" -ne 0 ]
  [[ "$output" =~ "PROMPT_review.md not found" ]]
}

@test "loop.sh accepts review as valid mode argument" {
  cat > PROMPT_review.md << 'EOF'
# Review Mode

Test prompt content.
EOF

  # Mock the agent command
  export AGENT="echo"
  
  run bash loop.sh review
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "unknown mode" ]]
}
