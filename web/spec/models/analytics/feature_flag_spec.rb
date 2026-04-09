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
