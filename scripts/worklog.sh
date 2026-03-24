#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f "$REPO_ROOT/ACTIVE_PROJECT" ]]; then
  echo "Error: ACTIVE_PROJECT file not found" >&2
  exit 1
fi

PROJECT_NAME=$(cat "$REPO_ROOT/ACTIVE_PROJECT" | tr -d '[:space:]')
if [[ -z "$PROJECT_NAME" ]]; then
  echo "Error: ACTIVE_PROJECT is empty" >&2
  exit 1
fi

if [[ "$PROJECT_NAME" == "unpossible" ]]; then
  WORKLOG="$REPO_ROOT/WORKLOG.md"
else
  WORKLOG="$REPO_ROOT/projects/$PROJECT_NAME/WORKLOG.md"
fi

usage() {
  cat <<EOF
Usage: worklog.sh <command> [options]

Commands:
  list                    Show all entries in table format
  show <id>               Show full details for one entry
  filter --status=<val>   Filter by status (todo|in-progress|done)
  filter --feature=<val>  Filter by feature name

Examples:
  worklog.sh list
  worklog.sh show 3
  worklog.sh filter --status=done
  worklog.sh filter --feature="Spec Organisation"
EOF
}

parse_entry() {
  local id title status feature started completed commit summary
  while IFS= read -r line; do
    if [[ "$line" =~ ^\#\#\ \[([0-9]+)\]\ (.+)$ ]]; then
      id="${BASH_REMATCH[1]}"
      title="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^\-\ \*\*Status:\*\*\ (.+)$ ]]; then
      status="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\-\ \*\*Feature:\*\*\ (.+)$ ]]; then
      feature="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\-\ \*\*Started:\*\*\ (.+)$ ]]; then
      started="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\-\ \*\*Completed:\*\*\ (.*)$ ]]; then
      completed="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\-\ \*\*Commit:\*\*\ (.*)$ ]]; then
      commit="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\#\#\#\ Summary$ ]]; then
      summary=""
      while IFS= read -r sumline; do
        [[ "$sumline" =~ ^\#\# ]] && break
        summary+="$sumline"$'\n'
      done
    fi
  done
  echo "$id|$title|$status|$feature|$started|$completed|$commit|$summary"
}

list_entries() {
  [[ ! -f "$WORKLOG" ]] && echo "No WORKLOG.md found" && return
  printf "%-4s %-40s %-12s %-30s\n" "ID" "TITLE" "STATUS" "FEATURE"
  printf "%-4s %-40s %-12s %-30s\n" "----" "----------------------------------------" "------------" "------------------------------"
  
  awk '
    /^## \[[0-9]+\]/ { id=$2; gsub(/\[|\]/, "", id); title=$0; sub(/^## \[[0-9]+\] /, "", title) }
    /^\- \*\*Status:\*\*/ { status=$3 }
    /^\- \*\*Feature:\*\*/ { feature=$0; sub(/^\- \*\*Feature:\*\* /, "", feature) }
    /^## \[[0-9]+\]/ && NR>1 { printf "%-4s %-40s %-12s %-30s\n", prev_id, substr(prev_title,1,40), prev_status, substr(prev_feature,1,30); prev_id=id; prev_title=title; prev_status=status; prev_feature=feature }
    NR==1 { prev_id=id; prev_title=title; prev_status=status; prev_feature=feature }
    END { if (prev_id) printf "%-4s %-40s %-12s %-30s\n", prev_id, substr(prev_title,1,40), prev_status, substr(prev_feature,1,30) }
  ' "$WORKLOG"
}

show_entry() {
  local target_id="$1"
  [[ ! -f "$WORKLOG" ]] && echo "Error: WORKLOG.md not found" >&2 && exit 1
  
  awk -v id="$target_id" '
    /^## \[/ { if (found) exit; if ($2 == "["id"]") found=1 }
    found { print }
  ' "$WORKLOG"
  
  [[ $(awk -v id="$target_id" '/^## \[/ { if ($2 == "["id"]") print 1 }' "$WORKLOG") != "1" ]] && echo "Error: Entry $target_id not found" >&2 && exit 1
}

filter_entries() {
  local filter_type="$1"
  local filter_value="$2"
  [[ ! -f "$WORKLOG" ]] && echo "No WORKLOG.md found" && return
  
  if [[ "$filter_type" == "status" ]]; then
    awk -v val="$filter_value" '
      /^## \[[0-9]+\]/ { entry=$0; in_entry=1; matched=0 }
      in_entry && /^\- \*\*Status:\*\*/ { if ($3 == val) matched=1 }
      in_entry && /^## \[[0-9]+\]/ && NR>1 { if (prev_matched) print prev_entry; prev_entry=entry; prev_matched=matched; entry=$0; matched=0 }
      in_entry && !/^## \[[0-9]+\]/ { entry=entry"\n"$0 }
      END { if (prev_matched) print prev_entry; if (matched) print entry }
    ' "$WORKLOG"
  elif [[ "$filter_type" == "feature" ]]; then
    awk -v val="$filter_value" '
      /^## \[[0-9]+\]/ { entry=$0; in_entry=1; matched=0 }
      in_entry && /^\- \*\*Feature:\*\*/ { feat=$0; sub(/^\- \*\*Feature:\*\* /, "", feat); if (feat == val) matched=1 }
      in_entry && /^## \[[0-9]+\]/ && NR>1 { if (prev_matched) print prev_entry; prev_entry=entry; prev_matched=matched; entry=$0; matched=0 }
      in_entry && !/^## \[[0-9]+\]/ { entry=entry"\n"$0 }
      END { if (prev_matched) print prev_entry; if (matched) print entry }
    ' "$WORKLOG"
  fi
}

case "${1:-}" in
  list)
    list_entries
    ;;
  show)
    [[ -z "${2:-}" ]] && echo "Error: show requires an ID" >&2 && exit 1
    show_entry "$2"
    ;;
  filter)
    [[ -z "${2:-}" ]] && echo "Error: filter requires --status=<val> or --feature=<val>" >&2 && exit 1
    if [[ "$2" =~ ^--status=(.+)$ ]]; then
      filter_entries "status" "${BASH_REMATCH[1]}"
    elif [[ "$2" =~ ^--feature=(.+)$ ]]; then
      filter_entries "feature" "${BASH_REMATCH[1]}"
    else
      echo "Error: invalid filter option: $2" >&2
      exit 1
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
