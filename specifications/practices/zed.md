---
name: zed
kind: practice
domain: Editor
description: Zed setup and workflows for running loops and reviewing output in-editor
loaded_by: [human]
---

# Zed Editor Practices

Principles for using Zed effectively in the unpossible workflow. The goal is to keep
the loop running in the editor, review its output without leaving Zed, and write better
specs before the loop ever starts.

## Core Setup

Add to your Zed `settings.json` (cmd+shift+p → "zed: open settings"):

```json
"git": {
  "inline_blame": {
    "enabled": true
  }
},
"terminal": {
  "shell": "system"
}
```

Inline blame shows who (or which loop iteration) last touched each line without opening
the git panel. Essential for reviewing loop output in spec files.

## Running the Loop from Zed

Use tasks instead of typing commands manually. Open with `cmd+shift+p` → "task: spawn".

| Task | When to use |
|---|---|
| `loop: build (single, streaming)` | Reviewing one iteration live — output stays visible |
| `loop: plan (single, streaming)` | Gap analysis before a build run — watch Claude's reasoning |
| `loop: build (background)` | Letting the loop run unattended — terminal opens but doesn't steal focus |
| `loop: plan (background)` | Same, for plan mode |
| `sandbox: shell` | Dropping into the Docker sandbox for manual inspection |

Tasks are defined in `.zed/tasks.json` at the project root. Mirror any new Makefile
targets there — don't add tasks for things not already in the Makefile.

## Terminal Layout

Zed's terminal panel (`cmd+j` to toggle) is sufficient for most loop work. For a
near-fullscreen terminal without leaving Zed:

- Drag the terminal divider up until only the tab bar is visible above it
- Or open a second Zed window (`cmd+shift+n`) dedicated to the running loop — one window
  for specifications/code, one for terminal output

Avoid switching to iTerm mid-session. Context switching between apps breaks the review
flow that Zed's split panes enable.

## Reviewing Loop Output (Git)

After each loop commit, review in Zed before touching anything else:

1. `cmd+shift+g` opens the git panel — see all changed files at a glance
2. Click any file in the panel to open its diff inline
3. Gutter indicators (colored bars on the left edge) show changed lines in every open file
4. To revert a single hunk: click the gutter indicator → "Revert Hunk"
5. To revert the entire last commit: open the terminal and run `git reset --hard HEAD~1`

Do not open the GitHub web UI to review loop commits. Everything you need is in the
git panel. The web UI is for sharing and PRs, not for iteration review.

## Spec Writing Workflow

The most common cause of unintended loop behavior is specs that contradict each other
or leave gaps the loop fills with assumptions. Zed's project search is the fix.

**Before running the loop:**

1. Open all active spec files in a split pane: `specifications/project-requirements.md` left, the relevant
   activity spec right
2. Use `cmd+shift+f` (project search) to search for any feature name or term you're
   about to implement — verify it appears consistently across all spec files
3. Look for the same term meaning different things in different files — that's the gap
   the loop will exploit

**Split pane layout for spec work:**
- Left pane: `specifications/project-requirements.md` (constraints — language, framework, port)
- Right pane: the activity spec you're currently writing
- Terminal panel (collapsed): available via `cmd+j` when you need to run `plan1` to
  check Claude's interpretation

## Working Across Template and Project Simultaneously

When porting improvements from unpossible (the template) to a project built from it:

1. `File → Add Folder to Project` — add both roots to one Zed workspace
2. Use `cmd+shift+f` to search across both — find where a practice or prompt pattern
   needs updating in the project
3. Use split panes to edit the template file and the project file side by side

This replaces the window-switching workflow and makes diffs between template and project
visible without a separate tool.

## What Not to Do in Zed

- Don't use the Zed agent panel for loop work — it's a separate context from the loop
  and will confuse your mental model of what the agent knows
- Don't run `loop.sh` directly in the terminal when a task exists for it — tasks keep
  the command consistent and documented
- Don't review loop output in the GitHub web UI during active development — it breaks
  the edit→run→review cycle that Zed's git panel supports natively
