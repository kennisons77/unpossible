## 2026-04-22 11:58 — Implement SkillLoader for skill file loading (tag 0.0.72)

**Changes:**
- Added `Agents::SkillLoader` service (`web/app/modules/agents/services/skill_loader.rb`)
- Added 11 RSpec examples covering all acceptance criteria
- Marked task 2.1 complete in IMPLEMENTATION_PLAN.md

**Thinking:**
- `SkillLoader` is a pure function (class method `.call`) — no state, no side effects, easy to test
- Used `Data.define` for the Result type to get immutable value semantics without a full class
- Path resolution: absolute paths pass through; relative paths resolve from `Rails.root/..` so `specifications/skills/build.md` works from the project root
- Flat `tools:` array (used in plan.md) is intentionally not treated as enrich/callable — the spec defines only the nested hash format for those declarations

**Challenges:**
- The YAML frontmatter regex needed `\z` not `\Z` to match the end of string including trailing newlines correctly with the `m` flag
- `Psych::Exception` is the base class for all psych parse errors in Ruby 3.3 — catching it covers both `SyntaxError` and `DisallowedClass`

**Alternatives considered:**
- Using a gem like `front_matter_parser` — rejected because stdlib YAML + a simple regex is sufficient and avoids a dependency
- Instance-based service object — rejected because there's no state to encapsulate; class methods are cleaner here

**Tradeoffs taken:**
- Fail open on all file errors (missing, unreadable, malformed) — consistent with the pipeline invisible step rules in the spec. If a skill file is broken, the job continues with empty enrichment rather than crashing
- `Rails.root.join("..", source_ref)` assumes the Rails app is one level below the project root (`web/`). This is true for this project but would break if the layout changed

## 2026-04-22 12:49 — Implement ContextRetriever and extend SkillLoader with principles (tag 0.0.73)

**Changes:**
- Added `Agents::ContextRetriever` service (`web/app/modules/agents/services/context_retriever.rb`)
- Extended `SkillLoader::Result` with `principles` field parsed from frontmatter
- Added 7 RSpec examples for `ContextRetriever`; updated `SkillLoader` spec to cover `principles`
- Marked task 2.2 complete in IMPLEMENTATION_PLAN.md

**Thinking:**
- `ContextRetriever` is a pure function: takes an array of principle names, returns an array of file contents
- Principle names (e.g. `"cost"`, `"coding"`) map directly to `specifications/practices/{name}.md` — no registry needed
- Extending `SkillLoader` to parse `principles` from frontmatter was the right place: it already owns frontmatter parsing, and `ContextRetriever` should receive already-parsed names rather than re-parsing the skill file
- `filter_map` with `next unless File.exist?` is the cleanest way to skip missing files without accumulating nils

**Challenges:**
- The test stub for `resolve_path` needed `allow(described_class).to receive(:resolve_path)` with a block — `stub_const` on `PRACTICES_DIR` alone wouldn't work because `resolve_path` uses `Rails.root.join` which would still point to the real path inside the container
- `private_class_method :resolve_path` means the stub must use `allow` not `expect` — RSpec can stub private class methods via `allow` without issue

**Alternatives considered:**
- Having `ContextRetriever` re-parse the skill file itself — rejected because it duplicates frontmatter parsing logic already in `SkillLoader`; single source of truth
- A lookup table mapping principle names to paths — rejected as over-engineering; the naming convention (`{name}.md` in `specifications/practices/`) is the convention and needs no registry
- Returning `{name: ..., content: ...}` structs instead of plain strings — rejected; callers (`build_prompt`) just need the content strings, not the names

**Tradeoffs taken:**
- Fail open on missing files: if `cost.md` is missing, the job continues with one fewer context chunk rather than crashing. Consistent with pipeline invisible step rules
- `Rails.root.join("..", PRACTICES_DIR, ...)` inherits the same layout assumption as `SkillLoader` — Rails app is one level below project root. Acceptable for Phase 0
