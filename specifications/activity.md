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
