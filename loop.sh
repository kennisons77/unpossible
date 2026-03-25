#!/bin/bash
# Usage: ./loop.sh [plan|research|review|promote] [max_iterations|id]
# Examples:
#   ./loop.sh              # Build mode, unlimited iterations
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan 1       # Plan mode, 1 iteration
#   ./loop.sh research 3   # Research mode, idea ID 3
#   ./loop.sh review       # Review mode
#   ./loop.sh promote 3    # Promote idea ID 3 to a spec
#
# Environment variables:
#   AGENT   - "claude" (default), "kiro", or a custom command (reads stdin)
#   MODEL   - model name passed to the agent

TEMP_PROMPT=""
AGENT_OUTPUT_FILE=""
cleanup() {
    rm -f "$TEMP_PROMPT" "$AGENT_OUTPUT_FILE"
}
trap cleanup EXIT

# --- Agent configuration ---
AGENT=${AGENT:-claude}
case "$AGENT" in
    claude)
        MODEL=${MODEL:-opus}
        AGENT_CMD="claude -p --dangerously-skip-permissions --output-format=stream-json --model $MODEL --verbose"
        ;;
    kiro)
        MODEL=${MODEL:-claude-sonnet-4.5}
        # kiro reads prompt as positional arg, not stdin; -- prevents flag interpretation
        AGENT_CMD="kiro-cli chat --no-interactive --trust-all-tools --model $MODEL --"
        ;;
    *)
        AGENT_CMD="$AGENT"
        ;;
esac

# --- Active project ---
if [ ! -f "ACTIVE_PROJECT" ]; then
    echo "Error: ACTIVE_PROJECT file not found"; exit 1
fi
PROJECT_NAME=$(cat ACTIVE_PROJECT | tr -d '[:space:]')
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: ACTIVE_PROJECT is empty"; exit 1
fi
if [ "$PROJECT_NAME" = "unpossible" ]; then
    PROJECT_DIR="."
else
    PROJECT_DIR="projects/$PROJECT_NAME"
    [ -d "$PROJECT_DIR" ] || { echo "Error: '$PROJECT_DIR' does not exist"; exit 1; }
fi

# --- Parse arguments ---
MODE="build"
MAX_ITERATIONS=0
IDEA_ID=""

case "$1" in
    plan)     MODE="plan";     MAX_ITERATIONS=${2:-0} ;;
    research) MODE="research"; IDEA_ID="$2"
              [ -z "$IDEA_ID" ] && { echo "Usage: ./loop.sh research <id>"; exit 1; }
              MAX_ITERATIONS=1 ;;
    review)   MODE="review";   MAX_ITERATIONS=1 ;;
    promote)  MODE="promote";  IDEA_ID="$2"
              [ -z "$IDEA_ID" ] && { echo "Usage: ./loop.sh promote <id>"; exit 1; } ;;
    [0-9]*)   MODE="build";    MAX_ITERATIONS=$1 ;;
esac

# --- Promote mode (no loop needed) ---
if [ "$MODE" = "promote" ]; then
    IDEAS_FILE="$PROJECT_DIR/IDEAS.md"
    [ -f "$IDEAS_FILE" ] || { echo "Error: $IDEAS_FILE not found"; exit 1; }

    IDEA_CONTENT=$(awk -v id="$IDEA_ID" '
        /^## \[/ { if (found) exit; if ($0 ~ "\\[" id "\\]") found=1 }
        found { print }
    ' "$IDEAS_FILE")
    [ -z "$IDEA_CONTENT" ] && { echo "Error: idea $IDEA_ID not found"; exit 1; }

    IDEA_TITLE=$(echo "$IDEA_CONTENT" | grep -m1 "^## \[" | sed 's/^## \[[0-9]*\] //')
    IDEA_STATUS=$(echo "$IDEA_CONTENT" | grep "^- \*\*Status:\*\*" | sed 's/^- \*\*Status:\*\* //')
    PROMOTED_LINE=$(echo "$IDEA_CONTENT" | grep "^- \*\*Promoted:\*\*")

    echo "$PROMOTED_LINE" | grep -q "^- \*\*Promoted:\*\* ." && {
        echo "Error: idea $IDEA_ID already promoted"; exit 1; }
    [ "$IDEA_STATUS" != "ready" ] && {
        echo "Error: idea $IDEA_ID status is '$IDEA_STATUS', must be 'ready'"; exit 1; }

    SPEC_FILENAME=$(echo "$IDEA_TITLE" | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9]/-/g;s/--*/-/g;s/^-//;s/-$//')
    SPEC_PATH="$PROJECT_DIR/specs/$SPEC_FILENAME.md"
    printf '# %s\n\n%s\n' "$IDEA_TITLE" "$IDEA_CONTENT" > "$SPEC_PATH"
    echo "Created: $SPEC_PATH"

    PROMOTED_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    awk -v id="$IDEA_ID" -v ts="$PROMOTED_TIMESTAMP" '
        /^## \[/ { if (in_entry) in_entry=0; if ($0 ~ "\\[" id "\\]") in_entry=1 }
        in_entry && /^- \*\*Status:\*\*/   { print "- **Status:** promoted"; next }
        in_entry && /^- \*\*Promoted:\*\*/ { print "- **Promoted:** " ts; next }
        { print }
    ' "$IDEAS_FILE" > "$IDEAS_FILE.tmp" && mv "$IDEAS_FILE.tmp" "$IDEAS_FILE"
    echo "Updated IDEAS.md: idea $IDEA_ID promoted at $PROMOTED_TIMESTAMP"
    exit 0
fi

# --- Resolve prompt file ---
PROMPT_BASENAME="PROMPT_${MODE}.md"
if [ -f "$PROJECT_DIR/$PROMPT_BASENAME" ]; then
    PROMPT_FILE="$PROJECT_DIR/$PROMPT_BASENAME"
else
    PROMPT_FILE="$PROMPT_BASENAME"
fi
[ -f "$PROMPT_FILE" ] || { echo "Error: $PROMPT_FILE not found"; exit 1; }

# --- Research mode: inject idea content into prompt ---
if [ "$MODE" = "research" ]; then
    IDEAS_FILE="$PROJECT_DIR/IDEAS.md"
    [ -f "$IDEAS_FILE" ] || { echo "Error: $IDEAS_FILE not found"; exit 1; }

    IDEA_CONTENT=$(awk -v id="$IDEA_ID" '
        /^## \[/ { if (found) exit; if ($0 ~ "\\[" id "\\]") found=1 }
        found { print }
    ' "$IDEAS_FILE")
    [ -z "$IDEA_CONTENT" ] && { echo "Error: idea $IDEA_ID not found"; exit 1; }

    TEMP_PROMPT="/tmp/prompt_research_$$.md"
    sed "s|{IDEA_CONTENT}|$IDEA_CONTENT|" "$PROMPT_FILE" > "$TEMP_PROMPT"
    PROMPT_FILE="$TEMP_PROMPT"
fi

# --- Git / branch setup ---
GIT_DIR="$PROJECT_DIR"
CURRENT_BRANCH=$(git -C "$GIT_DIR" branch --show-current)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    WORK_BRANCH="ralph/$(date +%Y%m%d-%H%M%S)"
    git -C "$GIT_DIR" checkout -b "$WORK_BRANCH"
    CURRENT_BRANCH="$WORK_BRANCH"
    echo "Created branch: $CURRENT_BRANCH"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Agent:  $AGENT"
echo "Model:  ${MODEL:-(agent default)}"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
[ "$MAX_ITERATIONS" -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PR_OPENED=0
ITERATION=0

while true; do
    if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    # Run agent — stream live, capture for RALPH_ signal checks
    AGENT_OUTPUT_FILE="/tmp/ralph_output_$$.txt"
    if [ "$AGENT" = "kiro" ]; then
        $AGENT_CMD "$(cat "$PROMPT_FILE")" 2>&1 | tee "$AGENT_OUTPUT_FILE"
    else
        cat "$PROMPT_FILE" | $AGENT_CMD 2>&1 | tee "$AGENT_OUTPUT_FILE"
    fi
    AGENT_OUTPUT=$(cat "$AGENT_OUTPUT_FILE")
    rm -f "$AGENT_OUTPUT_FILE"

    if echo "$AGENT_OUTPUT" | grep -q "RALPH_COMPLETE"; then
        echo "RALPH_COMPLETE — all tasks done"
        exit 0
    fi

    if echo "$AGENT_OUTPUT" | grep -q "RALPH_WAITING"; then
        QUESTION=$(echo "$AGENT_OUTPUT" | grep "RALPH_WAITING" | sed 's/.*RALPH_WAITING[: ]*//')
        echo ""
        echo "⏸  RALPH_WAITING — agent needs input"
        [ -n "$QUESTION" ] && echo "   $QUESTION"
        echo -n "Your response: "
        read -r USER_RESPONSE
        TEMP_REPLY="/tmp/prompt_reply_$$.md"
        { cat "$PROMPT_FILE"; echo ""; echo "## Human response"; echo "$USER_RESPONSE"; } > "$TEMP_REPLY"
        PROMPT_FILE="$TEMP_REPLY"
        continue
    fi

    # Push (skip for unpossible itself)
    if [ "$GIT_DIR" != "." ]; then
        git -C "$GIT_DIR" push origin "$CURRENT_BRANCH" 2>/dev/null || \
            git -C "$GIT_DIR" push -u origin "$CURRENT_BRANCH" 2>/dev/null || \
            echo "Warning: git push failed — continuing"

        if [ "$PR_OPENED" -eq 0 ] && command -v gh &>/dev/null; then
            gh -C "$GIT_DIR" pr create \
                --title "ralph: $MODE loop on $CURRENT_BRANCH" \
                --body "Automated PR opened by loop.sh ($AGENT / $MODE mode)." \
                --draft && PR_OPENED=1 || echo "Warning: gh pr create failed — continuing"
        fi
    fi

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done
