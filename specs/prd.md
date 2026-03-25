# Product Requirements Document — unpossible

## Overview

Metaprogramming improvements to the unpossible template itself: the loop runner, prompts, and project scaffolding tooling.

## Goals

1. `loop.sh` reads `ACTIVE_PROJECT` and scopes all paths to `projects/<name>/`
2. A `new-project.sh` scaffold script creates a new project directory with the correct structure
3. Shell scripts are tested with BATS in a Docker container

## Non-Goals

- Changes to any project living under `projects/` (e.g. geneAIe)
- CI/CD pipeline changes

## Technical Constraints

- Language: Bash
- Base image: bats/bats:latest
- Test command (in container): bats /workspace/test
- Port: none

## Phase

Phase 0
