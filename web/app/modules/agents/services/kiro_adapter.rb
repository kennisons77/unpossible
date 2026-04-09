# frozen_string_literal: true

module Agents
  class KiroAdapter < ProviderAdapter
    MAX_CONTEXT_TOKENS = 200_000

    def build_prompt(messages)
      { model: "kiro", messages: messages }
    end

    def parse_response(raw_response)
      raw_response.dig("content", 0, "text")
    end

    def max_context_tokens
      MAX_CONTEXT_TOKENS
    end
  end
end
