# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Analytics::AuditLogJob, type: :job, spec: "specifications/system/analytics/concept.md#audit-log-job" do
  let(:org_id) { SecureRandom.uuid }

  it 'is enqueued on the analytics queue' do
    expect(described_class.queue_name).to eq('analytics')
  end

  it 'creates an AuditEvent record when performed' do
    expect {
      described_class.perform_now(
        org_id: org_id,
        event_name: 'agent.completed',
        severity: 'info',
        properties: { run_id: '42' }
      )
    }.to change(Analytics::AuditEvent, :count).by(1)
  end

  it 'stores the correct attributes' do
    described_class.perform_now(
      org_id: org_id,
      event_name: 'agent.failed',
      severity: 'warning',
      properties: { reason: 'timeout' }
    )
    event = Analytics::AuditEvent.last
    expect(event.org_id).to eq(org_id)
    expect(event.event_name).to eq('agent.failed')
    expect(event.severity).to eq('warning')
    expect(event.properties).to eq({ 'reason' => 'timeout' })
  end

  it 'raises on invalid attributes when perform is called directly (fail-closed)' do
    # Bypass ApplicationJob retry_on wrapper to verify the job itself raises
    expect {
      described_class.new.perform(org_id: nil, event_name: 'test', severity: 'info')
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
