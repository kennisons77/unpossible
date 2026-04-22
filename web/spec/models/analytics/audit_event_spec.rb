# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Analytics::AuditEvent, type: :model, spec: "specifications/system/analytics/concept.md#audit-event" do
  describe 'validations' do
    it 'is valid with required fields' do
      expect(build(:analytics_audit_event)).to be_valid
    end

    it 'requires org_id' do
      expect(build(:analytics_audit_event, org_id: nil)).not_to be_valid
    end

    it 'requires event_name' do
      expect(build(:analytics_audit_event, event_name: nil)).not_to be_valid
    end

    it 'requires severity' do
      expect(build(:analytics_audit_event, severity: nil)).not_to be_valid
    end

    it 'rejects invalid severity' do
      expect(build(:analytics_audit_event, severity: 'debug')).not_to be_valid
    end

    it 'accepts info severity' do
      expect(build(:analytics_audit_event, severity: 'info')).to be_valid
    end

    it 'accepts warning severity' do
      expect(build(:analytics_audit_event, severity: 'warning')).to be_valid
    end

    it 'accepts critical severity' do
      expect(build(:analytics_audit_event, severity: 'critical')).to be_valid
    end
  end

  describe 'append-only enforcement' do
    let(:event) { create(:analytics_audit_event) }

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

  describe 'index on (org_id, created_at)' do
    it 'can query by org_id and created_at range' do
      org_id = SecureRandom.uuid
      create(:analytics_audit_event, org_id: org_id)
      results = described_class.where(org_id: org_id).where('created_at >= ?', 1.minute.ago)
      expect(results.count).to eq(1)
    end
  end
end
