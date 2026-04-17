# frozen_string_literal: true

module Agents
  class ProviderAdapter
    PROVIDERS = {
      "claude" => "Agents::ClaudeAdapter",
      "kiro" => "Agents::KiroAdapter",
      "openai" => "Agents::OpenAiAdapter"
    }.freeze

    def self.for(provider)
      klass_name = PROVIDERS[provider]
      raise ArgumentError, "Unknown provider: '#{provider}'" unless klass_name

      klass_name.constantize.new
    end

    def build_prompt(_messages)
      raise NotImplementedError, "#{self.class}#build_prompt must be implemented"
    end

    # Makes the HTTP call to the provider. Returns raw provider response.
    def call_provider(_messages)
      raise NotImplementedError, "#{self.class}#call_provider must be implemented"
    end

    def parse_response(_raw_response)
      raise NotImplementedError, "#{self.class}#parse_response must be implemented"
    end

    def max_context_tokens
      raise NotImplementedError, "#{self.class}#max_context_tokens must be implemented"
    end
  end
end
