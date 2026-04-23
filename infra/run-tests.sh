#!/bin/bash
# run-tests — wrapper for running tests from inside the agent container.
# Calls the Go runner sidecar's /test endpoint instead of docker compose directly.
#
# Usage:
#   run-tests                          # run full test suite
#   run-tests spec/path/to/spec.rb     # run a specific spec
#
# Required env vars: RUNNER_URL, RUNNER_USERNAME, RUNNER_PASSWORD
set -euo pipefail

RUNNER_URL="${RUNNER_URL:?RUNNER_URL must be set}"
RUNNER_USERNAME="${RUNNER_USERNAME:?RUNNER_USERNAME must be set}"
RUNNER_PASSWORD="${RUNNER_PASSWORD:?RUNNER_PASSWORD must be set}"

SPEC="${1:-}"

if [ -n "$SPEC" ]; then
    BODY=$(jq -n --arg spec "$SPEC" '{spec: $spec}')
else
    BODY='{}'
fi

RESPONSE=$(curl -sf -X POST \
    -u "${RUNNER_USERNAME}:${RUNNER_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    "${RUNNER_URL}/test")

EXIT_CODE=$(echo "$RESPONSE" | jq -r '.exit_code')
OUTPUT=$(echo "$RESPONSE" | jq -r '.output')

echo "$OUTPUT"
exit "$EXIT_CODE"
