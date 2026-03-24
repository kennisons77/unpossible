#!/bin/bash
# Usage: ./loop.sh [plan] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, unlimited iterations
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited iterations
#   ./loop.sh plan 5       # Plan mode, max 5 iterations
#
# Environment variables:
#   AGENT   - AI agent to use: "claude" (default), "kiro", or a custom command
#   MODEL   - Model name passed to the agent (default depends on agent)
#
# Examples:
#   AGENT=kiro ./loop.sh
#   AGENT=kiro MODEL=claude-sonnet-4.5 ./loop.sh 10
#   AGENT=claude MODEL=sonnet ./loop.sh plan 1

# --- Agent configuration ---
AGENT=${AGENT:-claude}

case "$AGENT" in
    claude)
        MODEL=${MODEL:-opus}
        AGENT_CMD="claude -p --dangerously-skip-permissions --output-format=stream-json --model $MODEL --verbose"
        ;;
    kiro)
        MODEL=${MODEL:-claude-sonnet-4.5}
        AGENT_CMD="kiro-cli chat --no-interactive --trust-all-tools --model $MODEL"
        ;;
    *)
        # Custom agent: full command string that reads prompt from stdin
        AGENT_CMD="$AGENT"
        ;;
esac

# --- Parse mode/iteration arguments ---
if [ "$1" = "plan" ]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=$1
else
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=0
fi

# --- Branch management ---
# If on main/master, create a timestamped work branch before doing anything
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    WORK_BRANCH="ralph/$(date +%Y%m%d-%H%M%S)"
    git checkout -b "$WORK_BRANCH"
    CURRENT_BRANCH="$WORK_BRANCH"
    echo "Created branch: $CURRENT_BRANCH"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Agent:  $AGENT"
echo "Model:  ${MODEL:-(agent default)}"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

PR_OPENED=0
ITERATION=0

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    cat "$PROMPT_FILE" | $AGENT_CMD

    # Push branch; set upstream tracking on first push
    git push origin "$CURRENT_BRANCH" 2>/dev/null || \
        git push -u origin "$CURRENT_BRANCH"

    # Open a draft PR after the first successful push (requires gh CLI)
    if [ $PR_OPENED -eq 0 ] && command -v gh &>/dev/null; then
        gh pr create \
            --title "ralph: $MODE loop on $CURRENT_BRANCH" \
            --body "Automated PR opened by loop.sh ($AGENT / $MODE mode)." \
            --draft \
            && PR_OPENED=1 \
            || echo "Warning: gh pr create failed — continuing without PR"
    fi

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done
