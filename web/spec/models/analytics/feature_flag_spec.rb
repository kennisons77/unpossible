# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Analytics::FeatureFlag, type: :model do
  let(:org_id) { SecureRandom.uuid }

  describe '.enabled?' do
    it 'returns false for unknown key' do
      expect(described_class.enabled?(org_id: org_id, key: 'nonexistent.flag')).to be false
    end

    it 'returns false for archived flag' do
      create(:analytics_feature_flag, org_id: org_id, key: 'test.archived', enabled: true, status: 'archived')
      expect(described_class.enabled?(org_id: org_id, key: 'test.archived')).to be false
    end

    it 'returns true for active enabled flag' do
      create(:analytics_feature_flag, org_id: org_id, key: 'test.enabled', enabled: true, status: 'active')
      expect(described_class.enabled?(org_id: org_id, key: 'test.enabled')).to be true
    end

    it 'returns false for active disabled flag' do
      create(:analytics_feature_flag, org_id: org_id, key: 'test.disabled', enabled: false, status: 'active')
      expect(described_class.enabled?(org_id: org_id, key: 'test.disabled')).to be false
    end

    it 'fires $feature_flag_called event on evaluation' do
      create(:analytics_feature_flag, org_id: org_id, key: 'test.fire', enabled: true, status: 'active')
      expect { described_class.enabled?(org_id: org_id, key: 'test.fire') }
        .to change { Analytics::AnalyticsEvent.where(event_name: '$feature_flag_called').count }.by(1)

      event = Analytics::AnalyticsEvent.find_by(event_name: '$feature_flag_called')
      expect(event.properties['flag_key']).to eq('test.fire')
      expect(event.properties['enabled']).to be true
      expect(event.properties['variant']).to eq('enabled')
    end

    it 'fires $feature_flag_called with enabled: false for disabled flag' do
      create(:analytics_feature_flag, org_id: org_id, key: 'test.off', enabled: false, status: 'active')
      described_class.enabled?(org_id: org_id, key: 'test.off')

      event = Analytics::AnalyticsEvent.find_by(event_name: '$feature_flag_called')
      expect(event.properties['enabled']).to be false
      expect(event.properties['variant']).to eq('disabled')
    end

    it 'does not raise when event creation fails' do
      allow(Analytics::AnalyticsEvent).to receive(:create!).and_raise(ActiveRecord::StatementInvalid)
      expect { described_class.enabled?(org_id: org_id, key: 'nonexistent.flag') }.not_to raise_error
    end
  end

  describe 'uniqueness' do
    it 'raises on duplicate key per org' do
      create(:analytics_feature_flag, org_id: org_id, key: 'dup.flag')
      duplicate = build(:analytics_feature_flag, org_id: org_id, key: 'dup.flag')

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'validations' do
    it 'is valid without metadata.hypothesis' do
      flag = build(:analytics_feature_flag, metadata: {})
      expect(flag).to be_valid
    end
  end
end
