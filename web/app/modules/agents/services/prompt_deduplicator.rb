# frozen_string_literal: true

module Agents
  class PromptDeduplicator
    DEFAULT_MAX_AGE = 24.hours

    def self.call(prompt_sha256:, mode:, max_age: DEFAULT_MAX_AGE)
      Agents::AgentRun
        .where(prompt_sha256: prompt_sha256, mode: mode, status: 'completed')
        .where('created_at >= ?', max_age.ago)
        .order(created_at: :desc)
        .first
    end
  end
end
