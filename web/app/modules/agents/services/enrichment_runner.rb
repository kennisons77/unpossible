# frozen_string_literal: true

module Agents
  # Runs enrichment tools before the first LLM call and appends results as
  # tool_result turns on the AgentRun.
  #
  # Enrichment tools are declared in skill frontmatter under `tools.enrich`.
  # Each tool runs unconditionally; failures are logged and skipped (fail open —
  # enrichment is a pipeline invisible step, not a core workflow step).
  #
  # Skipped entirely when agent_override is true.
  class EnrichmentRunner
    # Registry maps tool name → callable that returns a string result.
    # Each callable receives no arguments; tools capture context via closures
    # or read from the environment.
    TOOLS = {
      "git_diff" => -> { `git diff HEAD 2>&1`.strip }
    }.freeze

    # Runs each named tool, appends a tool_result turn for each, and returns
    # the array of appended AgentRunTurn records.
    #
    # run         — AgentRun record (turns appended here)
    # tool_names  — array of tool name strings from skill frontmatter
    def self.call(run, tool_names)
      Array(tool_names).filter_map do |name|
        tool = TOOLS[name]
        unless tool
          Rails.logger.warn("[EnrichmentRunner] unknown tool '#{name}' — skipping")
          next
        end

        result = tool.call
        # Query maximum position directly to avoid stale association cache.
        next_position = (AgentRunTurn.where(agent_run_id: run.id).maximum(:position) || 0) + 1
        run.turns.create!(position: next_position, kind: "tool_result", content: "#{name}:\n#{result}")
      rescue StandardError => e
        # Fail open — log and continue; enrichment failure must not abort the run
        Rails.logger.warn("[EnrichmentRunner] tool '#{name}' failed: #{e.message}")
        nil
      end
    end
  end
end
