# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::RunStorageService do
  describe '.complete' do
    let(:run) { create(:agents_agent_run, duration_ms: 1234) }

    it 'stores duration_ms from the agent run on the created LlmMetric' do
      described_class.complete(run, input_tokens: 10, output_tokens: 5, cost_estimate_usd: 0.001)
      metric = Analytics::LlmMetric.find_by!(agent_run_id: run.id)
      expect(metric.duration_ms).to eq(1234)
    end

    it 'stores nil duration_ms when agent run has no duration' do
      run.update_columns(duration_ms: nil)
      described_class.complete(run, input_tokens: 10, output_tokens: 5, cost_estimate_usd: 0.001)
      metric = Analytics::LlmMetric.find_by!(agent_run_id: run.id)
      expect(metric.duration_ms).to be_nil
    end
  end
end
