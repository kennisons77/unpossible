#!/bin/bash
# Usage: ./loop.sh [plan|research|review|promote] [max_iterations|id]
# Examples:
#   ./loop.sh              # Build mode, unlimited iterations
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited iterations
#   ./loop.sh plan 5       # Plan mode, max 5 iterations
#   ./loop.sh research 3   # Research mode, idea ID 3
#   ./loop.sh review       # Review mode, analyze last commit
#   ./loop.sh promote 3    # Promote mode, promote idea ID 3
#
# Environment variables:
#   AGENT   - AI agent to use: "claude" (default), "kiro", or a custom command
#   MODEL   - Model name passed to the agent (default depends on agent)
#
# Examples:
#   AGENT=kiro ./loop.sh
#   AGENT=kiro MODEL=claude-sonnet-4.5 ./loop.sh 10
#   AGENT=claude MODEL=sonnet ./loop.sh plan 1

# Cleanup temp files on exit
TEMP_PROMPT=""
cleanup() {
    if [ -n "$TEMP_PROMPT" ] && [ -f "$TEMP_PROMPT" ]; then
        rm -f "$TEMP_PROMPT"
    fi
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
        AGENT_CMD="kiro-cli chat --no-interactive --trust-all-tools --model $MODEL"
        ;;
    *)
        # Custom agent: full command string that reads prompt from stdin
        AGENT_CMD="$AGENT"
        ;;
esac

# --- Read active project ---
if [ ! -f "ACTIVE_PROJECT" ]; then
    echo "Error: ACTIVE_PROJECT file not found at repo root"
    exit 1
fi
PROJECT_NAME=$(cat ACTIVE_PROJECT | tr -d '[:space:]')
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: ACTIVE_PROJECT is empty"
    exit 1
fi
# unpossible works on itself: specs/plan/infra/src live at repo root
if [ "$PROJECT_NAME" = "unpossible" ]; then
    PROJECT_DIR="."
else
    PROJECT_DIR="projects/$PROJECT_NAME"
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "Error: project directory '$PROJECT_DIR' does not exist"
        exit 1
    fi
fi

# --- Parse mode/iteration arguments ---
if [ "$1" = "plan" ]; then
    MODE="plan"
    MAX_ITERATIONS=${2:-0}
elif [ "$1" = "research" ]; then
    MODE="research"
    IDEA_ID="$2"
    if [ -z "$IDEA_ID" ]; then
        echo "Error: research mode requires an idea ID"
        echo "Usage: ./loop.sh research <id>"
        exit 1
    fi
    MAX_ITERATIONS=1
elif [ "$1" = "review" ]; then
    MODE="review"
    MAX_ITERATIONS=1
elif [ "$1" = "promote" ]; then
    MODE="promote"
    IDEA_ID="$2"
    if [ -z "$IDEA_ID" ]; then
        echo "Error: promote mode requires an idea ID"
        echo "Usage: ./loop.sh promote <id>"
        exit 1
    fi
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    MODE="build"
    MAX_ITERATIONS=$1
else
    MODE="build"
    MAX_ITERATIONS=0
fi

# Prompt file: project-local override, else root fallback
PROMPT_BASENAME="PROMPT_${MODE}.md"
if [ -f "$PROJECT_DIR/$PROMPT_BASENAME" ]; then
    PROMPT_FILE="$PROJECT_DIR/$PROMPT_BASENAME"
else
    PROMPT_FILE="$PROMPT_BASENAME"
fi

# Validate prompt file exists before research mode processing
if [ "$MODE" != "promote" ] && [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

# Research mode: validate IDEAS.md exists and extract idea content
if [ "$MODE" = "research" ]; then
    IDEAS_FILE="$PROJECT_DIR/IDEAS.md"
    if [ ! -f "$IDEAS_FILE" ]; then
        echo "Error: IDEAS.md not found at $IDEAS_FILE"
        exit 1
    fi
    
    # Extract the idea entry (from ## [ID] to next ## or EOF)
    IDEA_CONTENT=$(awk -v id="$IDEA_ID" '
        /^## \[/ {
            if (found) exit
            if ($0 ~ "\\[" id "\\]") found=1
        }
        found { print }
    ' "$IDEAS_FILE")
    
    if [ -z "$IDEA_CONTENT" ]; then
        echo "Error: idea ID $IDEA_ID not found in $IDEAS_FILE"
        exit 1
    fi
    
    # Replace {IDEA_CONTENT} placeholder in prompt
    PROMPT_CONTENT=$(cat "$PROMPT_FILE" | sed "s|{IDEA_CONTENT}|$IDEA_CONTENT|")
    TEMP_PROMPT="/tmp/prompt_research_$$.md"
    echo "$PROMPT_CONTENT" > "$TEMP_PROMPT"
    PROMPT_FILE="$TEMP_PROMPT"
fi

# Promote mode: validate idea is ready, create spec file, update IDEAS.md
if [ "$MODE" = "promote" ]; then
    IDEAS_FILE="$PROJECT_DIR/IDEAS.md"
    if [ ! -f "$IDEAS_FILE" ]; then
        echo "Error: IDEAS.md not found at $IDEAS_FILE"
        exit 1
    fi
    
    # Extract the idea entry
    IDEA_CONTENT=$(awk -v id="$IDEA_ID" '
        /^## \[/ {
            if (found) exit
            if ($0 ~ "\\[" id "\\]") found=1
        }
        found { print }
    ' "$IDEAS_FILE")
    
    if [ -z "$IDEA_CONTENT" ]; then
        echo "Error: idea ID $IDEA_ID not found in $IDEAS_FILE"
        exit 1
    fi
    
    # Extract title and status
    IDEA_TITLE=$(echo "$IDEA_CONTENT" | grep -m1 "^## \[" | sed 's/^## \[[0-9]*\] //')
    IDEA_STATUS=$(echo "$IDEA_CONTENT" | grep "^- \*\*Status:\*\*" | sed 's/^- \*\*Status:\*\* //')
    
    # Check if already promoted (field has a value, not just empty)
    PROMOTED_LINE=$(echo "$IDEA_CONTENT" | grep "^- \*\*Promoted:\*\*")
    if echo "$PROMOTED_LINE" | grep -q "^- \*\*Promoted:\*\* ."; then
        PROMOTED_AT=$(echo "$PROMOTED_LINE" | sed 's/^- \*\*Promoted:\*\* //')
        echo "Error: idea $IDEA_ID is already promoted (promoted at: $PROMOTED_AT)"
        exit 1
    fi
    
    # Check if status is ready
    if [ "$IDEA_STATUS" != "ready" ]; then
        echo "Error: idea $IDEA_ID status is '$IDEA_STATUS', must be 'ready' to promote"
        exit 1
    fi
    
    # Slugify title for filename
    SPEC_FILENAME=$(echo "$IDEA_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    SPEC_PATH="$PROJECT_DIR/specs/$SPEC_FILENAME.md"
    
    # Create spec file
    cat > "$SPEC_PATH" << EOF
# $IDEA_TITLE

$IDEA_CONTENT
EOF
    
    echo "Created spec file: $SPEC_PATH"
    
    # Update IDEAS.md: change status to promoted, add timestamp
    PROMOTED_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    awk -v id="$IDEA_ID" -v ts="$PROMOTED_TIMESTAMP" '
        /^## \[/ {
            if (in_entry) in_entry=0
            if ($0 ~ "\\[" id "\\]") in_entry=1
        }
        {
            if (in_entry && /^- \*\*Status:\*\*/) {
                print "- **Status:** promoted"
            } else if (in_entry && /^- \*\*Promoted:\*\*/) {
                print "- **Promoted:** " ts
            } else {
                print
            }
        }
    ' "$IDEAS_FILE" > "$IDEAS_FILE.tmp"
    mv "$IDEAS_FILE.tmp" "$IDEAS_FILE"
    
    echo "Updated IDEAS.md: idea $IDEA_ID promoted at $PROMOTED_TIMESTAMP"
    exit 0
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

PR_OPENED=0
ITERATION=0

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    # Capture agent output to check for RALPH_COMPLETE
    AGENT_OUTPUT=$(cat "$PROMPT_FILE" | $AGENT_CMD 2>&1)
    echo "$AGENT_OUTPUT"

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
        { cat "$PROMPT_FILE"; echo ""; echo "## Human response to agent question"; echo "$USER_RESPONSE"; } > "$TEMP_REPLY"
        PROMPT_FILE="$TEMP_REPLY"
        continue
    fi

    # Push branch; set upstream tracking on first push
    git push origin "$CURRENT_BRANCH" 2>/dev/null || \
        git push -u origin "$CURRENT_BRANCH" 2>/dev/null || \
        echo "Warning: git push failed — continuing without push"

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
