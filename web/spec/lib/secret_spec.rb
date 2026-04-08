# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Secret do
  subject(:secret) { described_class.new('sk-supersecret') }

  describe '#inspect' do
    it 'returns [REDACTED]' do
      expect(secret.inspect).to eq('[REDACTED]')
    end
  end

  describe '#to_s' do
    it 'returns [REDACTED]' do
      expect(secret.to_s).to eq('[REDACTED]')
    end
  end

  describe '#as_json' do
    it 'returns [REDACTED]' do
      expect(secret.as_json).to eq('[REDACTED]')
    end
  end

  describe 'JSON serialization' do
    it 'does not expose the raw value in JSON output' do
      expect(secret.to_json).not_to include('sk-supersecret')
    end
  end

  describe '#expose' do
    it 'returns the raw value' do
      expect(secret.expose).to eq('sk-supersecret')
    end
  end

  describe 'string interpolation' do
    it 'does not leak the raw value' do
      expect("token=#{secret}").to eq('token=[REDACTED]')
    end
  end
end
