# frozen_string_literal: true

require 'pgvector'

# Pgvector column support: encode Ruby arrays to pgvector string format on write,
# decode pgvector strings back to Ruby arrays on read.
module Knowledge
  class LibraryItem < ApplicationRecord
    self.table_name = 'knowledge_library_items'

    CONTENT_TYPES = %w[markdown plain_text link_reference llm_response error_context].freeze

    belongs_to :node, class_name: 'Ledger::Node', optional: true

    validates :chunk_index, presence: true
    validates :content_type, presence: true, inclusion: { in: CONTENT_TYPES }
    validates :content, presence: true
    validates :embedding, presence: true
    validates :org_id, presence: true

    def embedding=(value)
      super(value.is_a?(Array) ? Pgvector.encode(value) : value)
    end

    def embedding
      raw = super
      return nil if raw.nil?
      return raw if raw.is_a?(Array)

      Pgvector.decode(raw)
    end
  end
end
