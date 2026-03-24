#!/usr/bin/env bats

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
