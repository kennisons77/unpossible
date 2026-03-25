# Specs Directory

This directory contains all specification files for the project.

## Structure

```
specs/
├── README.md              # This file
├── prd.md                 # Product Requirements Document
├── plan.md                # High-level human checklist
└── features/              # Feature-specific activity specs
    └── <feature-name>.md  # One spec per feature/activity
```

## Core Specs

- **prd.md** — Technical constraints (language, base image, test command, port) and phase
- **plan.md** — High-level goals and human-readable checklist

## Feature Organization

Activity specs can be organized under `specs/features/` for better grouping. Each feature file describes:

- What the user does and why
- Acceptance criteria — observable outcomes, not implementation details
- Capability depth in scope for the current release

The planning agent scans both `specs/*.md` and `specs/features/*.md` when generating the implementation plan.

## Writing Good Specs

- Focus on outcomes, not implementation
- Acceptance criteria become required tests
- Keep specs lean — they load into every loop iteration
- Use markdown for efficient tokenization
