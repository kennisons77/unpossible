# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Security::PromptSanitizer do
  describe '.sanitize' do
    it 'redacts an email address' do
      expect(described_class.sanitize('contact user@example.com please')).to include('[EMAIL]')
    end

    it 'does not include the original email in the output' do
      expect(described_class.sanitize('user@example.com')).not_to include('user@example.com')
    end

    it 'redacts a phone number' do
      expect(described_class.sanitize('call 555-867-5309 now')).to include('[PHONE]')
    end

    it 'redacts an IP address' do
      expect(described_class.sanitize('server at 192.168.1.1 failed')).to include('[IP]')
    end

    it 'redacts an OpenAI API key' do
      expect(described_class.sanitize('key=sk-abcdefghijklmnopqrstuvwxyz1234567890')).to include('[REDACTED:openai_key]')
    end

    it 'redacts an AWS access key' do
      expect(described_class.sanitize('AKIAIOSFODNN7EXAMPLE')).to include('[REDACTED:aws_key]')
    end

    it 'redacts a JWT token' do
      text = 'token=eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxfQ.abc123'
      expect(described_class.sanitize(text)).to include('[REDACTED:jwt]')
    end

    it 'passes clean text through unchanged' do
      text = 'summarize the following document'
      expect(described_class.sanitize(text)).to eq(text)
    end

    it 'logs a warning when sensitive content is detected' do
      allow(Rails.logger).to receive(:warn)
      described_class.sanitize('user@example.com')
      expect(Rails.logger).to have_received(:warn).with('[PromptSanitizer] sensitive content detected and redacted')
    end

    it 'does not log a warning for clean text' do
      allow(Rails.logger).to receive(:warn)
      described_class.sanitize('clean text here')
      expect(Rails.logger).not_to have_received(:warn)
    end
  end
end
