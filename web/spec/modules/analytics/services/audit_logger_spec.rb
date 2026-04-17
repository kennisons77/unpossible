# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Analytics::AuditLogger do
  describe '.log' do
    let(:org_id) { SecureRandom.uuid }

    around do |example|
      original = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original
    end

    it 'enqueues an AuditLogJob on the analytics queue' do
      expect {
        described_class.log(org_id: org_id, event_name: 'agent.completed', severity: 'info')
      }.to have_enqueued_job(Analytics::AuditLogJob)
        .on_queue('analytics')
        .with(org_id: org_id, event_name: 'agent.completed', severity: 'info', properties: {})
    end

    it 'passes properties to the job' do
      props = { run_id: '123' }
      expect {
        described_class.log(org_id: org_id, event_name: 'agent.completed', properties: props)
      }.to have_enqueued_job(Analytics::AuditLogJob)
        .with(hash_including(properties: props))
    end

    it 'does not raise when job enqueue fails' do
      allow(Analytics::AuditLogJob).to receive(:perform_later).and_raise(StandardError, 'queue down')
      expect { described_class.log(org_id: org_id, event_name: 'test') }.not_to raise_error
    end

    it 'logs to Rails.logger when enqueue fails' do
      allow(Analytics::AuditLogJob).to receive(:perform_later).and_raise(StandardError, 'queue down')
      expect(Rails.logger).to receive(:error).with(/AuditLogger\.log failed/)
      described_class.log(org_id: org_id, event_name: 'test')
    end
  end
end
