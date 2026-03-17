# Ralph Wiggum Loop Prompt

You are an autonomous AI agent working in a "Ralph Wiggum Loop". 
Your goal is to complete the project described in `specs/prd.md` by executing the tasks in `specs/plan.md`. Token spend is an issue and the process should use 

## Instructions

1.  **Read Context:**
    *   Read `specs/prd.md` to understand the goal.
    *   Read `specs/plan.md` to see the current status.
    *   Read `specs/activity.md` to see what happened in previous iterations.

2.  **Select Task:**
    *   Find the *first* unchecked item in `specs/plan.md`.
    *   If all items are checked, verify the project is working and output `RALPH_COMPLETE`.

3.  **Execute:**
    *   Implement the selected task.
    *   Create or update files as needed.
    *   **CRITICAL:** Run tests to verify your changes. Do not mark a task as done unless tests pass.

4.  **Update State:**
    *   Mark the task as completed in `specs/plan.md` (change `[ ]` to `[x]`).
    *   Append a brief entry to `specs/activity.md` describing what you did and the test results.

5.  **Loop Constraint:**
    *   Do only *one* task per iteration to maintain focus.
    *   If you get stuck, log the error in `specs/activity.md` and try a different approach in the next iteration.

## Output
When you are finished with the current task (or if the whole project is done), output a brief summary.
If the project is complete, output the string: `RALPH_COMPLETE`.
