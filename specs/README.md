# Ralph Wiggum Loop Specs

This directory contains the standard specifications for running a Ralph Wiggum Loop.

## Files

### 1. `pitch.md` (Product Requirements Document)
The startingpoint for an LLM discussion about the project. Think of it as a pitch deck for the project that lists the why, the who, and the what for the project. Can be a useful when doing an [interview with an agent](https://github.com/ghuntley/how-to-ralph-wiggum?tab=readme-ov-file#use-claudes-askuserquestiontool-for-planning).

### 1. `prd.md` (Product Requirements Document)
Defines the "what" and "why" of the project. This is the source of truth for the agent.

### 2. `plan.md` (Implementation Plan)
A granular checklist of tasks. The agent is instructed to:  
1.  Read this file.
2.  Find the first unchecked item.
3.  Implement it.
4.  Mark it as checked.

### 3. `activity.md` (Activity Log)
A persistent log file. The agent appends a summary of its actions after each iteration. This provides "memory" between fresh context windows.

### 4. `prompt.md` (Loop Prompt)
The master instruction file. This is fed to the AI agent at the start of every iteration. It directs the agent to read the other files and execute the next task.

## Usage
1.  **Define:** Fill in `prd.md` with your project goals.
2.  **Plan:** Break down the work into tasks in `plan.md`.
3.  **Run:** Execute the loop using a script like `../ralph.sh` or your preferred AI CLI tool.
4.  **Monitor:** Watch `activity.md` and your git history as the agent works.
