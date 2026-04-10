# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::AgentRun, type: :model do
  describe 'validations' do
    it 'is valid with all required fields' do
      run = build(:agents_agent_run)
      expect(run).to be_valid
    end

    it 'validates mode inclusion' do
      run = build(:agents_agent_run, mode: 'invalid')
      expect(run).not_to be_valid
      expect(run.errors[:mode]).to be_present
    end

    it 'accepts all defined modes' do
      Agents::AgentRun::MODES.each do |m|
        run = build(:agents_agent_run, mode: m)
        expect(run).to be_valid, "expected mode '#{m}' to be valid"
      end
    end

    it 'validates status inclusion' do
      run = build(:agents_agent_run, status: 'invalid')
      expect(run).not_to be_valid
      expect(run.errors[:status]).to be_present
    end

    it 'accepts all defined statuses' do
      Agents::AgentRun::STATUSES.each do |s|
        run = build(:agents_agent_run, status: s)
        expect(run).to be_valid, "expected status '#{s}' to be valid"
      end
    end
  end

  describe 'nullable fields' do
    it 'allows nil parent_run_id' do
      run = build(:agents_agent_run, parent_run_id: nil)
      expect(run).to be_valid
    end
  end

  describe 'defaults' do
    it 'defaults source_node_ids to empty array' do
      run = create(:agents_agent_run)
      expect(run.reload.source_node_ids).to eq([])
    end
  end
end
