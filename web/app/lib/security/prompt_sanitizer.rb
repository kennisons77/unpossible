# frozen_string_literal: true

module Security
  # Sanitizes text before it is sent to an LLM provider.
  # Replaces secrets and PII with typed placeholders and logs a warning on any match.
  module PromptSanitizer
    PATTERNS = [
      [/\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b/, '[EMAIL]'],
      [/\b(\+?1[\s\-.]?)?\(?\d{3}\)?[\s\-.]?\d{3}[\s\-.]?\d{4}\b/, '[PHONE]'],
      [/\b(?:\d{1,3}\.){3}\d{1,3}\b/, '[IP]'],
      [/sk-[A-Za-z0-9\-_]{20,}/, '[REDACTED:openai_key]'],
      [/AKIA[A-Z0-9]{16}/, '[REDACTED:aws_key]'],
      [/eyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]*/, '[REDACTED:jwt]']
    ].freeze

    def self.sanitize(text)
      sanitized = PATTERNS.reduce(text) { |t, (pattern, replacement)| t.gsub(pattern, replacement) }
      Rails.logger.warn('[PromptSanitizer] sensitive content detected and redacted') if sanitized != text
      sanitized
    end
  end
end
