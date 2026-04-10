# frozen_string_literal: true

FactoryBot.define do
  factory :knowledge_library_item, class: 'Knowledge::LibraryItem' do
    association :node, factory: :ledger_node
    source_path { 'specs/example.md' }
    source_sha { SecureRandom.hex(32) }
    sequence(:chunk_index) { |n| n }
    content_type { 'markdown' }
    content { 'Example chunk content' }
    embedding { Array.new(1536) { rand(-1.0..1.0) } }
    org_id { SecureRandom.uuid }
  end
end
