# frozen_string_literal: true

module Agents
  class ClaudeAdapter < ProviderAdapter
    MAX_CONTEXT_TOKENS = 200_000

    def build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)
      system_content = assemble_system(node, context_chunks, principles)
      system_cost = estimate_tokens(system_content)
      remaining = token_budget - system_cost

      trimmed_turns = apply_turn_budget(turns, remaining)
      messages = trimmed_turns.map { |t| { role: turn_role(t[:kind]), content: t[:content] } }

      { model: "claude-sonnet-4-20250514", system: system_content, messages: messages }
    end

    def parse_response(raw_response)
      raw_response.dig("content", 0, "text")
    end

    def max_context_tokens
      MAX_CONTEXT_TOKENS
    end

    private

    def assemble_system(node, context_chunks, principles)
      parts = []
      parts << node.to_s if node.present?
      parts.concat(Array(principles))
      parts.concat(Array(context_chunks))
      parts.join("\n\n")
    end

    def turn_role(kind)
      case kind
      when "human_input", "tool_result" then "user"
      else "assistant"
      end
    end
  end
end
