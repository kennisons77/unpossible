# frozen_string_literal: true

module Security
  # Scrubs sensitive patterns from log lines before they are written.
  # Plugged into the lograge formatter so all structured request logs are clean.
  module LogRedactor
    PATTERNS = [
      [/sk-[A-Za-z0-9\-_]{20,}/, '[REDACTED:openai_key]'],
      [/Bearer\s+[A-Za-z0-9\-._~+\/]+=*/, '[REDACTED:bearer_token]'],
      [/-----BEGIN [A-Z ]+-----/, '[REDACTED:pem_header]'],
      [/AKIA[A-Z0-9]{16}/, '[REDACTED:aws_key]'],
      [/eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]*/, '[REDACTED:jwt]']
    ].freeze

    def self.scrub(line)
      PATTERNS.reduce(line) { |text, (pattern, replacement)| text.gsub(pattern, replacement) }
    end
  end
end
