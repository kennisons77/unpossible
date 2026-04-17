# frozen_string_literal: true

module Agents
  class OpenAiAdapter < ProviderAdapter
    MAX_CONTEXT_TOKENS = 128_000

    def build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)
      system_content = assemble_system(node, context_chunks, principles)
      system_cost = estimate_tokens(system_content)
      remaining = token_budget - system_cost

      trimmed_turns = apply_turn_budget(turns, remaining)

      # OpenAI uses a flat messages array with an optional system message prepended
      messages = []
      messages << { role: "system", content: system_content } if system_content.present?
      messages.concat(trimmed_turns.map { |t| { role: turn_role(t[:kind]), content: t[:content] } })

      { model: "gpt-4o", messages: messages }
    end

    def parse_response(raw_response)
      raw_response.dig("choices", 0, "message", "content")
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
