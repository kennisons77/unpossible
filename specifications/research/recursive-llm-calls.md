# Research: Recursive LLM Calls

**Status:** Pinned — not yet analyzed
**Created:** 2026-03-30

## Purpose

Investigate patterns for recursive / nested LLM calls — where an LLM invocation spawns further LLM calls as part of its execution. Relevant to unpossible's subagent dispatch model and the producer/reviewer pattern.

## Pinned References

| Title | URL | Notes |
|---|---|---|
| arxiv 2512.24601 | https://arxiv.org/abs/2512.24601 | Starting point — not yet analyzed |

## Open Questions

- What termination conditions prevent infinite recursion in agent trees?
- How does cost accumulate across recursive call trees — and how do we attribute it back to the originating story/task?
- Are there patterns for bounding recursion depth deterministically (vs relying on the LLM to self-terminate)?
- How does this interact with the producer/reviewer pattern — can a reviewer spawn its own build sub-loop?

## Next Step

Run a spike loop against the pinned paper and any related work it cites. Output: a summary of applicable patterns and a recommendation for how unpossible's subagent dispatch should handle recursive depth limits.
