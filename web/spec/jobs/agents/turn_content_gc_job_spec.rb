# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::TurnContentGcJob, type: :job, spec: "specifications/system/agent-runner/concept.md#turn-content-gc" do
  let(:org_id) { SecureRandom.uuid }

  it 'is enqueued on the agents queue' do
    expect(described_class.queue_name).to eq('agents')
  end

  describe '#perform' do
    def make_run(status:, updated_at:)
      run = create(:agents_agent_run, org_id: org_id, status: status)
      run.update_column(:updated_at, updated_at)
      run
    end

    def add_turn(run)
      run.turns.create!(position: 1, kind: 'llm_response', content: 'hello')
    end

    context 'completed run older than 30 days' do
      let(:run) { make_run(status: 'completed', updated_at: 31.days.ago) }
      let!(:turn) { add_turn(run) }

      it 'sets purged_at on the turn' do
        described_class.perform_now
        expect(turn.reload.purged_at).not_to be_nil
      end

      it 'clears content on the turn' do
        described_class.perform_now
        expect(turn.reload.content).to be_nil
      end

      it 'retains the turn record' do
        expect { described_class.perform_now }.not_to change(Agents::AgentRunTurn, :count)
      end
    end

    context 'completed run within 30 days' do
      let(:run) { make_run(status: 'completed', updated_at: 1.day.ago) }
      let!(:turn) { add_turn(run) }

      it 'does not purge the turn' do
        described_class.perform_now
        expect(turn.reload.purged_at).to be_nil
        expect(turn.reload.content).to eq('hello')
      end
    end

    context 'failed run older than 30 days' do
      let(:run) { make_run(status: 'failed', updated_at: 31.days.ago) }
      let!(:turn) { add_turn(run) }

      it 'does not purge the turn' do
        described_class.perform_now
        expect(turn.reload.purged_at).to be_nil
      end
    end

    context 'waiting_for_input run older than 30 days' do
      let(:run) { make_run(status: 'waiting_for_input', updated_at: 31.days.ago) }
      let!(:turn) { add_turn(run) }

      it 'does not purge the turn' do
        described_class.perform_now
        expect(turn.reload.purged_at).to be_nil
      end
    end

    context 'already purged turn' do
      let(:run) { make_run(status: 'completed', updated_at: 31.days.ago) }
      let!(:turn) do
        t = add_turn(run)
        t.update_columns(purged_at: 5.days.ago, content: nil)
        t
      end

      it 'is idempotent — does not re-update already purged turns' do
        original_purged_at = turn.purged_at
        described_class.perform_now
        expect(turn.reload.purged_at).to eq(original_purged_at)
      end
    end

    context 'with custom retention_days' do
      let(:run) { make_run(status: 'completed', updated_at: 10.days.ago) }
      let!(:turn) { add_turn(run) }

      it 'purges turns older than the custom threshold' do
        described_class.perform_now(retention_days: 7)
        expect(turn.reload.purged_at).not_to be_nil
      end

      it 'does not purge turns within the custom threshold' do
        described_class.perform_now(retention_days: 14)
        expect(turn.reload.purged_at).to be_nil
      end
    end
  end
end
