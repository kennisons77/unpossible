# Work Log — unpossible

## [1] Define IDEAS.md schema

- **Status:** done
- **Feature:** Idea Parking Lot
- **Started:** 2026-03-24T17:32:00Z
- **Completed:** 2026-03-24T17:32:42Z
- **Commit:** 24cf3ae 

### Summary

Created specs/features/ideas.md defining the schema for the idea parking lot feature. Schema includes: id (auto-increment), title, status (parked/researching/ready/rejected/promoted), description, open_questions, created_at, promoted_at. Documented integration with research and promote modes. No tests required (schema definition only).

## [2] Fix new-project.sh: substitute [PROJECT_NAME] placeholder in generated files

- **Status:** done
- **Feature:** Bug Fixes
- **Started:** 2026-03-25T10:27:00-05:00
- **Completed:** 2026-03-25T10:28:00-05:00
- **Commit:** 1a465ab

### Summary

Fixed new-project.sh to substitute $PROJECT_NAME variable in generated prd.md, plan.md, and IMPLEMENTATION_PLAN.md files. Changed heredoc delimiters from 'EOF' (literal) to EOF (variable expansion). Added 3 new BATS tests verifying project name appears in generated files and [PROJECT_NAME] placeholder does not. All 39 tests pass (15 existing + 3 new for new-project.sh).

## [3] Fix new-project.sh: correct Dockerfile COPY path

- **Status:** done
- **Feature:** Bug Fixes
- **Started:** 2026-03-25T10:47:00-05:00
- **Completed:** 2026-03-25T10:49:00-05:00
- **Commit:** 3170db6

### Summary

Fixed Dockerfile COPY path from `../src/` to `src/` in new-project.sh. The build context in docker-compose.yml is set to `..` (parent directory), so the correct relative path is `src/` not `../src/`. Added BATS test verifying the generated Dockerfile contains the correct COPY path. Manually verified a freshly scaffolded project builds successfully. All 40 tests pass.
