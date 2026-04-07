# frozen_string_literal: true

module Ledger
  class LedgerController < ApplicationController
    before_action :authenticate_session!

    # GET /ledger — active in_progress node + ancestor chain
    def current
      @active_node = Ledger::Node
        .where(org_id: current_org_id, kind: "question", status: "in_progress")
        .order(originated_at: :asc)
        .first
      @ancestors = @active_node ? ancestors_for(@active_node) : []
    end

    # GET /ledger/open — all open questions, filterable
    def open
      scope = Ledger::Node.where(org_id: current_org_id, kind: "question", status: "open")
      scope = scope.where(scope: params[:scope]) if params[:scope].present?
      scope = scope.where(level: params[:level]) if params[:level].present?
      scope = scope.where(author: params[:author]) if params[:author].present?
      @nodes = scope.order(originated_at: :asc)
    end

    # GET /ledger/tree — full project tree, text search
    def tree
      scope = Ledger::Node.where(org_id: current_org_id)
      if params[:q].present?
        q = "%#{params[:q].downcase}%"
        scope = scope.where("LOWER(title) LIKE ? OR LOWER(body) LIKE ?", q, q)
      end
      all_nodes = scope.order(originated_at: :asc).to_a
      child_ids = Ledger::NodeEdge.where(edge_type: "contains", child_id: all_nodes.map(&:id))
                                  .pluck(:child_id).to_set
      @root_nodes = all_nodes.reject { |n| child_ids.include?(n.id) }
      @children_by_parent = build_children_map(all_nodes)
    end

    # GET /ledger/nodes/:id — node detail
    def node
      @node = Ledger::Node.find(params[:id])
      @ancestors = ancestors_for(@node)
      @children = Ledger::NodeEdge.where(parent_id: @node.id, edge_type: "contains")
                                  .includes(:child).map(&:child)
      @depends_on = Ledger::NodeEdge.where(child_id: @node.id, edge_type: "depends_on")
                                    .includes(:parent).map(&:parent)
      @refs = Ledger::NodeEdge.where(parent_id: @node.id, edge_type: "refs")
                              .includes(:child)
      @audit_events = @node.audit_events.order(recorded_at: :asc)
    end

    private

    def ancestors_for(node)
      ancestors = []
      current = node
      loop do
        edge = Ledger::NodeEdge.find_by(child_id: current.id, edge_type: "contains", primary: true) ||
               Ledger::NodeEdge.find_by(child_id: current.id, edge_type: "contains")
        break unless edge

        current = Ledger::Node.find(edge.parent_id)
        ancestors.unshift(current)
      end
      ancestors
    end

    def build_children_map(nodes)
      node_ids = nodes.map(&:id)
      edges = Ledger::NodeEdge.where(parent_id: node_ids, edge_type: "contains")
      nodes_by_id = nodes.index_by(&:id)
      edges.each_with_object(Hash.new { |h, k| h[k] = [] }) do |edge, map|
        map[edge.parent_id] << nodes_by_id[edge.child_id]
      end
    end
  end
end
