# frozen_string_literal: true

module Agents
  class AgentRunJob < ApplicationJob
    queue_as :agents

    # One active job per source_ref — concurrent enqueue waits rather than runs in parallel.
    # source_ref is nullable; fall back to run_id so the key is always present.
    def self.concurrency_key_for(run_id:, source_ref: nil)
      source_ref.presence || run_id
    end

    def perform(agent_run_id)
      run = AgentRun.find_by(id: agent_run_id)
      return unless run && run.status == "running"

      adapter = ProviderAdapter.for(run.provider)
      messages = build_messages(run)

      raw = adapter.call_provider(messages)
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
    end

    private

    # Reconstruct conversation history from persisted turns.
    def build_messages(run)
      run.turns.order(:position).map do |turn|
        { role: turn_role(turn.kind), content: turn.content }
      end
    end

    def turn_role(kind)
      case kind
      when "human_input" then "user"
      when "agent_question" then "assistant"
      when "llm_response" then "assistant"
      when "tool_result" then "user"
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
