#!/bin/bash
set -euo pipefail

# Delegates test execution to the runner sidecar via HTTP.
# Usage: run-tests [spec_path]

SPEC="${1:-}"
PAYLOAD="{}"
if [ -n "$SPEC" ]; then
  PAYLOAD=$(jq -n --arg spec "$SPEC" '{spec: $spec}')
fi

curl -sf -u "${RUNNER_USERNAME}:${RUNNER_PASSWORD}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "${RUNNER_URL}/run-tests"
