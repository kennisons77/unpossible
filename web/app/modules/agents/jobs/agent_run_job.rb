# frozen_string_literal: true

module Agents
  class AgentRunJob < ApplicationJob
    queue_as :agents

    # One active job per source_ref — concurrent enqueue waits rather than runs in parallel.
    # source_ref is nullable; fall back to run_id so the key is always present.
    def self.concurrency_key_for(run_id:, source_ref: nil)
      source_ref.presence || run_id
    end

    # Solid Queue concurrency control: block a second job for the same source_ref
    # until the first completes. Arguments are (agent_run_id, source_ref).
    limits_concurrency to: 1,
                       key: ->(agent_run_id, source_ref = nil) {
                         self.class.concurrency_key_for(run_id: agent_run_id.to_s, source_ref: source_ref)
                       },
                       duration: 30.minutes

    def perform(agent_run_id, _source_ref = nil)
      run = AgentRun.find_by(id: agent_run_id)
      return unless run && run.status == "running"

      adapter = ProviderAdapter.for(run.provider)
      turns = build_turn_hashes(run)

      prompt = adapter.build_prompt(
        node: run.source_ref,
        context_chunks: [],
        principles: [],
        turns: turns,
        token_budget: adapter.max_context_tokens
      )

      raw = adapter.call_provider(prompt)
      result = adapter.parse_response(raw)

      if result[:stop_reason] == "agent_question"
        # Agent is pausing for human input
        append_turn(run, kind: "agent_question", content: result[:text])
        run.update!(status: "waiting_for_input")
      else
        append_turn(run, kind: "llm_response", content: result[:text])
        run.update!(
          status: "completed",
          input_tokens: result[:input_tokens],
          output_tokens: result[:output_tokens]
        )
      end
    rescue ProviderAdapter::TokenBudgetExceeded => e
      append_turn(run, kind: "agent_question", content: "RALPH_WAITING: #{e.message}")
      run.update!(status: "waiting_for_input")
    end

    private

    # Reconstruct conversation history from persisted turns as hashes for build_prompt.
    def build_turn_hashes(run)
      run.turns.order(:position).map do |turn|
        { kind: turn.kind, content: turn.content, position: turn.position }
      end
    end

    def append_turn(run, kind:, content:)
      run.turns.create!(
        position: (run.turns.maximum(:position) || 0) + 1,
        kind: kind,
        content: content
      )
    end
  end
end
