# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Analytics::LlmMetric, type: :model, spec: "specifications/system/analytics/concept.md#llm-metric" do
  describe 'validations' do
    it 'is valid with required fields' do
      expect(build(:analytics_llm_metric)).to be_valid
    end

    it 'requires org_id' do
      expect(build(:analytics_llm_metric, org_id: nil)).not_to be_valid
    end

    it 'requires provider' do
      expect(build(:analytics_llm_metric, provider: nil)).not_to be_valid
    end

    it 'requires model' do
      expect(build(:analytics_llm_metric, model: nil)).not_to be_valid
    end

    it 'requires cost_estimate_usd' do
      expect(build(:analytics_llm_metric, cost_estimate_usd: nil)).not_to be_valid
    end

    it 'stores cost_estimate_usd as decimal with 6 decimal places' do
      metric = create(:analytics_llm_metric, cost_estimate_usd: 0.123456)
      expect(metric.reload.cost_estimate_usd).to eq(BigDecimal('0.123456'))
    end
  end

  describe 'append-only enforcement' do
    let(:metric) { create(:analytics_llm_metric) }

    it 'raises on update' do
      expect { metric.update(provider: 'changed') }.to raise_error(NotImplementedError)
    end

    it 'raises on update!' do
      expect { metric.update!(provider: 'changed') }.to raise_error(NotImplementedError)
    end

    it 'raises on destroy' do
      expect { metric.destroy }.to raise_error(NotImplementedError)
    end

    it 'raises on destroy!' do
      expect { metric.destroy! }.to raise_error(NotImplementedError)
    end
  end

  describe 'index on (org_id, provider, model, created_at)' do
    it 'can query by org_id, provider, and model' do
      org_id = SecureRandom.uuid
      create(:analytics_llm_metric, org_id: org_id, provider: 'anthropic', model: 'claude-3')
      results = described_class.where(org_id: org_id, provider: 'anthropic', model: 'claude-3')
      expect(results.count).to eq(1)
    end
  end
end
