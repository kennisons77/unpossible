# frozen_string_literal: true

require "rails_helper"

RSpec.describe Knowledge::ContextRetriever do
  let(:org_id) { SecureRandom.uuid }
  # Deterministic embeddings: unit vectors along different axes for predictable cosine distance
  let(:query_embedding) { Array.new(1536, 0.0).tap { |a| a[0] = 1.0 } }
  let(:close_embedding) { Array.new(1536, 0.0).tap { |a| a[0] = 0.9; a[1] = 0.1 } }
  let(:far_embedding)   { Array.new(1536, 0.0).tap { |a| a[1] = 1.0 } }
  let(:mid_embedding)   { Array.new(1536, 0.0).tap { |a| a[0] = 0.5; a[1] = 0.5 } }

  let(:embedder) { instance_double(Knowledge::OpenAiEmbedder) }

  before do
    allow(Knowledge::EmbedderService).to receive(:for).and_return(embedder)
    allow(embedder).to receive(:embed).and_return(query_embedding)
  end

  describe ".retrieve" do
    it "returns top-N chunks ordered by cosine similarity" do
      far  = create(:knowledge_library_item, embedding: far_embedding, org_id: org_id)
      close = create(:knowledge_library_item, embedding: close_embedding, org_id: org_id)
      mid  = create(:knowledge_library_item, embedding: mid_embedding, org_id: org_id)

      results = described_class.retrieve(query: "test", limit: 2)

      expect(results.length).to eq(2)
      expect(results[0].id).to eq(close.id)
      expect(results[1].id).to eq(mid.id)
    end

    it "scopes results to node tree when node_id is provided" do
      parent = create(:ledger_node, org_id: org_id)
      child  = create(:ledger_node, org_id: org_id)
      create(:ledger_node_edge, parent: parent, child: child, edge_type: "contains")

      other_node = create(:ledger_node, org_id: org_id)

      scoped_item = create(:knowledge_library_item, node: child, embedding: close_embedding, org_id: org_id)
      ancestor_item = create(:knowledge_library_item, node: parent, embedding: mid_embedding, org_id: org_id)
      _unrelated = create(:knowledge_library_item, node: other_node, embedding: close_embedding, org_id: org_id)

      results = described_class.retrieve(query: "test", limit: 10, node_id: child.id)

      expect(results.map(&:id)).to contain_exactly(scoped_item.id, ancestor_item.id)
    end

    it "returns empty array when no matches" do
      results = described_class.retrieve(query: "test", limit: 5)

      expect(results).to eq([])
    end
  end
end
