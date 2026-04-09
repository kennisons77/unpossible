# frozen_string_literal: true

module Knowledge
  class IndexerJob < ApplicationJob
    queue_as :knowledge

    # Accepts a node_id (string UUID) or keyword source_path.
    # Node-based: reads spec_path from the node, indexes with node association.
    # Path-based: indexes a standalone file with no node association.
    def perform(node_id = nil, source_path: nil)
      if node_id
        node = Ledger::Node.find(node_id)
        source_path ||= node.spec_path
        org_id = node.org_id
      end

      raise ArgumentError, 'either node_id or source_path required' unless source_path

      abs_path = resolve_path(source_path)
      return unless File.exist?(abs_path)

      content = File.read(abs_path)
      sha = Digest::SHA256.hexdigest(content)

      return if unchanged?(source_path, sha)

      chunks = MdChunker.chunk(content)
      embedder = EmbedderService.for
      org = org_id || default_org_id

      upsert_chunks(chunks, embedder, source_path, sha, node_id, org)
      cleanup_stale(source_path, chunks.length)
    end

    private

    def resolve_path(source_path)
      File.expand_path(source_path, Rails.root.parent.to_s)
    end

    def unchanged?(source_path, sha)
      LibraryItem.where(source_path: source_path)
                 .where(source_sha: sha)
                 .exists?
    end

    def upsert_chunks(chunks, embedder, source_path, sha, node_id, org_id)
      chunks.each do |chunk|
        embedding = embedder.embed(chunk[:content])

        item = LibraryItem.find_or_initialize_by(
          source_path: source_path,
          chunk_index: chunk[:chunk_index]
        )
        item.assign_attributes(
          content: chunk[:content],
          content_type: 'markdown',
          embedding: embedding,
          source_sha: sha,
          node_id: node_id,
          org_id: org_id
        )
        item.save!
      end
    end

    def cleanup_stale(source_path, chunk_count)
      LibraryItem.where(source_path: source_path)
                 .where('chunk_index >= ?', chunk_count)
                 .delete_all
    end

    def default_org_id
      ENV.fetch('DEFAULT_ORG_ID', '00000000-0000-0000-0000-000000000000')
    end
  end
end
