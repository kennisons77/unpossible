# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::AgentRun, type: :model do
  describe 'validations' do
    it 'is valid with all required fields' do
      run = build(:agents_agent_run)
      expect(run).to be_valid
    end

    it 'validates org_id presence' do
      run = build(:agents_agent_run, org_id: nil)
      expect(run).not_to be_valid
      expect(run.errors[:org_id]).to be_present
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

    it 'allows nil source_ref' do
      run = build(:agents_agent_run, source_ref: nil)
      expect(run).to be_valid
    end
  end

  describe 'source_ref' do
    it 'accepts a spec path string' do
      run = build(:agents_agent_run, source_ref: 'specifications/system/agent-runner/concept.md')
      expect(run).to be_valid
    end
  end

  describe 'defaults' do
    it 'defaults source_node_ids to empty array' do
      run = create(:agents_agent_run)
      expect(run.reload.source_node_ids).to eq([])
    end

    it 'defaults agent_override to false' do
      run = create(:agents_agent_run)
      expect(run.reload.agent_override).to be false
    end
  end

  describe 'agent_override' do
    it 'accepts true' do
      run = build(:agents_agent_run, agent_override: true)
      expect(run).to be_valid
    end

    it 'accepts false' do
      run = build(:agents_agent_run, agent_override: false)
      expect(run).to be_valid
    end
  end
end
