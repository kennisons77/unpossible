# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Security::LogRedactor, spec: "specifications/system/api/concept.md#log-redaction" do
  describe '.scrub' do
    it 'redacts a JWT token' do
      line = 'Authorization: eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxfQ.abc123'
      expect(described_class.scrub(line)).to include('[REDACTED:jwt]')
    end

    it 'does not include the original JWT in the output' do
      line = 'token=eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxfQ.abc123'
      expect(described_class.scrub(line)).not_to include('eyJhbGciOiJIUzI1NiJ9')
    end

    it 'redacts an OpenAI API key' do
      line = 'key=sk-abcdefghijklmnopqrstuvwxyz1234567890'
      expect(described_class.scrub(line)).to include('[REDACTED:openai_key]')
    end

    it 'does not include the original OpenAI key in the output' do
      line = 'key=sk-abcdefghijklmnopqrstuvwxyz1234567890'
      expect(described_class.scrub(line)).not_to include('sk-abcdefghijklmnopqrstuvwxyz')
    end

    it 'redacts a Bearer token' do
      line = 'Authorization: Bearer sometoken123=='
      expect(described_class.scrub(line)).to include('[REDACTED:bearer_token]')
    end

    it 'redacts a PEM header' do
      line = '-----BEGIN RSA PRIVATE KEY-----'
      expect(described_class.scrub(line)).to include('[REDACTED:pem_header]')
    end

    it 'redacts an AWS access key' do
      line = 'aws_access_key_id=AKIAIOSFODNN7EXAMPLE'
      expect(described_class.scrub(line)).to include('[REDACTED:aws_key]')
    end

    it 'passes through a normal log line unchanged' do
      line = 'GET /api/health 200 OK'
      expect(described_class.scrub(line)).to eq(line)
    end
  end
end
