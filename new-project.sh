#!/bin/bash
# Usage: ./new-project.sh <project-name>
# Creates a new project directory structure under projects/<name>/

set -e

if [ $# -eq 0 ]; then
    echo "Error: project name required"
    echo "Usage: ./new-project.sh <project-name>"
    exit 1
fi

PROJECT_NAME="$1"

# Validate project name
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: project name cannot be empty"
    exit 1
fi

if [[ "$PROJECT_NAME" =~ [/\\] ]]; then
    echo "Error: project name cannot contain slashes"
    exit 1
fi

if [[ "$PROJECT_NAME" =~ [[:space:]] ]]; then
    echo "Error: project name cannot contain spaces"
    exit 1
fi

PROJECT_DIR="projects/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "Error: project '$PROJECT_NAME' already exists at $PROJECT_DIR"
    exit 1
fi

echo "Creating project: $PROJECT_NAME"

# Create directory structure
mkdir -p "$PROJECT_DIR/specs"
mkdir -p "$PROJECT_DIR/src/test"
mkdir -p "$PROJECT_DIR/infra"

# Create placeholder spec files
cat > "$PROJECT_DIR/specs/prd.md" << EOF
# Product Requirements Document — $PROJECT_NAME

## Overview

[Brief description of what this project does]

## Goals

- [Goal 1]
- [Goal 2]

## Non-Goals

- [What this project explicitly does not do]

## Technical Constraints

- Language: [e.g., Python 3.12, Go 1.22, Ruby 3.3]
- Framework: [e.g., FastAPI, Rails, none]
- Base image: [e.g., python:3.12-slim, golang:1.22-alpine]
- Test command (in container): [e.g., pytest, go test ./..., rspec]
- Port: [e.g., 8080, 3000, none]

## Phase

Phase 0
EOF

cat > "$PROJECT_DIR/specs/plan.md" << EOF
# Plan — $PROJECT_NAME

## Goals

- [High-level goal 1]
- [High-level goal 2]

## Current Status

[What's done, what's next]
EOF

# Create IMPLEMENTATION_PLAN.md
cat > "$PROJECT_DIR/IMPLEMENTATION_PLAN.md" << EOF
# IMPLEMENTATION_PLAN — $PROJECT_NAME

[Brief description of the project]

**Current Phase:** Phase 0 (Local development with docker-compose)

---

## Backlog

- [ ] [First task description] (\`path/to/file\`)
  Required tests: [what tests are needed]

---

**Total tasks:** 0
**Phase 0 constraints:** All work uses local docker-compose only. No CI/CD, no remote deploys, no k8s.
**Next phase:** Phase 1 (CI) — not planned yet. Advance only after Phase 0 acceptance criteria are met.
EOF

# Create minimal Dockerfile
cat > "$PROJECT_DIR/infra/Dockerfile" << 'EOF'
# TODO: Update FROM based on specs/prd.md Technical Constraints
FROM alpine:latest

WORKDIR /app

# TODO: Install dependencies

COPY src/ .

# TODO: Update CMD based on your application
CMD ["echo", "Replace this with your application command"]
EOF

# Create docker-compose.yml
cat > "$PROJECT_DIR/infra/docker-compose.yml" << 'EOF'
services:
  app:
    build:
      context: ..
      dockerfile: infra/Dockerfile
    ports:
      - "8080:8080"  # TODO: Update port from specs/prd.md
    volumes:
      - ../src:/app

  test:
    build:
      context: ..
      dockerfile: infra/Dockerfile
    command: "echo 'TODO: Update test command from specs/prd.md'"
    volumes:
      - ../src:/app
EOF

# Create .gitkeep for test directory
touch "$PROJECT_DIR/src/test/.gitkeep"

echo "✓ Created $PROJECT_DIR/"
echo "✓ Created specs/ (prd.md, plan.md)"
echo "✓ Created src/test/"
echo "✓ Created infra/ (Dockerfile, docker-compose.yml)"
echo "✓ Created IMPLEMENTATION_PLAN.md"
echo ""
echo "Next steps:"
echo "1. Edit $PROJECT_DIR/specs/prd.md — fill in Technical Constraints"
echo "2. Edit $PROJECT_DIR/specs/plan.md — define your goals"
echo "3. Update ACTIVE_PROJECT file: echo '$PROJECT_NAME' > ACTIVE_PROJECT"
echo "4. Run: ./loop.sh plan 1"
