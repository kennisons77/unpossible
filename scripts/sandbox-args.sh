#!/bin/bash
# Maps (agent, mode) to agent-specific CLI flags for sbx run.
# Usage: scripts/sandbox-args.sh <agent> <mode>
# Modes: run, interview, review

AGENT="$1"
MODE="$2"

if [ -z "$AGENT" ] || [ -z "$MODE" ]; then
  echo "Usage: sandbox-args.sh <agent> <mode>" >&2
  exit 1
fi

case "$AGENT" in
  kiro)
    case "$MODE" in
      run)       echo "--tui" ;;
      interview) echo "chat --tui --agent interview" ;;
      review)    echo "chat --tui --agent review" ;;
      *)         echo "Unknown mode for kiro: $MODE" >&2; exit 1 ;;
    esac
    ;;
  claude)
    case "$MODE" in
      run)       echo "--dangerously-skip-permissions" ;;
      interview) echo "--dangerously-skip-permissions" ;;
      review)    echo "--dangerously-skip-permissions" ;;
      *)         echo "Unknown mode for claude: $MODE" >&2; exit 1 ;;
    esac
    ;;
  *)
    echo "Unknown agent: $AGENT — add a case in scripts/sandbox-args.sh" >&2
    exit 1
    ;;
esac
