# frozen_string_literal: true

module Knowledge
  class ContextRetriever
    def self.retrieve(query:, limit:, node_id: nil)
      new(query:, limit:, node_id:).retrieve
    end

    def initialize(query:, limit:, node_id: nil)
      @query = query
      @limit = limit
      @node_id = node_id
    end

    def retrieve
      embedding = EmbedderService.for.embed(@query)
      encoded = Pgvector.encode(embedding)

      scope = LibraryItem.all
      scope = scope.where(node_id: ancestor_node_ids) if @node_id
      scope
        .order(Arel.sql(LibraryItem.sanitize_sql_array(["embedding <=> ?", encoded])))
        .limit(@limit)
        .to_a
    end

    private

    def ancestor_node_ids
      ids = [@node_id]
      visited = Set.new(ids)
      queue = [@node_id]

      while (current = queue.shift)
        Ledger::NodeEdge.where(edge_type: "contains", child_id: current).pluck(:parent_id).each do |pid|
          next if visited.include?(pid)

          visited << pid
          ids << pid
          queue << pid
        end
      end

      ids
    end
  end
end
