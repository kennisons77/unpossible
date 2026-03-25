# Gap Analysis — unpossible (2026-03-24)

## Executive Summary

The unpossible project is a meta-improvement to the unpossible template itself. The template has a structural divergence: the README describes a flat structure (app/, infra/, specs/ at root), but the actual implementation uses a `projects/<name>/` subdirectory structure anchored by an `ACTIVE_PROJECT` file.

**Critical Finding:** The prompt files (PROMPT_plan.md, PROMPT_build.md) already reference the `projects/<name>/` structure, but `loop.sh` has NOT been updated to implement it. This is the #1 blocker preventing the template from working correctly.

## Current State

### What Exists
- ✅ ACTIVE_PROJECT file at repo root (contains "unpossible")
- ✅ projects/unpossible/ directory with specs/, src/, infra/, IMPLEMENTATION_PLAN.md
- ✅ PROMPT_plan.md and PROMPT_build.md reference projects/<name>/ paths correctly
- ✅ infra/Dockerfile properly configured (bats/bats:latest, no placeholders)
- ✅ infra/docker-compose.yml properly configured (test service defined)
- ✅ Basic BATS test file exists: src/test/loop.bats (3 trivial tests)

### What's Missing
- ❌ loop.sh does NOT read ACTIVE_PROJECT or scope paths to projects/<name>/
- ❌ new-project.sh does NOT exist
- ❌ Comprehensive BATS tests for loop.sh scoping behavior
- ❌ BATS tests for new-project.sh
- ❌ No audience.md (full gap analysis performed)
- ❌ No language-specific practices for Bash
- ❌ Features from plan.md not yet implemented (spec organisation, worklog, ideas, review)

## Specs Analysis

### From prd.md (Technical Constraints)
- **Language:** Bash
- **Framework:** (none)
- **Base image:** bats/bats:latest
- **Test command:** bats /workspace/test
- **Port:** none
- **Phase:** Phase 0 (Local development)

### Goals from prd.md
1. ✅ **Goal 1:** loop.sh reads ACTIVE_PROJECT and scopes all paths to projects/<name>/ — **NOT IMPLEMENTED** (blocker)
2. ❌ **Goal 2:** new-project.sh scaffold script creates new project directories — **MISSING**
3. ⚠️ **Goal 3:** Shell scripts tested with BATS in Docker — **PARTIALLY DONE** (basic tests exist, comprehensive tests missing)

### Goals from plan.md
1. ⚠️ **BATS test harness** — infrastructure exists, comprehensive tests missing
2. ❌ **new-project.sh scaffold** — not implemented
3. ❌ **Feature-scoped spec organisation** — not implemented
4. ❌ **Structured work log** — not implemented
5. ❌ **Idea parking lot** — not implemented
6. ❌ **Agent code review loop** — not implemented

## Source Code Analysis

### loop.sh (repo root)
- **Current behavior:** Hardcodes PROMPT_plan.md and PROMPT_build.md at repo root
- **Missing:** NO reference to ACTIVE_PROJECT anywhere in the script
- **Missing:** NO path scoping to projects/<name>/
- **Impact:** The loop cannot work with the projects/ structure that the prompts expect

### src/test/loop.bats
- **Current tests:** 3 trivial tests (ACTIVE_PROJECT exists, non-empty, loop.sh executable)
- **Missing:** Tests for ACTIVE_PROJECT scoping behavior
- **Missing:** Tests for error handling (missing ACTIVE_PROJECT, missing project dir)
- **Missing:** Tests for path construction

### new-project.sh
- **Status:** Does not exist
- **Impact:** No way to scaffold new projects from the template

## Infrastructure Analysis

### infra/Dockerfile
- ✅ Properly configured with bats/bats:latest
- ✅ No placeholder values
- ✅ Sets WORKDIR to /workspace
- ✅ Copies repo into container

### infra/docker-compose.yml
- ✅ Defines test service
- ✅ Builds from repo root (../../..)
- ✅ Runs projects/unpossible/src/test
- ⚠️ No app service (not needed for this meta-project)

## Dependency Analysis

### Critical Path (Blockers)
1. **loop.sh ACTIVE_PROJECT scoping** — blocks everything else
2. **BATS tests for loop.sh** — verifies #1 works
3. **new-project.sh** — required by prd.md Goal 2
4. **BATS tests for new-project.sh** — verifies #3 works
5. **Full BATS suite green** — checkpoint before features

### Feature Dependencies
- **Spec organisation** — depends on loop.sh working correctly
- **Structured work log** — depends on loop.sh working correctly
- **Idea parking lot** — depends on loop.sh working correctly
- **Agent code review** — depends on loop.sh working correctly

All features depend on the critical path being complete.

## Recommendations

### Immediate Actions (Phase 0)
1. **Fix loop.sh** — implement ACTIVE_PROJECT scoping (task #1, highest priority)
2. **Add comprehensive BATS tests** — verify loop.sh behavior (task #2)
3. **Create new-project.sh** — scaffold script (task #3)
4. **Add BATS tests for new-project.sh** — verify scaffolding (task #4)
5. **Verify full suite green** — checkpoint (task #5)

### Feature Implementation (Phase 0)
After critical path is complete:
- Implement spec organisation by feature (3 tasks)
- Implement structured work log (4 tasks)
- Implement idea parking lot (4 tasks)
- Implement agent code review (4 tasks)

### Future Phases (Not Yet Planned)
- **Phase 1 (CI):** Add GitHub Actions or equivalent
- **Phase 2 (Staging):** Remote deploy (if applicable for a template project)
- **Phase 3 (Production):** Production-ready, security hardened

## Missing Specifications

No new specifications need to be authored. The existing specs (prd.md, plan.md) are sufficient. However, as features are implemented, feature-specific specs should be created under `specs/features/`:

- `specs/features/worklog.md` — schema and usage for WORKLOG.md
- `specs/features/ideas.md` — schema and usage for IDEAS.md
- `specs/README.md` — document the specs/features/ convention

## Test Coverage Gaps

### Current Coverage
- ✅ ACTIVE_PROJECT file exists
- ✅ ACTIVE_PROJECT is non-empty
- ✅ loop.sh is executable

### Missing Coverage
- ❌ loop.sh reads ACTIVE_PROJECT correctly
- ❌ loop.sh exits non-zero if ACTIVE_PROJECT missing
- ❌ loop.sh exits non-zero if ACTIVE_PROJECT empty
- ❌ loop.sh exits non-zero if projects/<name>/ doesn't exist
- ❌ loop.sh constructs correct paths to PROMPT files
- ❌ loop.sh falls back to root PROMPT files if project-level ones missing
- ❌ new-project.sh creates correct directory structure
- ❌ new-project.sh validates input
- ❌ new-project.sh exits non-zero on errors

## Conclusion

The unpossible project has a clear implementation path. The critical blocker is loop.sh not implementing ACTIVE_PROJECT scoping. Once that's fixed and tested, the remaining features can be implemented in dependency order.

All infrastructure is properly configured. No placeholder values need to be filled in. The project is ready for implementation to begin with task #1 in IMPLEMENTATION_PLAN.md.

**Next Step:** Implement task #1 (Update loop.sh to read ACTIVE_PROJECT and scope all paths to projects/<name>/)
