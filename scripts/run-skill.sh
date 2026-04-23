#!/bin/bash
# Runs a skill prompt through the configured agent.
# Usage: scripts/run-skill.sh <agent> <prompt-file> [model]
# The prompt file contents are sent to the agent in the correct way per agent.

AGENT="$1"
PROMPT_FILE="$2"
MODEL="$3"

if [ -z "$AGENT" ] || [ -z "$PROMPT_FILE" ]; then
  echo "Usage: run-skill.sh <agent> <prompt-file> [model]" >&2
  exit 1
fi

[ -f "$PROMPT_FILE" ] || { echo "Error: $PROMPT_FILE not found" >&2; exit 1; }

case "$AGENT" in
  kiro)
    MODEL_FLAG=""
    [ -n "$MODEL" ] && MODEL_FLAG="--model $MODEL"
    exec kiro-cli chat --no-interactive --trust-all-tools $MODEL_FLAG -- "$(cat "$PROMPT_FILE")"
    ;;
  claude)
    MODEL_FLAG=""
    [ -n "$MODEL" ] && MODEL_FLAG="--model $MODEL"
    exec claude -p --dangerously-skip-permissions $MODEL_FLAG < "$PROMPT_FILE"
    ;;
  *)
    exec $AGENT < "$PROMPT_FILE"
    ;;
esac
