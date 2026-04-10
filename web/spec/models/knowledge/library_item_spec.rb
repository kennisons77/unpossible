# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Knowledge::LibraryItem, type: :model do
  describe 'validations' do
    it 'is valid with all required fields' do
      item = build(:knowledge_library_item)
      expect(item).to be_valid
    end

    it 'validates content_type inclusion' do
      item = build(:knowledge_library_item, content_type: 'invalid')
      expect(item).not_to be_valid
      expect(item.errors[:content_type]).to be_present
    end

    it 'accepts all defined content types' do
      Knowledge::LibraryItem::CONTENT_TYPES.each do |ct|
        item = build(:knowledge_library_item, content_type: ct)
        expect(item).to be_valid, "expected content_type '#{ct}' to be valid"
      end
    end
  end

  describe 'upsert idempotency' do
    it 'enforces unique index on (source_path, chunk_index)' do
      create(:knowledge_library_item, source_path: 'specs/a.md', chunk_index: 0)
      duplicate = build(:knowledge_library_item, source_path: 'specs/a.md', chunk_index: 0)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe 'nullable fields' do
    it 'allows nil node_id' do
      item = build(:knowledge_library_item, node: nil)
      expect(item).to be_valid
    end

    it 'allows nil source_path' do
      item = build(:knowledge_library_item, source_path: nil, chunk_index: 0)
      expect(item).to be_valid
    end
  end
end
