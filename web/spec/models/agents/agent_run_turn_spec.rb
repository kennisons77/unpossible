# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::AgentRunTurn, type: :model do
  describe 'validations' do
    it 'is valid with all required fields' do
      turn = build(:agents_agent_run_turn)
      expect(turn).to be_valid
    end

    it 'validates kind inclusion' do
      turn = build(:agents_agent_run_turn, kind: 'invalid')
      expect(turn).not_to be_valid
      expect(turn.errors[:kind]).to be_present
    end

    it 'accepts all defined kinds' do
      Agents::AgentRunTurn::KINDS.each do |k|
        turn = build(:agents_agent_run_turn, kind: k)
        expect(turn).to be_valid, "expected kind '#{k}' to be valid"
      end
    end
  end

  describe 'associations' do
    it 'belongs to an AgentRun' do
      turn = create(:agents_agent_run_turn)
      expect(turn.agent_run).to be_a(Agents::AgentRun)
    end
  end

  describe 'nullable fields' do
    it 'allows nil purged_at' do
      turn = build(:agents_agent_run_turn, purged_at: nil)
      expect(turn).to be_valid
    end

    it 'accepts a purged_at timestamp' do
      turn = create(:agents_agent_run_turn, purged_at: Time.current)
      expect(turn.reload.purged_at).to be_present
    end
  end
end
