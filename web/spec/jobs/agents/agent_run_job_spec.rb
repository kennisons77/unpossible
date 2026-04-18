# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::AgentRunJob, type: :job do
  include ActiveJob::TestHelper

  let(:org_id) { SecureRandom.uuid }
  let(:run) { create(:agents_agent_run, org_id: org_id, status: 'running') }
  let(:adapter) { instance_double(Agents::ClaudeAdapter) }
  let(:built_prompt) { { model: "claude-sonnet-4-20250514", system: "", messages: [] } }

  before do
    allow(Agents::ProviderAdapter).to receive(:for).with(run.provider).and_return(adapter)
    allow(adapter).to receive(:max_context_tokens).and_return(200_000)
    allow(adapter).to receive(:build_prompt).and_return(built_prompt)
  end

  it 'is enqueued on the agents queue' do
    expect(described_class.queue_name).to eq('agents')
  end

  describe 'limits_concurrency' do
    it 'declares concurrency limit of 1' do
      expect(described_class.concurrency_limit).to eq(1)
    end

    it 'uses source_ref as concurrency key when present' do
      job = described_class.new
      job.arguments = [run.id, 'specifications/foo.md']
      expect(job.concurrency_key).to include('specifications/foo.md')
    end

    it 'falls back to run_id string when source_ref is absent' do
      job = described_class.new
      job.arguments = [run.id, nil]
      expect(job.concurrency_key).to include(run.id.to_s)
    end
  end

  describe 'concurrency key helper' do
    it 'uses source_ref when present' do
      expect(described_class.concurrency_key_for(run_id: 'r1', source_ref: 'specifications/foo.md'))
        .to eq('specifications/foo.md')
    end

    it 'falls back to run_id when source_ref is absent' do
      expect(described_class.concurrency_key_for(run_id: 'r1', source_ref: nil))
        .to eq('r1')
    end
  end

  describe '#perform' do
    context 'when provider returns a normal response' do
      before do
        allow(adapter).to receive(:call_provider).and_return({ 'content' => [{ 'text' => 'done' }] })
        allow(adapter).to receive(:parse_response).and_return(
          { text: 'done', input_tokens: 10, output_tokens: 5, stop_reason: 'end_turn' }
        )
      end

      it 'appends an llm_response turn' do
        expect { described_class.perform_now(run.id) }
          .to change { run.turns.where(kind: 'llm_response').count }.by(1)
      end

      it 'marks the run completed' do
        described_class.perform_now(run.id)
        expect(run.reload.status).to eq('completed')
      end

      it 'stores token counts' do
        described_class.perform_now(run.id)
        run.reload
        expect(run.input_tokens).to eq(10)
        expect(run.output_tokens).to eq(5)
      end
    end

    context 'when provider signals agent_question (pause)' do
      before do
        allow(adapter).to receive(:call_provider).and_return({})
        allow(adapter).to receive(:parse_response).and_return(
          { text: 'What is the target env?', input_tokens: 8, output_tokens: 3, stop_reason: 'agent_question' }
        )
      end

      it 'appends an agent_question turn' do
        expect { described_class.perform_now(run.id) }
          .to change { run.turns.where(kind: 'agent_question').count }.by(1)
      end

      it 'sets status to waiting_for_input' do
        described_class.perform_now(run.id)
        expect(run.reload.status).to eq('waiting_for_input')
      end
    end

    context 'on resume after human_input' do
      before do
        run.turns.create!(position: 1, kind: 'agent_question', content: 'What env?')
        run.turns.create!(position: 2, kind: 'human_input', content: 'staging')
        allow(adapter).to receive(:build_prompt) do |**kwargs|
          # Verify turn history is reconstructed and passed to build_prompt
          @received_turns = kwargs[:turns]
          built_prompt
        end
        allow(adapter).to receive(:call_provider).and_return({})
        allow(adapter).to receive(:parse_response).and_return(
          { text: 'ok', input_tokens: 5, output_tokens: 2, stop_reason: 'end_turn' }
        )
      end

      it 'passes full turn history to build_prompt' do
        described_class.perform_now(run.id)
        expect(@received_turns.length).to eq(2)
        expect(@received_turns.last[:content]).to eq('staging')
      end

      it 'completes the run' do
        described_class.perform_now(run.id)
        expect(run.reload.status).to eq('completed')
      end
    end

    context 'when token budget is exceeded' do
      before do
        allow(adapter).to receive(:build_prompt)
          .and_raise(Agents::ProviderAdapter::TokenBudgetExceeded, "Pinned turns exceed token budget — RALPH_WAITING")
      end

      it 'sets status to waiting_for_input' do
        described_class.perform_now(run.id)
        expect(run.reload.status).to eq('waiting_for_input')
      end

      it 'appends an agent_question turn with RALPH_WAITING message' do
        expect { described_class.perform_now(run.id) }
          .to change { run.turns.where(kind: 'agent_question').count }.by(1)
        expect(run.turns.last.content).to include('RALPH_WAITING')
      end
    end

    context 'when run is not in running status' do
      let(:run) { create(:agents_agent_run, status: 'waiting_for_input') }

      it 'does nothing' do
        expect(adapter).not_to receive(:call_provider)
        described_class.perform_now(run.id)
      end
    end

    context 'when run does not exist' do
      it 'does nothing without raising' do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end
  end

  describe 'enqueuing from RunStorageService' do
    it 'enqueues AgentRunJob when a run is started' do
      expect {
        Agents::RunStorageService.start(
          org_id: org_id,
          run_id: SecureRandom.uuid,
          mode: 'build',
          provider: 'claude',
          model: 'opus',
          prompt_sha256: SecureRandom.hex(32),
          status: 'running'
        )
      }.to have_enqueued_job(described_class)
    end
  end

  describe 're-enqueuing from RunStorageService#record_input' do
    let(:run) { create(:agents_agent_run, status: 'waiting_for_input') }

    it 're-enqueues AgentRunJob when human input is recorded' do
      expect {
        Agents::RunStorageService.record_input(run, content: 'my answer')
      }.to have_enqueued_job(described_class).with(run.id, run.source_ref)
    end
  end
end
