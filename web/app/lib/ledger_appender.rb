# frozen_string_literal: true

# Appends structured events to LEDGER.jsonl.
# The file is append-only — entries are never modified or deleted.
# Idempotent: duplicate entries (same ts + type + ref/path) are silently skipped.
class LedgerAppender
  VALID_TYPES = %w[status blocked unblocked spec_changed spec_removed pr_opened pr_review pr_merged].freeze

  # Default path relative to Rails.root (or project root in non-Rails contexts).
  DEFAULT_PATH = File.expand_path('../../../../LEDGER.jsonl', __dir__)

  class InvalidEventType < ArgumentError; end

  # Appends an event to the ledger file.
  # event - Hash with at minimum :type and :ts keys.
  # path  - Override the ledger file path (used in tests).
  def self.append(event, path: DEFAULT_PATH)
    type = event[:type] || event['type']
    raise InvalidEventType, "Unknown event type: #{type.inspect}" unless VALID_TYPES.include?(type)

    line = event.to_json

    # Idempotency: skip if this exact line already exists.
    if File.exist?(path)
      return if File.foreach(path).any? { |existing| existing.chomp == line }
    end

    File.open(path, 'a') { |f| f.puts(line) }
  end
end
