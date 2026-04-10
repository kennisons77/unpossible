# frozen_string_literal: true

module Agents
  class RunStorageService
    class ConcurrentRunError < StandardError; end
    class DuplicateRunError < StandardError; end

    def self.start(params)
      if params[:prompt_sha256].present? && params[:mode].present?
        cached = PromptDeduplicator.call(prompt_sha256: params[:prompt_sha256], mode: params[:mode])
        return { run: cached, cached: true } if cached
      end

      if AgentRun.where(actor_id: params[:actor_id], status: %w[running waiting_for_input]).exists?
        raise ConcurrentRunError, "Concurrent run already active for this actor"
      end

      run = AgentRun.new(params.merge(status: "running"))
      run.save!
      { run: run, cached: false }
    rescue ActiveRecord::RecordInvalid => e
      raise DuplicateRunError, "Duplicate run_id" if e.record.errors[:run_id]&.include?("has already been taken")
      raise
    end

    def self.complete(run, attrs)
      run.update!(attrs.merge(status: "completed"))
      run
    end

    def self.record_input(run, content:)
      turn = run.turns.create!(
        position: (run.turns.maximum(:position) || 0) + 1,
        kind: "human_input",
        content: content
      )
      run.update!(status: "running")
      turn
    end
  end
end
