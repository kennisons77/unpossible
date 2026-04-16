#!/bin/bash
# Attach the latest activity.md entry as a git note on HEAD.
# Usage: scripts/attach-activity-note.sh [commit]
# Defaults to HEAD if no commit given.

set -euo pipefail

COMMIT="${1:-HEAD}"
ACTIVITY_FILE="activity.md"

[ -f "$ACTIVITY_FILE" ] || { echo "Error: $ACTIVITY_FILE not found"; exit 1; }

# Extract the last entry (everything from the final "## " heading to EOF)
ENTRY=$(awk '/^## /{start=NR; buf=""} start{buf=buf $0 "\n"} END{printf "%s", buf}' "$ACTIVITY_FILE")

[ -z "$ENTRY" ] && { echo "No activity entry found"; exit 1; }

git notes add -f -m "$ENTRY" "$COMMIT"
echo "Attached activity note to $(git rev-parse --short "$COMMIT")"
