# frozen_string_literal: true

require 'open3'
require 'json'

module ReferenceGraph
  # Shells out to the reference-parser Go binary and returns the parsed graph.
  # Returns an empty graph on any error (fail-open — UI degrades gracefully).
  class ParserService
    EMPTY_GRAPH = { 'nodes' => [], 'edges' => [], 'generated_at' => nil }.freeze

    # Path to the binary. Override via REFERENCE_PARSER_PATH env var.
    # Default: go/reference-parser relative to the project root (one level above Rails.root).
    def self.binary_path
      ENV.fetch('REFERENCE_PARSER_PATH') do
        File.expand_path('../../go/reference-parser', Rails.root)
      end
    end

    def self.call
      bin = binary_path
      unless File.exist?(bin) && File.executable?(bin)
        Rails.logger.warn("ReferenceGraph::ParserService: binary not found at #{bin}")
        return EMPTY_GRAPH.dup
      end

      root = File.expand_path('..', Rails.root)
      stdout, stderr, status = Open3.capture3(bin, '--root', root)

      unless status.success?
        Rails.logger.warn("ReferenceGraph::ParserService: parser exited #{status.exitstatus}: #{stderr}")
        return EMPTY_GRAPH.dup
      end

      JSON.parse(stdout)
    rescue JSON::ParserError => e
      Rails.logger.warn("ReferenceGraph::ParserService: JSON parse error: #{e.message}")
      EMPTY_GRAPH.dup
    rescue StandardError => e
      Rails.logger.warn("ReferenceGraph::ParserService: unexpected error: #{e.message}")
      EMPTY_GRAPH.dup
    end
  end
end
