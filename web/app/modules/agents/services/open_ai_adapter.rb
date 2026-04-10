# frozen_string_literal: true

module Agents
  class OpenAiAdapter < ProviderAdapter
    MAX_CONTEXT_TOKENS = 128_000

    def build_prompt(messages)
      { model: "gpt-4o", messages: messages }
    end

    def parse_response(raw_response)
      raw_response.dig("choices", 0, "message", "content")
    end

    def max_context_tokens
      MAX_CONTEXT_TOKENS
    end
  end
end
