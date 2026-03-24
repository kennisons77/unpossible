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
#   AGENT=kiro MODEL=claude-sonnet-4-5 ./loop.sh 10
#   AGENT=claude MODEL=sonnet ./loop.sh plan 1

# --- Agent configuration ---
AGENT=${AGENT:-claude}

# Build the command to invoke the agent in headless/non-interactive mode
case "$AGENT" in
    claude)
        MODEL=${MODEL:-opus}
        # -p: headless, --dangerously-skip-permissions: auto-approve, --output-format=stream-json: structured output
        AGENT_CMD="claude -p --dangerously-skip-permissions --output-format=stream-json --model $MODEL --verbose"
        ;;
    kiro)
        MODEL=${MODEL:-claude-sonnet-4-5}
        # --no-interactive: headless, -a/--trust-all-tools: auto-approve all tools
        AGENT_CMD="kiro-cli chat --no-interactive --trust-all-tools --model $MODEL"
        ;;
    *)
        # Custom agent: AGENT should be a full command that reads prompt from stdin
        # e.g. AGENT="my-llm-cli --headless --model gpt-4o"
        AGENT_CMD="$AGENT"
        ;;
esac

# Parse mode/iteration arguments
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

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

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

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    cat "$PROMPT_FILE" | $AGENT_CMD

    git push origin "$CURRENT_BRANCH" || {
        echo "Failed to push. Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done
