# IDEAS — Unpossible

Raw ideas. Promote to a spec with `make promote <id>` when ready.

## [1] Custom code index tool

- **Status:** parked
- **Created:** 2026-04-13
- **Promoted:**

A lightweight code index service that replaces or supplements LSP for agent navigation.
Uses Ruby's `prism` parser (ships with 3.3) to extract symbols (classes, methods, module
boundaries) and exposes them via MCP tool or simple API.

Why: LSP servers are heavy, require the full language runtime in the agent environment,
and provide more than agents need. Agents mostly want: "where is this defined?", "who
calls this?", "what's the public interface of this module?". A purpose-built index could
be lighter, faster, and integrated with the ledger (index changes per beat).

Could also index LOOKUP.md files and spec cross-references, making the validate-refs
check available as a live query rather than a batch script.

Defer until ruby-lsp proves insufficient for agent navigation needs.
