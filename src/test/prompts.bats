#!/usr/bin/env bats

@test "PROMPT_plan.md references specs/features/ directory" {
  grep -q 'specs/features' /workspace/PROMPT_plan.md
}
