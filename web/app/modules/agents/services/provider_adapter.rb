# frozen_string_literal: true

module Agents
  class ProviderAdapter
    PROVIDERS = {
      "claude" => "Agents::ClaudeAdapter",
      "kiro" => "Agents::KiroAdapter",
      "openai" => "Agents::OpenAiAdapter"
    }.freeze

    # Raised when the prompt cannot fit within token_budget even after trimming
    # all non-pinned turns. Caller should surface this as RALPH_WAITING.
    class TokenBudgetExceeded < StandardError; end

    def self.for(provider)
      klass_name = PROVIDERS[provider]
      raise ArgumentError, "Unknown provider: '#{provider}'" unless klass_name

      klass_name.constantize.new
    end

    # Assembles the provider-native prompt payload, applying pinned+sliding trimming
    # to fit within token_budget.
    #
    # Pinned turns (always kept): agent_question, human_input
    # Trimmable turns (dropped oldest-first): llm_response, tool_result
    #
    # Raises TokenBudgetExceeded if still over budget after all trimmable turns removed.
    def build_prompt(node:, context_chunks:, principles:, turns:, token_budget:)
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

    protected

    # Applies pinned+sliding trimming to a list of turn hashes.
    # Each turn hash must have :kind and :content keys.
    # Returns the trimmed list of turns that fit within the remaining budget
    # (after system content has already been accounted for).
    #
    # Raises TokenBudgetExceeded if pinned turns alone exceed the budget.
    def apply_turn_budget(turns, remaining_tokens)
      pinned_kinds = %w[agent_question human_input]
      trimmable_kinds = %w[llm_response tool_result]

      pinned = turns.select { |t| pinned_kinds.include?(t[:kind]) }
      trimmable = turns.select { |t| trimmable_kinds.include?(t[:kind]) }

      pinned_cost = pinned.sum { |t| estimate_tokens(t[:content]) }
      raise TokenBudgetExceeded, "Pinned turns exceed token budget — RALPH_WAITING" if pinned_cost > remaining_tokens

      # Add trimmable turns from newest to oldest until budget is exhausted
      budget_left = remaining_tokens - pinned_cost
      kept_trimmable = []
      trimmable.reverse_each do |turn|
        cost = estimate_tokens(turn[:content])
        if cost <= budget_left
          kept_trimmable.unshift(turn)
          budget_left -= cost
        end
        # Oldest trimmable turns that don't fit are silently dropped
      end

      # Reconstruct in original order: interleave pinned and kept_trimmable by position
      all_kept = (pinned + kept_trimmable).sort_by { |t| t[:position] || 0 }
      all_kept
    end

    # Rough token estimate: ~4 characters per token (standard approximation).
    def estimate_tokens(text)
      (text.to_s.length / 4.0).ceil
    end
  end
end
