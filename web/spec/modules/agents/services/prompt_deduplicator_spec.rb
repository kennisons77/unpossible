# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Agents::PromptDeduplicator do
  let(:sha) { SecureRandom.hex(32) }
  let(:mode) { 'build' }

  describe '.call' do
    it 'returns cached run when SHA matches within 24h' do
      run = create(:agents_agent_run, prompt_sha256: sha, mode: mode, status: 'completed', created_at: 1.hour.ago)

      expect(described_class.call(prompt_sha256: sha, mode: mode)).to eq(run)
    end

    it 'returns nil when no match' do
      expect(described_class.call(prompt_sha256: sha, mode: mode)).to be_nil
    end

    it 'ignores failed runs' do
      create(:agents_agent_run, prompt_sha256: sha, mode: mode, status: 'failed', created_at: 1.hour.ago)

      expect(described_class.call(prompt_sha256: sha, mode: mode)).to be_nil
    end

    it 'ignores runs older than max age' do
      create(:agents_agent_run, prompt_sha256: sha, mode: mode, status: 'completed', created_at: 25.hours.ago)

      expect(described_class.call(prompt_sha256: sha, mode: mode)).to be_nil
    end

    it 'respects custom max_age' do
      run = create(:agents_agent_run, prompt_sha256: sha, mode: mode, status: 'completed', created_at: 2.hours.ago)

      expect(described_class.call(prompt_sha256: sha, mode: mode, max_age: 1.hour)).to be_nil
      expect(described_class.call(prompt_sha256: sha, mode: mode, max_age: 3.hours)).to eq(run)
    end

    it 'returns the most recent matching run' do
      old_run = create(:agents_agent_run, prompt_sha256: sha, mode: mode, status: 'completed', created_at: 3.hours.ago)
      new_run = create(:agents_agent_run, prompt_sha256: sha, mode: mode, status: 'completed', created_at: 1.hour.ago)

      expect(described_class.call(prompt_sha256: sha, mode: mode)).to eq(new_run)
    end
  end
end
