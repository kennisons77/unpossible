# frozen_string_literal: true

module ReferenceGraph
  class GraphController < ApplicationController
    before_action :authenticate!
    before_action :load_graph

    # GET /graph/current — in-progress beat and its ancestor chain
    def current
      @current_beat = @nodes_by_id.values.find { |n| n['type'] == 'beat' && n['status'] == 'in_progress' }
      @ancestors = @current_beat ? ancestor_chain(@current_beat) : []
    end

    # GET /graph/open — all non-done plan items, filterable by status
    def open
      beats = @nodes_by_id.values.select { |n| n['type'] == 'beat' && n['status'] != 'done' }
      beats = beats.select { |n| n['status'] == params[:status] } if params[:status].present?
      @beats = beats.sort_by { |n| n['id'] }
    end

    # GET /graph/condensed — full project tree, collapsible, with text search
    def condensed
      query = params[:q].to_s.downcase
      @nodes = @nodes_by_id.values
      @nodes = @nodes.select { |n| n['label'].to_s.downcase.include?(query) || n['id'].downcase.include?(query) } if query.present?
      @nodes_by_type = @nodes.group_by { |n| n['type'] }.sort_by { |type, _| GRAPH_TYPE_ORDER.index(type) || 99 }
      @query = params[:q]
    end

    private

    GRAPH_TYPE_ORDER = %w[beat spec_section pull_request commit test_suite research_finding review].freeze

    def load_graph
      result = ReferenceGraph::ParserService.call
      @graph = result
      @nodes_by_id = result['nodes'].index_by { |n| n['id'] }
      @edges = result['edges']
    end

    def ancestor_chain(beat)
      # Walk edges: beat → spec (refs), spec → spec (contains)
      visited = {}
      chain = []
      queue = [beat['id']]
      while (id = queue.shift)
        next if visited[id]
        visited[id] = true
        node = @nodes_by_id[id]
        chain << node if node && node['id'] != beat['id']
        @edges.each do |e|
          queue << e['to'] if e['from'] == id && !visited[e['to']]
        end
      end
      chain
    end
  end
end
