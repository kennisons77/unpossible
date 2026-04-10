# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Knowledge::IndexerJob, type: :job do
  let(:org_id) { SecureRandom.uuid }
  let(:node) { create(:ledger_node, spec_path: 'specs/test.md', org_id: org_id) }
  let(:markdown_content) { "# Title\n\nFirst paragraph.\n\nSecond paragraph." }
  let(:chunks) { Knowledge::MdChunker.chunk(markdown_content) }
  let(:sha) { Digest::SHA256.hexdigest(markdown_content) }
  let(:fake_embedding) { Array.new(1536) { 0.1 } }
  let(:embedder) { instance_double(Knowledge::OpenAiEmbedder) }
  let(:abs_path) { File.expand_path('specs/test.md', Rails.root.parent.to_s) }

  before do
    allow(Knowledge::EmbedderService).to receive(:for).and_return(embedder)
    allow(embedder).to receive(:embed).and_return(fake_embedding)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(abs_path).and_return(true)
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(abs_path).and_return(markdown_content)
  end

  describe 'indexing' do
    it 'indexes markdown file into paragraph-level chunks with embeddings' do
      described_class.perform_now(node.id.to_s)

      items = Knowledge::LibraryItem.where(source_path: 'specs/test.md').order(:chunk_index)
      expect(items.length).to eq(chunks.length)
      expect(items.first.content).to eq(chunks.first[:content])
      expect(items.last.content).to eq(chunks.last[:content])
      expect(items.first.embedding).to eq(fake_embedding)
      expect(items.first.node_id).to eq(node.id)
      expect(items.first.org_id).to eq(org_id)
    end
  end

  describe 'SHA256 change detection' do
    it 'skips unchanged file — no embedding call made' do
      create(:knowledge_library_item,
             source_path: 'specs/test.md',
             source_sha: sha,
             chunk_index: 0,
             org_id: org_id)

      described_class.perform_now(node.id.to_s)

      expect(embedder).not_to have_received(:embed)
    end
  end

  describe 'upsert idempotency' do
    it 'upserts on (source_path, chunk_index)' do
      create(:knowledge_library_item,
             source_path: 'specs/test.md',
             source_sha: 'old-sha',
             chunk_index: 0,
             content: 'old content',
             org_id: org_id)

      described_class.perform_now(node.id.to_s)

      items = Knowledge::LibraryItem.where(source_path: 'specs/test.md')
      expect(items.count).to eq(chunks.length)
      expect(items.find_by(chunk_index: 0).source_sha).to eq(sha)
    end
  end

  describe 'queue' do
    it 'is enqueued on the knowledge queue' do
      expect(described_class.new.queue_name).to eq('knowledge')
    end
  end
end
