#!/bin/bash
# Validate cross-references across the project.
# Run from project root: ./scripts/validate-refs.sh
#
# Checks:
#   1. Agent config file:// resources resolve
#   2. Markdown relative links in specifications/, AGENTS.md, README.md resolve
#   3. Lookup table paths in AGENTS.md and LOOKUP.md files resolve
#
# Exit 0 if all refs valid, exit 1 if any broken.

set -euo pipefail

ERRFILE=$(mktemp)
: > "$ERRFILE"
trap 'rm -f "$ERRFILE"' EXIT

err() { echo "BROKEN: $1" | tee -a "$ERRFILE"; }

# --- 1. Agent config resources ---
for config in .kiro/agents/*.json; do
    [ -f "$config" ] || continue
    agent=$(basename "$config")
    for path in $(grep -oP '"file://\K[^"]+' "$config" 2>/dev/null); do
        [ -f "$path" ] || err "$agent → $path (resource not found)"
    done
done

# --- 2. Markdown relative links ---
# Match [text](relative/path) but skip URLs, anchors, mailto
# Exclude specifications/research/ — those are snapshots of external projects
for mdfile in $(find specifications/ -name '*.md' -not -path 'specifications/research/*' 2>/dev/null) AGENTS.md README.md PROMPT_*.md; do
    [ -f "$mdfile" ] || continue
    dir=$(dirname "$mdfile")
    for link in $(grep -oP '\[.*?\]\(\K[^)]+' "$mdfile" 2>/dev/null); do
        case "$link" in
            http://*|https://*|\#*|mailto:*) continue ;;
        esac
        path="${link%%#*}"
        [ -z "$path" ] && continue
        # Skip single-word example links (e.g. "url", "path") — no slash or dot
        echo "$path" | grep -qE '[/.]' || continue
        resolved="$dir/$path"
        [ -e "$resolved" ] || err "$mdfile → $link (link target not found)"
    done
done

# --- 3. Lookup table paths (backtick-quoted in table rows) ---
for lookup in AGENTS.md specifications/practices/LOOKUP.md web/app/modules/LOOKUP.md; do
    [ -f "$lookup" ] || continue
    for path in $(grep -oP '`\K(?:specifications/|web/|\.kiro/|infra/)[^`]+' "$lookup" 2>/dev/null); do
        case "$path" in
            *\{*|*\**) continue ;;
        esac
        [ -e "$path" ] || err "$lookup → $path (table ref not found)"
    done
done

echo ""
ERRORS=$(wc -l < "$ERRFILE")
if [ "$ERRORS" -gt 0 ]; then
    echo "$ERRORS broken reference(s) found"
    exit 1
fi
echo "All references valid"
