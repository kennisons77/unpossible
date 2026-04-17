# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Analytics::AnalyticsEvent, type: :model do
  describe 'validations' do
    it 'is valid with required fields' do
      event = build(:analytics_event)
      expect(event).to be_valid
    end

    it 'requires org_id' do
      expect(build(:analytics_event, org_id: nil)).not_to be_valid
    end

    it 'requires distinct_id' do
      expect(build(:analytics_event, distinct_id: nil)).not_to be_valid
    end

    it 'requires event_name' do
      expect(build(:analytics_event, event_name: nil)).not_to be_valid
    end

    it 'requires timestamp' do
      expect(build(:analytics_event, timestamp: nil)).not_to be_valid
    end

    it 'requires received_at' do
      expect(build(:analytics_event, received_at: nil)).not_to be_valid
    end
  end

  describe 'append-only enforcement' do
    let(:event) { create(:analytics_event) }

    it 'raises on update' do
      expect { event.update(event_name: 'changed') }.to raise_error(NotImplementedError)
    end

    it 'raises on update!' do
      expect { event.update!(event_name: 'changed') }.to raise_error(NotImplementedError)
    end

    it 'raises on destroy' do
      expect { event.destroy }.to raise_error(NotImplementedError)
    end

    it 'raises on destroy!' do
      expect { event.destroy! }.to raise_error(NotImplementedError)
    end
  end

  describe 'distinct_id' do
    it 'stores as UUID string' do
      uuid = SecureRandom.uuid
      event = create(:analytics_event, distinct_id: uuid)
      expect(event.reload.distinct_id).to eq(uuid)
    end
  end

  describe 'node_id' do
    it 'accepts string values' do
      event = create(:analytics_event, node_id: 'specs/system/analytics/spec.md')
      expect(event.reload.node_id).to eq('specs/system/analytics/spec.md')
    end

    it 'is nullable' do
      event = create(:analytics_event, node_id: nil)
      expect(event.reload.node_id).to be_nil
    end
  end
end
